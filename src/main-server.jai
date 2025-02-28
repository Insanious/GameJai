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

process_messages :: (app: *AppState) {
    using app.network_manager;
    for client_id: 0..MAX_CLIENTS-1 {
        if !server_is_client_connected(server, client_id) continue;

        message := server_receive_message(server, client_id, xx GameChannel.RELIABLE);
        while message != null {
            log_message_type("Got message", cast(GameMessageType) message.type);

            if cast(GameMessageType) message.type == {
                case .PLAYER_MOVE; {
                    msg := cast(*PlayerMoveMessage) message;
                    uuid := server_get_client_id(server, client_id);
                    request := ActionRequest.{ action=.MOVE, x=msg.x, y=msg.y, uuid=uuid };
                    result, ok := perform_clean_action_request(msg.state_index, request);
                    if !ok break;

                    for c_id: 0..MAX_CLIENTS-1 {
                        if !server_is_client_connected(server, c_id)
                            continue;

                        response := cast(*PlayerMoveResponseMessage) server_create_message(server, client_id, xx GameMessageType.PLAYER_MOVE_RESPONSE);
                        response.data = PlayerMoveResponseData.{ state_index=msg.state_index, uuid=uuid, x=msg.x, y=msg.y, count=result.path.count };
                        for 0..result.path.count-1 // @NOTE: cant memcpy this, not sure why though (maybe [] != [..] ?)
                            response.data.path[it] = result.path[it];

                        server_send_message(server, c_id, xx GameChannel.RELIABLE, response);
                    }

                    fast_forward_state_with_request(msg.state_index, next_state_index(app.current), request);
                }

                case .CLIENT_CONNECT; {
                    response := cast(*ClientConnectResponseMessage) server_create_message(server, client_id, xx GameMessageType.CLIENT_CONNECT_RESPONSE);
                    response.data = ClientConnectResponseData.{ state_index=app.current, nr_of_players=GAME_STATES[app.current].nr_of_players };
                    memcpy(*response.data.players, *GAME_STATES[app.current].players, MAX_PLAYERS * size_of(Entity));
                    server_send_message(server, client_id, xx GameChannel.RELIABLE, response);

                    // should be broadcast to all connected clients
                    uuid := server_get_client_id(server, client_id);
                    x: u16 = xx(random_get() % TILES_X);
                    y: u16 = xx(random_get() % TILES_Y);
                    add_player(*GAME_STATES[app.current], uuid, x, y, false);
                    for c_id: 0..MAX_CLIENTS-1 {
                        if !server_is_client_connected(server, c_id)
                            continue;

                        message := cast(*NewPlayerMessage) server_create_message(server, c_id, xx GameMessageType.NEW_PLAYER);
                        message.data = NewPlayerData.{ state_index=app.current, uuid=uuid, x=x, y=y };
                        server_send_message(server, c_id, xx GameChannel.RELIABLE, message);
                    }
                }
            }
            server_release_message(server, client_id, message);
            message = server_receive_message(server, client_id, xx GameChannel.RELIABLE);
        }
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
        if !network_manager_update(app.network_manager)
            break;
        num_ticks := cast(u8, floor(app.accumulator / FRAMETIME));

        if num_ticks > 0 {
            app.accumulator -= FRAMETIME * xx num_ticks;
            process_messages(*app);

            app.previous = prev_state_index(app.current, num_ticks);
            for 0..num_ticks-1 {
                previous := app.current;
                app.current = next_state_index(app.current);
                game_state = *GAME_STATES[app.current];
                memcpy(game_state, *GAME_STATES[previous], size_of(GameState));
                game_state.nr_of_actions = 0;

                log("simulating: %\n", app.current);
                simulate(game_state, FRAMETIME);
           }
           app.previous = prev_state_index(app.current, num_ticks);
        }

        alpha := cast(float32) clamp(app.accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, app.view, alpha);
    }

    quit_app(*app);
}