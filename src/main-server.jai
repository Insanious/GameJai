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

broadcast :: (server: *Server, type: GameMessageType, $message_type: Type, data: $T) {
    for 0..MAX_CLIENTS-1 {
        if !server_is_client_connected(server, it) continue;
        send_to_client(server, it, type, message_type, data);
    }
}

send_to_client :: (server: *Server, client: int, type: GameMessageType, $message_type: Type, data: $T) {
    msg := cast(*message_type) server_create_message(server, client, xx type);
    msg.data = data;
    server_send_message(server, client, xx GameChannel.RELIABLE, msg);
}

process_messages :: (app: *AppState) {
    dummy_state: GameState;
    game_state: *GameState = null;
    using app.network_manager;
    for 0..MAX_CLIENTS-1 {
        if !server_is_client_connected(server, it) continue;

        message := server_receive_message(server, it, xx GameChannel.RELIABLE);
        while message != null {
            uuid := server_get_client_id(server, it);
            log_message_type("Got message", cast(GameMessageType) message.type);

            if cast(GameMessageType) message.type == {
                case .PLAYER_MOVE; {
                    msg := cast(*PlayerMoveMessage) message;
                    request := ActionRequest.{ action=.MOVE, x=msg.x, y=msg.y, uuid=uuid };
                    perform_clean_action_request(*dummy_state, msg.state_index, request);
                    player := get_player(*dummy_state, uuid);
                    assert(player != null);

                    response_data := PlayerMoveResponseData.{ msg.state_index, uuid, msg.x, msg.y, player.current_path_index+1, player.path };
                    broadcast(server, .PLAYER_MOVE_RESPONSE, PlayerMoveResponseMessage, response_data);

                    fast_forward_state_with_request(msg.state_index, next_state_index(app.current), request);
                }

                case .CLIENT_CONNECT; {
                    game_state = *GAME_STATES[app.current];
                    response_data := ClientConnectResponseData.{ app.current, game_state.nr_of_players, game_state.players };
                    send_to_client(server, it, .CLIENT_CONNECT_RESPONSE, ClientConnectResponseMessage, response_data);

                    new_player_data := NewPlayerData.{ app.current, uuid, xx(random_get() % TILES_X), xx(random_get() % TILES_Y) };
                    broadcast(server, .NEW_PLAYER, NewPlayerMessage, new_player_data);
                    add_player(game_state, uuid, new_player_data.x, new_player_data.y, false);
                }
            }
            server_release_message(server, it, message);
            message = server_receive_message(server, it, xx GameChannel.RELIABLE);
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
                case .SDL_EVENT_QUIT; quit_app(*app);
                case .SDL_EVENT_KEY_DOWN; if event.key.key == SDLK_ESCAPE then quit_app(*app);
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