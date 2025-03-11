#import "Basic";
#import "raylib";
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
        send_message(server, it, type, message_type, data);
    }
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
                case .PLAYER_CLICK_WORLD; {
                    msg := cast(*PlayerClickWorldMessage) message;
                    request := ActionRequest.{ action=.CLICK, position=msg.position, uuid=uuid };
                    perform_clean_action_request(*dummy_state, msg.state_index, *request);
                    assert(request.result.kind == .CLAIM_AREA, "request.result != .CLAIM_AREA");
                    assert(request.result.network_id != 0, "request.result.network_id == 0");
                    response_data := PlayerClaimAreaResponseData.{ msg.state_index, uuid, request.result.network_id, msg.position };
                    broadcast(server, .PLAYER_CLAIM_AREA_RESPONSE, PlayerClaimAreaResponseMessage, response_data);
                }

                case .PLAYER_MOVE; {
                    msg := cast(*PlayerMoveMessage) message;
                    request := ActionRequest.{ action=.MOVE, point=msg.point, uuid=uuid };
                    perform_clean_action_request(*dummy_state, msg.state_index, *request);
                    player := get_player(*dummy_state, uuid);
                    assert(player != null);

                    response_data := PlayerMoveResponseData.{ msg.state_index, uuid, msg.point, player.current_path_index+1, player.path };
                    broadcast(server, .PLAYER_MOVE_RESPONSE, PlayerMoveResponseMessage, response_data);

                    fast_forward_state_with_request(msg.state_index, app.current, request);
                }

                case .CLIENT_CONNECT; {
                    game_state = *GAME_STATES[app.current];
                    response_data := ClientConnectResponseData.{ state_index=app.current, nr_of_players=game_state.nr_of_players, players=game_state.players, areas=WORLD.areas };
                    for y: 0..TILES_Y-1
                        for x: 0..TILES_X-1
                            response_data.tile_flags[y][x] = WORLD.tiles[y][x].flags;
                    send_message(server, it, .CLIENT_CONNECT_RESPONSE, ClientConnectResponseMessage, response_data);

                    new_player_data := NewPlayerData.{ app.current, uuid, Vector2i.{ xx(random_get() % TILES_X), xx(random_get() % TILES_Y) } };
                    broadcast(server, .NEW_PLAYER, NewPlayerMessage, new_player_data);
                    add_player(game_state, uuid, new_player_data.point, false);
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

    game_state: *GameState;
    input_state: InputState;
    dummy_input: InputState;
    while !WindowShouldClose() {
        reset_temporary_storage();

        delta := clock_reset(*app.clock);
        app.accumulator += delta;
        app.network_manager.apollo_time += to_apollo(delta);

        check_input(*input_state, *dummy_input);
        update_view(*app.view, *input_state, delta);

        if !network_update(app.network_manager.server, app.network_manager.apollo_time)
            break;

        num_ticks := cast(u8, floor(app.accumulator / FRAMETIME));
        if num_ticks > 0 {
            process_messages(*app);

            for 0..num_ticks-1 {
                previous := app.current;
                app.current = next_state_index(app.current);
                game_state = *GAME_STATES[app.current];
                copy_game_state(game_state, *GAME_STATES[previous]);
                game_state.nr_of_actions = 0;

                log("simulating: %\n", app.current);
                simulate(game_state, FRAMETIME);
           }
           app.previous = prev_state_index(app.current, num_ticks);
           app.accumulator -= FRAMETIME * xx num_ticks;
        }

        app.render_state.alpha = cast(float32) clamp(app.accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, app.view);
    }

    quit_app(*app);
}