#import "Basic";
#import "SDL";
#import "Math";
#import "Random";
#import "Yojimbo"()(ENABLE_LOGGING=true);
#import "IPAddress"()(ENABLE_LOGGING=true);
#import "Serialize"()(ENABLE_LOGGING=true);
#import "Reliable";

#load "renderer.jai";
#load "game.jai";
#load "input.jai";
#load "common.jai";
#load "network.jai";
#load "infrastructure.jai";

convert_input_to_actions :: (input_state: *InputState, game_state: *GameState) -> []ActionRequest {
    actions: [..]ActionRequest;

    if input_state.RMB_pressed {
        assert(game_state.player_index != -1, "Tried creating action when player_index == -1");

        mouse_pos: = mouse_to_screen(game_state, input_state) - tile_size_offset();
        mouse_grid := screen_to_map(mouse_pos);
        if in_bounds(mouse_grid) {
            player := game_state.players[game_state.player_index];
            array_add(*actions, ActionRequest.{ action=.MOVE, x=xx mouse_grid.x, y=xx mouse_grid.y, uuid=player.uuid });
        }
    }

    return actions;
}

main :: () {
    random_seed(cast,no_check(u64) to_milliseconds(current_time_consensus())); // used to randomize client id

    #if CLIENT {
        if !yojimbo_init() exit(0);
    }

    app, ok := init_app(get_command_line_arguments());
    if !ok
        quit_app(*app);

    // @HACK: copy init state to all other states, so when client syncs to server the tiles are set correctly
    for 1..STATE_COUNT-1 {
        memcpy(*GAME_STATES[it], *GAME_STATES[0], size_of(GameState));
    }

    event: SDL_Event;
    previous_input: InputState;
    accumulated_input: InputState;
    game_state: *GameState;
    input_state: *InputState;

    while true {
        reset_temporary_storage();

        while SDL_PollEvent(*event)
            input(*accumulated_input, *previous_input, *event);

        if accumulated_input.exit == true break;

        delta := clock_reset(*app.clock);
        app.accumulator += delta;
        num_ticks := cast(u8, floor(app.accumulator / FRAMETIME));

        #if CLIENT
            app.network_manager.apollo_time += to_apollo(delta);

        if num_ticks > 0 {
            #if CLIENT {
                if !network_manager_update(app.network_manager, delta)
                    break;

                {
                    using app.network_manager;
                    if client_is_connected(client) {
                        message := client_receive_message(client, xx GameChannel.RELIABLE);
                        while message != null {
                            log_message_type("Got message", cast(GameMessageType) message.type);

                            if cast(GameMessageType) message.type == {
                                case .NEW_PLAYER; {
                                    msg := cast(*NewPlayerMessage) message;
                                    add_player(*GAME_STATES[msg.game_state_index], msg.uuid, msg.x, msg.y, msg.uuid == client.clientId);
                                }

                                case .CLIENT_CONNECT;

                                case .CLIENT_CONNECT_RESPONSE; {
                                    msg := cast(*ClientConnectResponseMessage) message;
                                    // sync game state index here for now
                                    app.current = msg.game_state_index;
                                    app.previous = (app.current - 1 + STATE_COUNT) % STATE_COUNT;
                                    {
                                        using GAME_STATES[app.current];
                                        nr_of_players = msg.nr_of_players;
                                        memcpy(*players, *msg.players, MAX_PLAYERS * size_of(Entity));
                                    }
                                }

                                case .PLAYER_MOVE_RESPONSE; {
                                    msg := cast(*PlayerMoveResponseMessage) message;

                                    game_state = *GAME_STATES[msg.game_state_index];
                                    copy_game_state_keeping_actions(game_state, *GAME_STATES[prev_state_index(msg.game_state_index)]);

                                    if client.clientId == msg.uuid
                                        remove_action(game_state, ActionRequest.{ action=.MOVE, uuid=msg.uuid, x=msg.x, y=msg.y });

                                    action := ActionRequest.{ action=.MOVE_CORRECTION, uuid=msg.uuid, x=msg.x, y=msg.y, path=msg.path };
                                    perform_action_request(game_state, action);

                                    player := get_player(*GAME_STATES[app.current], msg.uuid);
                                    assert(player != null, ".PLAYER_MOVE_RESPONSE 2: player == null");
                                    old_position := ifx player.is_interpolating then player.interpolated_position else player.position;

                                    fast_forward_state(msg.game_state_index, next_state_index(app.current));

                                    if client.clientId != msg.uuid {
                                        player = get_player(*GAME_STATES[app.current], msg.uuid);
                                        assert(player != null, ".PLAYER_MOVE_RESPONSE 3: player == null");
                                        player.is_interpolating = true;
                                        player.interpolated_position = old_position;
                                    }
                                }
                            }
                            client_release_message(client, message);
                            message = client_receive_message(client, xx GameChannel.RELIABLE);
                        }

                        if accumulated_input.space {
                            message = cast(*ClientConnectMessage) client_create_message(client, xx GameMessageType.CLIENT_CONNECT);
                            client_send_message(client, xx GameChannel.RELIABLE, message);
                        }
                    }
                }
            }

            SDL_GetMouseState(xx *accumulated_input.mouse_position.x, xx *accumulated_input.mouse_position.y);
            game_actions := convert_input_to_actions(*accumulated_input, *GAME_STATES[app.current],, temp);

            app.accumulator -= FRAMETIME * xx num_ticks;
            for 0..num_ticks-1 {
                previous := app.current;
                app.current = next_state_index(app.current);
                game_state = *GAME_STATES[app.current];

                memcpy(game_state, *GAME_STATES[previous], size_of(GameState));
                memcpy(*INPUT_STATES[app.current], *accumulated_input, size_of(InputState));

                game_state.nr_of_actions = 0;
                for game_actions
                    add_action(game_state, it);

                log("simulating: %\n", app.current);
                simulate(game_state, *INPUT_STATES[app.current], FRAMETIME);

                // reset transient inputs
                accumulated_input.space = false;
                accumulated_input.LMB_pressed = false;
                accumulated_input.RMB_pressed = false;
                accumulated_input.scroll_delta = 0;
            }
            app.previous = prev_state_index(app.current, num_ticks);

            memcpy(*previous_input, *accumulated_input, size_of(InputState));

            #if CLIENT {
                {
                    using app.network_manager;
                    if client_is_connected(client) {
                        for game_actions {
                            if it.action == {
                                case .MOVE; {
                                    message := cast(*PlayerMoveMessage) client_create_message(client, xx GameMessageType.PLAYER_MOVE);
                                    message.game_state_index = app.current;
                                    message.x = it.x;
                                    message.y = it.y;
                                    client_send_message(client, xx GameChannel.RELIABLE, message);
                                }
                            }
                        }
                    }
                }
            }
        }
        alpha := cast(float32) clamp(app.accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, alpha);
    }

    quit_app(*app);
}