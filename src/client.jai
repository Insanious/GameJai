make_client :: (using network_manager: *NetworkManager) {
    apollo_time = seconds_to_apollo(100);
    server_address = address_init_v4(SERVER_ADDRESS, SERVER_PORT);

    client = New(Client);
    client_id := random_get();
    log("client_id: %\n", client_id);
    client_address := address_init_v4("0.0.0.0");

    client_init(client, client_address, config, GameMessageFactory, apollo_time);
    client_insecure_connect(client, private_key, client_id, server_address);

    log("client address is %\n", address_to_string(client.boundAddress,, temp));
}

network_update :: (client: *Client, time: Apollo_Time) -> bool {
    client_send_packets(client);
    client_receive_packets(client);
    client_advance_time(client, time);

    return client.clientState != .Disconnected;
}

send_message :: (client: *Client, type: GameMessageType, $message_type: Type, data: $T) {
    message := cast(*message_type) client_create_message(client, xx type);
    message.data = data;
    client_send_message(client, xx GameChannel.RELIABLE, message);
}

send_actions_to_server :: (app: *AppState, game_state: *GameState) {
    client := app.network_manager.client;
    for 0..game_state.nr_of_actions-1 {
        action := game_state.actions[it];
        if #complete action.kind == {
            case .MOVE;       send_message(client, .PLAYER_MOVE, PlayerMoveMessage, PlayerMoveData.{ app.current, action.point });
            case .ADD_PLAYER; send_message(client, .CLIENT_CONNECT, ClientConnectMessage, ClientConnectData.{});
            case .CLICK;      send_message(client, .PLAYER_CLICK_WORLD, PlayerClickWorldMessage, PlayerClickWorldData.{ app.current, action.position });
        }
    }
}



process_messages :: (app: *AppState) {
    client := app.network_manager.client;
    if !client_is_connected(client) return;

    message := client_receive_message(client, xx GameChannel.RELIABLE);
    while message != null {
        log_message_type("Got message", cast(GameMessageType) message.type);

        if cast(GameMessageType) message.type == {
            case .NEW_PLAYER;                 process_new_player_message(xx message, app, client.clientId);
            case .CLIENT_CONNECT_RESPONSE;    process_client_connect_response_message(xx message, app, client.clientId);
            case .PLAYER_MOVE_RESPONSE;       process_player_move_response_message(xx message, app, client.clientId);
            case .PLAYER_CLAIM_AREA_RESPONSE; process_player_claim_area_response_message(xx message, app, client.clientId);
        }

        client_release_message(client, message);
        message = client_receive_message(client, xx GameChannel.RELIABLE);
    }
}

process_new_player_message :: (msg: *NewPlayerMessage, app: *AppState, uuid: u64) {
    // @Note: this requires special handling since when the player first joins, there is
    //        no previous state and the current_income_tick will be the default value of 0

    current_income_tick := GAME_STATES[app.current].current_income_tick;
    game_state := *GAME_STATES[msg.state_index];
    copy_game_state(game_state, *GAME_STATES[prev_state_index(msg.state_index)]);

    add_player(game_state, msg.uuid, msg.point, msg.uuid == uuid);
    fast_forward_state(msg.state_index, app.current);

    GAME_STATES[app.current].current_income_tick = current_income_tick;
}

process_client_connect_response_message :: (msg: *ClientConnectResponseMessage, app: *AppState, uuid: u64) {
    // @NOTE: sync game state index here for now
    app.current = msg.state_index;
    app.previous = prev_state_index(msg.state_index);
    GAME_STATES[app.current].nr_of_players = msg.nr_of_players;
    GAME_STATES[app.current].players = msg.players;
    GAME_STATES[app.current].current_income_tick = msg.current_income_tick;
    WORLD.areas = msg.areas;
    for y: 0..TILES_Y-1
        for x: 0..TILES_X-1
            WORLD.tiles[y][x].flags = msg.tile_flags[y][x];
}

process_player_move_response_message :: (msg: *PlayerMoveResponseMessage, app: *AppState, uuid: u64) {
    player := get_player(*GAME_STATES[app.current], msg.uuid);
    assert(player != null, ".PLAYER_MOVE_RESPONSE 1: player == null");
    position_to_interpolate_to := ifx player.is_interpolating then player.interpolated_position else player.position;

    game_state := *GAME_STATES[msg.state_index];
    copy_game_state(game_state, *GAME_STATES[prev_state_index(msg.state_index)]);

    if msg.uuid == uuid
         remove_action(game_state, ActionRequest.{ kind=.MOVE, uuid=msg.uuid, point=msg.point });

    player = get_player(game_state, msg.uuid);
    assert(player != null, tprint("perform_action_request: Found no player with uuid == %", msg.uuid));

    for tiles: WORLD.tiles
        for * tile: tiles
            tile.flags &= ~.PATH;

    for 0..msg.count-1 {
        vec := msg.path[it];
        player.path[it] = vec;
        WORLD.tiles[vec.y][vec.x].flags |= .PATH;
    }
    player.current_path_index = xx(msg.count-1);

    if player.current_path_index >= 0 player.state = .RUNNING;
    else                              player.state = .IDLE;


    fast_forward_state(msg.state_index, app.current);

    if msg.uuid != uuid {
        player = get_player(*GAME_STATES[app.current], msg.uuid);
        assert(player != null, ".PLAYER_MOVE_RESPONSE 2: player == null");
        player.is_interpolating = true;
        player.interpolated_position = position_to_interpolate_to;
    }
}

process_player_claim_area_response_message :: (msg: *PlayerClaimAreaResponseMessage, app: *AppState, uuid: u64) {
    game_state := *GAME_STATES[msg.state_index];
    copy_game_state(game_state, *GAME_STATES[prev_state_index(msg.state_index)]);

    if msg.uuid == uuid
         remove_action(game_state, ActionRequest.{ kind=.CLICK, uuid=msg.uuid, position=msg.position });

    for 0..MAX_AREAS-1 {
        area := *WORLD.areas[it];
        if area.network_id == msg.network_id {
            for index: area.entrance WORLD.tiles[index.y][index.x].flags |= .WHITELISTED;
            area.owner_uuid = msg.uuid;
            get_player(game_state, msg.uuid).gold_income += 1;
            break;
        }
    }
    fast_forward_state(msg.state_index, app.current);
}