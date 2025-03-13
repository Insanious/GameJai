make_server :: (using network_manager: *NetworkManager) {
    apollo_time = seconds_to_apollo(100);
    server_address = address_init_v4(SERVER_ADDRESS, SERVER_PORT);

    server = New(Server);
    server_init(server, private_key, server_address, config, GameMessageFactory, apollo_time);
    server_start(server, MAX_CLIENTS);

    log("server address is %\n", address_to_string(server_address,, temp));
}

network_update :: (server: *Server, time: Apollo_Time) -> bool {
    server_send_packets(server);
    server_receive_packets(server);
    server_advance_time(server, time);

    return server.running;
}

send_message :: (server: *Server, client: int, type: GameMessageType, $message_type: Type, data: $T) {
    message := cast(*message_type) server_create_message(server, client, xx type);
    message.data = data;
    server_send_message(server, client, xx GameChannel.RELIABLE, message);
}

broadcast :: (server: *Server, type: GameMessageType, $message_type: Type, data: $T) {
    for 0..MAX_CLIENTS-1 {
        if !server_is_client_connected(server, it) continue;
        send_message(server, it, type, message_type, data);
    }
}



DUMMY_STATE: GameState;
process_messages :: (app: *AppState) {
    server := app.network_manager.server;
    for 0..MAX_CLIENTS-1 {
        if !server_is_client_connected(server, it) continue;

        message := server_receive_message(server, it, xx GameChannel.RELIABLE);
        while message != null {
            uuid := server_get_client_id(server, it);
            log_message_type("Got message", cast(GameMessageType) message.type);

            if cast(GameMessageType) message.type == {
                case .PLAYER_CLICK_WORLD; process_player_click_world_message(xx message, app, server, uuid);
                case .PLAYER_MOVE;        process_player_move_message(xx message, app, server, uuid);
                case .CLIENT_CONNECT;     process_client_connect_message(xx message, app, server, uuid, it);
                case; assert(false, "got some weird message...");
            }
            server_release_message(server, it, message);
            message = server_receive_message(server, it, xx GameChannel.RELIABLE);
        }
    }
}

process_player_click_world_message :: (msg: *PlayerClickWorldMessage, app: *AppState, server: *Server, uuid: u64) {
    request := ActionRequest.{ kind=.CLICK, position=msg.position, uuid=uuid };
    result, ok := perform_clean_action_request(*DUMMY_STATE, msg.state_index, *request);
    if !ok return;

    if result.kind == .CLAIM_AREA {
        response_data := PlayerClaimAreaResponseData.{ msg.state_index, uuid, result.network_id, msg.position };
        broadcast(server, .PLAYER_CLAIM_AREA_RESPONSE, PlayerClaimAreaResponseMessage, response_data);
        // @NOTE: fast forward not necessary since this is just updating the global WORLD directly, instead of a specific game_state
    } else {
        assert(false, "result.kind != .CLAIM_AREA");
    }
}

process_player_move_message :: (msg: *PlayerMoveMessage, app: *AppState, server: *Server, uuid: u64) {
    request := ActionRequest.{ kind=.MOVE, point=msg.point, uuid=uuid };
    perform_clean_action_request(*DUMMY_STATE, msg.state_index, *request);
    player := get_player(*DUMMY_STATE, uuid);
    assert(player != null);

    response_data := PlayerMoveResponseData.{ msg.state_index, uuid, msg.point, player.current_path_index+1, player.path };
    broadcast(server, .PLAYER_MOVE_RESPONSE, PlayerMoveResponseMessage, response_data);

    fast_forward_state_with_request(msg.state_index, app.current, request);
}

process_client_connect_message :: (msg: *PlayerMoveMessage, app: *AppState, server: *Server, uuid: u64, client: int) {
    current_state := *GAME_STATES[app.current];
    response_data := ClientConnectResponseData.{ state_index=app.current, nr_of_players=current_state.nr_of_players, players=current_state.players, areas=WORLD.areas };
    for y: 0..TILES_Y-1
        for x: 0..TILES_X-1
            response_data.tile_flags[y][x] = WORLD.tiles[y][x].flags;
    send_message(server, client, .CLIENT_CONNECT_RESPONSE, ClientConnectResponseMessage, response_data);

    new_player_data := NewPlayerData.{ app.current, uuid, Vector2i.{ xx(random_get() % TILES_X), xx(random_get() % TILES_Y) } };
    broadcast(server, .NEW_PLAYER, NewPlayerMessage, new_player_data);
    add_player(current_state, uuid, new_player_data.point, false);
}