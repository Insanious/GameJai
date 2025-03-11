SERVER_ADDRESS      :: "127.0.0.1";
SERVER_PORT         :: 60000;
WAIT_FOR_PACKETS_MS :: 16;
MAX_CLIENTS         :: 8;

// Serialize Vector2
serialize_struct :: (stream: *Stream, vector: *Vector2) -> bool {
    serialize_float(stream, *vector.x);
    serialize_float(stream, *vector.y);
    return true;
}

// Serialize Vector2i
serialize_struct :: (stream: *Stream, vector: *Vector2i, min: Vector2i, max: Vector2i) -> bool {
    serialize_int(stream, *vector.x, min.x, max.x);
    serialize_int(stream, *vector.y, min.y, max.y);
    return true;
}

// Serialize Rect
serialize_struct :: (stream: *Stream, rect: *Rect) -> bool {
    serialize_struct(stream, *rect.top_left);
    serialize_struct(stream, *rect.size);
    return true;
}

// Serialize IntRect
serialize_struct :: (stream: *Stream, rect: *IntRect, min: Vector2i, max: Vector2i) -> bool {
    serialize_struct(stream, *rect.top_left, min, max);
    serialize_struct(stream, *rect.size, min, max);
    return true;
}

PlayerClaimAreaResponseData :: struct {
    state_index: s16;
    uuid: u64;
    network_id: u32;
    position: Vector2;
}
PlayerClaimAreaResponseMessage :: struct {
    using #as base: Message;
    using data: PlayerClaimAreaResponseData;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*PlayerClaimAreaResponseMessage) message;
        serialize_bits(stream, *m.state_index, 16);
        serialize_bits(stream, *m.uuid, 64);
        serialize_bits(stream, *m.network_id, 32);
        serialize_struct(stream, *m.position);
        return true;
    }
}

PlayerClickWorldData :: struct {
    state_index: s16;
    position: Vector2;
}
PlayerClickWorldMessage :: struct {
    using #as base: Message;
    using data: PlayerClickWorldData;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*PlayerClickWorldMessage) message;
        serialize_bits(stream, *m.state_index, 16);
        serialize_struct(stream, *m.position);
        return true;
    }
}

PlayerMoveResponseData :: struct {
    state_index: s16;
    uuid: u64;
    point: Vector2i;
    count: s64;
    path: [ENTITY_PATH_COUNT]Vector2i;
}
PlayerMoveResponseMessage :: struct {
    using #as base: Message;
    using data: PlayerMoveResponseData;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*PlayerMoveResponseMessage) message;
        serialize_bits(stream, *m.state_index, 16);
        serialize_bits(stream, *m.uuid, 64);
        serialize_struct(stream, *m.point, MIN_TILES, MAX_TILES);

        serialize_bits(stream, *m.count, 16);
        for 0..m.count-1
            serialize_struct(stream, *m.path[it], MIN_TILES, MAX_TILES);

        return true;
    }
}

PlayerMoveData :: struct {
    state_index: s16;
    point: Vector2i;
}
PlayerMoveMessage :: struct {
    using #as base: Message;
    using data: PlayerMoveData;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*PlayerMoveMessage) message;
        serialize_bits(stream, *m.state_index, 16);
        serialize_struct(stream, *m.point, MIN_TILES, MAX_TILES);
        return true;
    }
}

NewPlayerData :: struct {
    state_index: s16;
    uuid: u64;
    point: Vector2i;
}
NewPlayerMessage :: struct {
    using #as base: Message;
    using data: NewPlayerData;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*NewPlayerMessage) message;
        serialize_bits(stream, *m.state_index, 16);
        serialize_bits(stream, *m.uuid, 64);
        serialize_struct(stream, *m.point, MIN_TILES, MAX_TILES);
        return true;
    }
}

ClientConnectMessage :: struct {
    using #as base: Message;

    handshake: u16 = 69;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*ClientConnectMessage) message;
        serialize_bits(stream, *m.handshake, 16);
        return true;
    }
}

ClientConnectResponseData :: struct {
    state_index: s16;
    nr_of_players: s32;
    players: [MAX_PLAYERS]Entity;
    tile_flags: [TILES_Y][TILES_X]TileFlags;
    areas: [MAX_AREAS]Area;
}
ClientConnectResponseMessage :: struct {
    using #as base: Message;
    using data: ClientConnectResponseData;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*ClientConnectResponseMessage) message;
        serialize_bits(stream, *m.state_index, 16);
        serialize_bits(stream, *m.nr_of_players, 32);
        for 0..m.nr_of_players-1 {
            player := *m.players[it];
            serialize_bits(stream, *player.uuid, 64);
            serialize_float(stream, *player.speed);
            serialize_float(stream, *player.position.x);
            serialize_float(stream, *player.position.y);
        }

        for y: 0..TILES_Y-1
            for x: 0..TILES_X-1
                serialize_bits(stream, *m.tile_flags[y][x], 8);

        for 0..MAX_AREAS-1 {
            serialize_bits(stream, *m.areas[it].network_id, 32);
            serialize_struct(stream, *m.areas[it].rect, MIN_TILES, MAX_TILES);
            serialize_struct(stream, *m.areas[it].entrance_btn);
            serialize_struct(stream, *m.areas[it].entrance_btn);
            for entrance_idx: 0..ENTRANCE_SIZE-1
                serialize_struct(stream, *m.areas[it].entrance[entrance_idx], MIN_TILES, MAX_TILES);
        }

        return true;
    }
}

GameMessageType :: enum u16 {
    PLAYER_CLAIM_AREA_RESPONSE;
    PLAYER_CLICK_WORLD;
    PLAYER_MOVE_RESPONSE;
    PLAYER_MOVE;
    NEW_PLAYER;
    CLIENT_CONNECT;
    CLIENT_CONNECT_RESPONSE;
    NUM_MESSAGE_TYPES;
}

