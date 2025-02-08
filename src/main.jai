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
#load "app.jai";

FRAMETIME   :: 1.0 / 10.0;
SCREEN_SIZE :: Vector2i.{ 800, 600 };

STATE_COUNT :: 256;
GAME_STATES : [STATE_COUNT]GameState;
INPUT_STATES: [STATE_COUNT]InputState;

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

            app.accumulator -= FRAMETIME * xx num_ticks;
            for 0..num_ticks-1 {
                previous := app.current;
                app.current = (app.current + 1) % STATE_COUNT;
                log("app.current: %\n", app.current);

                memcpy(*GAME_STATES[app.current], *GAME_STATES[previous], size_of(GameState));
                memcpy(*INPUT_STATES[app.current], *accumulated_input, size_of(InputState));
                game_state = *GAME_STATES[app.current];
                input_state = *INPUT_STATES[app.current];

                SDL_GetMouseState(xx *input_state.mouse_position.x, xx *input_state.mouse_position.y);

                simulate(game_state, input_state, FRAMETIME);

                // reset transient inputs
                accumulated_input.space = false;
                accumulated_input.LMB_pressed = false;
                accumulated_input.RMB_pressed = false;
                accumulated_input.scroll_delta = 0;
            }
            memcpy(*previous_input, *accumulated_input, size_of(InputState));
            app.previous = (app.current - num_ticks + STATE_COUNT) % STATE_COUNT;

            #if CLIENT {
                {
                    using app.network_manager;
                    if client_is_connected(client) {
                        using GAME_STATES[app.current];
                        if client_index != -1 {
                            for players[client_index].actions {
                                if it.action == {
                                    case .MOVE; {
                                        message := cast(*PlayerMoveMessage) client_create_message(client, xx GameMessageType.PLAYER_MOVE);
                                        message.x = it.x;
                                        message.y = it.y;
                                        message.game_state_index = app.current;
                                        client_send_message(client, xx GameChannel.RELIABLE, message);
                                    }
                                }
                            }
                            array_reset(*players[client_index].actions);
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