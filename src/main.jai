#import "Basic";
#import "SDL3";
#import "Math";
#import "Random";
#import "Yojimbo"()(ENABLE_LOGGING=true);
#import "IPAddress"()(ENABLE_LOGGING=true);
#import "Serialize"()(ENABLE_LOGGING=true);
#import "Reliable";

#load "renderer.jai";
#load "game.jai";
#load "input.jai";
#load "common/common.jai";
#load "network.jai";
#load "infrastructure.jai";

process_messages :: (app: *AppState) {
    using app.network_manager;
    if !client_is_connected(client) return;

    message := client_receive_message(client, xx GameChannel.RELIABLE);
    while message != null {
        log_message_type("Got message", cast(GameMessageType) message.type);

        if cast(GameMessageType) message.type == {
            case .NEW_PLAYER; {
                msg := cast(*NewPlayerMessage) message;

                game_state := *GAME_STATES[msg.state_index];
                action := ActionRequest.{ action=.ADD_PLAYER, point=msg.point, uuid=msg.uuid, b_value=(msg.uuid == client.clientId), ignore=false };
                perform_action_request(game_state, action);
                fast_forward_state(msg.state_index, next_state_index(app.current));
            }

            case .CLIENT_CONNECT_RESPONSE; { // sync game state index here for now
                msg := cast(*ClientConnectResponseMessage) message;

                app.current = msg.state_index;
                app.previous = prev_state_index(msg.state_index);
                GAME_STATES[app.current].nr_of_players = msg.nr_of_players;
                GAME_STATES[app.current].players = msg.players;
            }

            case .PLAYER_MOVE_RESPONSE; {
                msg := cast(*PlayerMoveResponseMessage) message;

                game_state := *GAME_STATES[msg.state_index];
                copy_game_state(game_state, *GAME_STATES[prev_state_index(msg.state_index)]);

                if client.clientId == msg.uuid
                    remove_action(game_state, ActionRequest.{ action=.MOVE, uuid=msg.uuid, point=msg.point });

                action := ActionRequest.{ action=.MOVE_CORRECTION, uuid=msg.uuid, point=msg.point, path=msg.path, count=msg.count };
                perform_action_request(game_state, action);

                player := get_player(*GAME_STATES[app.current], msg.uuid);
                assert(player != null, ".PLAYER_MOVE_RESPONSE 2: player == null");
                old_position := ifx player.is_interpolating then player.interpolated_position else player.position;

                fast_forward_state(msg.state_index, next_state_index(app.current));

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
}

send_actions_to_server :: (app: *AppState, actions: []ActionRequest) {
    using app.network_manager;
    for actions {
        if it.action == {
            case .MOVE; {
                message := cast(*PlayerMoveMessage) client_create_message(client, xx GameMessageType.PLAYER_MOVE);
                message.data = PlayerMoveData.{ state_index=app.current, point=it.point };
                client_send_message(client, xx GameChannel.RELIABLE, message);
            }

            case .ADD_PLAYER; {
                message := cast(*ClientConnectMessage) client_create_message(app.network_manager.client, xx GameMessageType.CLIENT_CONNECT);
                client_send_message(app.network_manager.client, xx GameChannel.RELIABLE, message);
            }
        }
    }
}

convert_input_to_actions :: (input_state: *InputState, game_state: *GameState) -> []ActionRequest {
    actions: [..]ActionRequest;

    if input_state.RMB_pressed {
        assert(game_state.player_index != -1, "Tried creating action when player_index == -1");

        mouse_pos: = mouse_to_screen(game_state) - HALF_TILE_RECT_SIZE;
        mouse_grid := screen_to_map(mouse_pos);
        if in_bounds(mouse_grid) {
            player := game_state.players[game_state.player_index];
            array_add(*actions, ActionRequest.{ action=.MOVE, point=mouse_grid, uuid=player.uuid });
        }
        input_state.RMB_pressed = false;
    }

    if input_state.LMB_pressed {
        uuid: u64 = 69420;
        if game_state.player_index != -1 then uuid = game_state.players[game_state.player_index].uuid;
        array_add(*actions, ActionRequest.{ action=.CLICK, uuid=uuid });
        input_state.LMB_pressed = false;
    }

    if input_state.space {
        action := ActionRequest.{
            action  = .ADD_PLAYER,
            point   = Vector2i.{ xx(random_get() % TILES_X), xx(random_get() % TILES_Y) },
            uuid    = 69420,
            b_value = game_state.player_index == -1,
            ignore  = false
        };
        #if CLIENT { action.ignore = true; } // this is needed to circumvent double actions on multiplayer

        array_add(*actions, action);
        input_state.space = false;
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

    event: SDL_Event;
    previous_input: InputState;
    accumulated_input: InputState;
    game_state: *GameState;

    while true {
        reset_temporary_storage();

        while SDL_PollEvent(*event)
            input(*accumulated_input, *previous_input, *event);

        if accumulated_input.exit == true break;

        if accumulated_input.r {
            init_world(*WORLD);
            accumulated_input.r = false;
        }

        delta := clock_reset(*app.clock);
        app.accumulator += delta;
        num_ticks := cast(u8, floor(app.accumulator / FRAMETIME));

        update_view(*app.view, accumulated_input, delta);
        accumulated_input.scroll_delta = 0;

        #if CLIENT {
            app.network_manager.apollo_time += to_apollo(delta);
            if !network_manager_update(app.network_manager)
                break;
        }

        if num_ticks > 0 {
            #if CLIENT { process_messages(*app); }

            SDL_GetMouseState(xx *accumulated_input.mouse_position.x, xx *accumulated_input.mouse_position.y);
            game_actions := convert_input_to_actions(*accumulated_input, *GAME_STATES[app.current],, temp);

            app.accumulator -= FRAMETIME * xx num_ticks;
            for 0..num_ticks-1 {
                previous := app.current;
                app.current = next_state_index(app.current);
                game_state = *GAME_STATES[app.current];

                copy_game_state(game_state, *GAME_STATES[previous]);
                game_state.view = app.view;
                game_state.input_state = accumulated_input;

                game_state.nr_of_actions = 0;
                for game_actions
                    add_action(game_state, it);

                log("simulating: %\n", app.current);
                simulate(game_state, FRAMETIME);
            }
            app.previous = prev_state_index(app.current, num_ticks);

            memcpy(*previous_input, *accumulated_input, size_of(InputState));

            #if CLIENT {
                send_actions_to_server(*app, game_actions);
            }
        }

        alpha := cast(float32) clamp(app.accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, app.view, alpha);
    }

    quit_app(*app);
}