GameMessageFactory :: MessageFactory.{
    max_message_type = xx GameMessageType.NUM_MESSAGE_TYPES,
    create = (message_type: u16) -> *Message {
        type := message_type.(GameMessageType);
        if #complete type == {
            case .PLAYER_CLAIM_AREA_RESPONSE; return New(PlayerClaimAreaResponseMessage);
            case .PLAYER_CLICK_WORLD;         return New(PlayerClickWorldMessage);
            case .PLAYER_MOVE_RESPONSE;       return New(PlayerMoveResponseMessage);
            case .PLAYER_MOVE;                return New(PlayerMoveMessage);
            case .NEW_PLAYER;                 return New(NewPlayerMessage);
            case .CLIENT_CONNECT;             return New(ClientConnectMessage);
            case .CLIENT_CONNECT_RESPONSE;    return New(ClientConnectResponseMessage);
            case .NUM_MESSAGE_TYPES;          return null;
        }
    },
    serialize = (stream: *Stream, message: *Message) -> bool {
        type := message.type.(GameMessageType);
        if #complete type == {
            case .PLAYER_CLAIM_AREA_RESPONSE; return PlayerClaimAreaResponseMessage.serialize(stream, message);
            case .PLAYER_CLICK_WORLD;         return PlayerClickWorldMessage.serialize(stream, message);
            case .PLAYER_MOVE_RESPONSE;       return PlayerMoveResponseMessage.serialize(stream, message);
            case .PLAYER_MOVE;                return PlayerMoveMessage.serialize(stream, message);
            case .NEW_PLAYER;                 return NewPlayerMessage.serialize(stream, message);
            case .CLIENT_CONNECT;             return ClientConnectMessage.serialize(stream, message);
            case .CLIENT_CONNECT_RESPONSE;    return ClientConnectResponseMessage.serialize(stream, message);
            case .NUM_MESSAGE_TYPES;          return false;
        }
    }
};

GameChannel :: enum u16 {
    RELIABLE;
    UNRELIABLE;
}

NetworkManager :: struct {
    apollo_time: Apollo_Time;
    config: ClientServerConfig;
    private_key: [KeyBytes] u8;
    server_address : IPAddress;

    server: *Server = null;
    client: *Client = null;
}

log_message_type :: (prefix: string, type: GameMessageType) {
    if #complete type == {
        case .PLAYER_CLAIM_AREA_RESPONSE; log("% PLAYER_CLAIM_AREA_RESPONSE\n", prefix);
        case .PLAYER_CLICK_WORLD;         log("% PLAYER_CLICK_WORLD\n",         prefix);
        case .PLAYER_MOVE_RESPONSE;       log("% PLAYER_MOVE_RESPONSE\n",       prefix);
        case .PLAYER_MOVE;                log("% PLAYER_MOVE\n",                prefix);
        case .NEW_PLAYER;                 log("% NEW_PLAYER\n",                 prefix);
        case .CLIENT_CONNECT;             log("% CLIENT_CONNECT\n",             prefix);
        case .CLIENT_CONNECT_RESPONSE;    log("% CLIENT_CONNECT_RESPONSE\n",    prefix);
        case .NUM_MESSAGE_TYPES;          log("% NUM_MESSAGE_TYPES\n",          prefix);
    }
}

make_server :: (using network_manager: *NetworkManager) {
    apollo_time = seconds_to_apollo(100);
    server_address = address_init_v4(SERVER_ADDRESS, SERVER_PORT);

    server = New(Server);
    server_init(server, private_key, server_address, config, GameMessageFactory, apollo_time);
    server_start(server, MAX_CLIENTS);

    log("server address is %\n", address_to_string(server_address,, temp));
}

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

make_network_manager :: (using network_manager: *NetworkManager) {
    apollo_time = seconds_to_apollo(100);
    server_address = address_init_v4(SERVER_ADDRESS, SERVER_PORT);

    #if SERVER {
        server = New(Server);
        server_init(server, private_key, server_address, config, GameMessageFactory, apollo_time);
        server_start(server, MAX_CLIENTS);

        log("server address is %\n", address_to_string(server_address,, temp));
    }

    #if CLIENT {
        client = New(Client);
        client_id := random_get();
        client_address := address_init_v4("0.0.0.0");

        client_init(client, client_address, config, GameMessageFactory, apollo_time);
        client_insecure_connect(client, private_key, client_id, server_address);

        log("client address is %\n", address_to_string(client.boundAddress,, temp));
    }
}

network_update :: (server: *Server, time: Apollo_Time) -> bool {
    server_send_packets(server);
    server_receive_packets(server);
    server_advance_time(server, time);

    return server.running;
}

network_update :: (client: *Client, time: Apollo_Time) -> bool {
    client_send_packets(client);
    client_receive_packets(client);
    client_advance_time(client, time);

    return client.clientState != .Disconnected;
}

send_message :: (server: *Server, client: int, type: GameMessageType, $message_type: Type, data: $T) {
    message := cast(*message_type) server_create_message(server, client, xx type);
    message.data = data;
    server_send_message(server, client, xx GameChannel.RELIABLE, message);
}

send_message :: (client: *Client, type: GameMessageType, $message_type: Type, data: $T) {
    message := cast(*message_type) client_create_message(client, xx type);
    message.data = data;
    client_send_message(client, xx GameChannel.RELIABLE, message);
}

deinit :: (using network_manager: *NetworkManager) {
    #if SERVER server_stop(server);

    #if CLIENT client_disconnect(client);
}

current_network_id: u32 = 0;
get_new_network_id :: () -> u32 {
    current_network_id += 1;
    return current_network_id;
}
