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
    path: [PLAYER_PATH_COUNT]Vector2i;
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

ClientConnectData :: struct {}
ClientConnectMessage :: struct {
    using #as base: Message;
    using data: ClientConnectData;
    handshake: u16 = 69;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*ClientConnectMessage) message;
        serialize_bits(stream, *m.handshake, 16);
        return true;
    }
}

ClientConnectResponseData :: struct {
    state_index: s16;
    current_income_tick: float32;
    nr_of_players: s32;
    players: [MAX_PLAYERS]Player;
    tile_flags: [TILES_Y][TILES_X]TileFlags;
    areas: [MAX_AREAS]Area;
}
ClientConnectResponseMessage :: struct {
    using #as base: Message;
    using data: ClientConnectResponseData;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*ClientConnectResponseMessage) message;
        serialize_bits(stream, *m.state_index, 16);
        serialize_float(stream, *m.current_income_tick);

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
}

GameMessageFactory :: MessageFactory.{
    max_message_type = #run enum_highest_value(GameMessageType) + 1,
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

    union {
        server: *Server = null;
        client: *Client = null;
    }
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
    }
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
