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

fast_forward_state :: (start: s16, end: s16) {
    ticks := (end - start + STATE_COUNT) % STATE_COUNT;
    current := start;
    for 0..ticks-1 {
        simulate(*GAME_STATES[current], *INPUT_STATES[current], FRAMETIME);

        next := (current + 1) % STATE_COUNT;
        memcpy(*GAME_STATES[next], *GAME_STATES[current], size_of(GameState));

        current = next;
    }
}

main :: () {
    if !yojimbo_init() exit(0);

    app, ok := init_app(get_command_line_arguments());
    if !ok
        quit_app(*app);

    event: SDL_Event;
    game_state: *GameState;
    input_state: *InputState;
    while true {
        reset_temporary_storage();

        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT; quit_app(*app);
                case SDL_KEYDOWN; if event.key.keysym.sym == SDLK_ESCAPE then quit_app(*app);
            }
        }

        delta := clock_reset(*app.clock);
        app.accumulator += delta;
        app.network_manager.apollo_time += to_apollo(delta);
        num_ticks := cast(u8, floor(app.accumulator / FRAMETIME));

        if num_ticks > 0 {
            if !network_manager_update(app.network_manager, delta)
                break;

            {
                using app.network_manager;
                for client_id: 0..MAX_CLIENTS-1 {
                    if server_is_client_connected(server, client_id) {
                        message := server_receive_message(server, client_id, xx GameChannel.RELIABLE);
                        while message != null {
                            log_message_type("Got message", cast(GameMessageType) message.type);

                            if cast(GameMessageType) message.type == {
                                case .PLAYER_MOVE; {
                                    msg := cast(*PlayerMoveMessage) message;
                                    uuid := server_get_client_id(server, client_id);
                                    player: *Entity = null;
                                    idx := msg.game_state_index;
                                    for 0..GAME_STATES[idx].nr_of_players {
                                        if GAME_STATES[idx].players[it].uuid == uuid {
                                            player = *GAME_STATES[idx].players[it];
                                        }
                                    }
                                    request := ActionRequest.{ action=.MOVE, x=msg.x, y=msg.y };
                                    perform_action_request(*GAME_STATES[idx], player, request);
                                    fast_forward_state(msg.game_state_index, app.current);
                                }

                                case .CLIENT_CONNECT; {
                                    response := cast(*ClientConnectResponseMessage) server_create_message(server, client_id, xx GameMessageType.CLIENT_CONNECT_RESPONSE);
                                    {
                                        using GAME_STATES[app.current];
                                        response.nr_of_players = nr_of_players;
                                        memcpy(*response.players, *players, MAX_PLAYERS * size_of(Entity));
                                    }
                                    response.game_state_index = app.current;
                                    server_send_message(server, client_id, xx GameChannel.RELIABLE, response);


                                    // should be broadcast to all connected clients
                                    uuid := server_get_client_id(server, client_id);
                                    x: u16 = xx(random_get() % TILES_X);
                                    y: u16 = xx(random_get() % TILES_Y);
                                    add_player(*GAME_STATES[app.current], uuid, x, y, false);
                                    for client_id: 0..MAX_CLIENTS-1 {
                                        message := cast(*NewPlayerMessage) server_create_message(server, client_id, xx GameMessageType.NEW_PLAYER);
                                        message.uuid, message.x, message.y, message.game_state_index = uuid, x, y, app.current;
                                        server_send_message(server, client_id, xx GameChannel.RELIABLE, message);
                                    }
                                }
                            }
                            server_release_message(server, client_id, message);
                            message = server_receive_message(server, client_id, xx GameChannel.RELIABLE);
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
                simulate(*GAME_STATES[app.current], *INPUT_STATES[app.current], FRAMETIME);
            }
            app.previous = (app.current - num_ticks + STATE_COUNT) % STATE_COUNT;
        }

        alpha := cast(float32) clamp(app.accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, alpha);
    }

    quit_app(*app);
}