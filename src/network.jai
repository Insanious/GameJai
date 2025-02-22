SERVER_ADDRESS      :: "127.0.0.1";
SERVER_PORT         :: 60000;
WAIT_FOR_PACKETS_MS :: 16;
MAX_CLIENTS         :: 8;

PlayerMoveResponseMessage :: struct {
    using #as base: Message;

    game_state_index: s16;
    uuid: u64;

    x: u16;
    y: u16;
    count: s64;
    path: []Vector2i;

    serializer :: MessageSerializer.{
        create = () -> *Message { return New(PlayerMoveResponseMessage); },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*PlayerMoveResponseMessage) message;
            serialize_bits(stream, *m.game_state_index, 16);
            serialize_bits(stream, *m.uuid, 64);
            serialize_bits(stream, *m.x, 16);
            serialize_bits(stream, *m.y, 16);

            serialize_bits(stream, *m.count, 16);
            x, y: s32;
            if stream.isReading m.path = NewArray(m.count, Vector2i, initialized=false);
            for 0..m.count-1 {
                if stream.isWriting {
                    x, y = m.path[it].x, m.path[it].y;
                }
                if x > TILES_X || y > TILES_Y {
                    log("x, y: %, %\n", x, y);
                    log("m.path: %\n", m.path);
                }

                serialize_int(stream, *x, 0, TILES_X);
                serialize_int(stream, *y, 0, TILES_Y);

                if stream.isReading {
                    m.path[it] = .{x, y};
                }
            }

            return true;
        }
    };
}

PlayerMoveMessage :: struct {
    using #as base: Message;

    game_state_index: s16;

    x: u16;
    y: u16;

    serializer :: MessageSerializer.{
        create = () -> *Message { return New(PlayerMoveMessage); },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*PlayerMoveMessage) message;
            serialize_bits(stream, *m.x, 16);
            serialize_bits(stream, *m.y, 16);
            serialize_bits(stream, *m.game_state_index, 16);
            return true;
        }
    };
}

NewPlayerMessage :: struct {
    using #as base: Message;

    game_state_index: s16;
    uuid: u64;

    x: u16;
    y: u16;

    serializer :: MessageSerializer.{
        create = () -> *Message { return New(NewPlayerMessage); },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*NewPlayerMessage) message;
            serialize_bits(stream, *m.uuid, 64);
            serialize_bits(stream, *m.x, 16);
            serialize_bits(stream, *m.y, 16);
            serialize_bits(stream, *m.game_state_index, 16);
            return true;
        }
    };
}

ClientConnectMessage :: struct {
    using #as base: Message;

    handshake: u16 = 69;

    serializer :: MessageSerializer.{
        create = () -> *Message { return New(ClientConnectMessage); },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*ClientConnectMessage) message;
            serialize_bits(stream, *m.handshake, 16);
            return true;
        }
    };
}

ClientConnectResponseMessage :: struct {
    using #as base: Message;

    game_state_index: s16;

    nr_of_players: s32;
    players: [MAX_PLAYERS]Entity;

    serializer :: MessageSerializer.{
        create = () -> *Message { return New(ClientConnectResponseMessage); },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*ClientConnectResponseMessage) message;
            serialize_bits(stream, *m.game_state_index, 16);
            serialize_bits(stream, *m.nr_of_players, 32);
            for 0..m.nr_of_players-1 {
                player := *m.players[it];
                serialize_bits(stream, *player.uuid, 64);
                serialize_float(stream, *player.speed);
                serialize_float(stream, *player.position.x);
                serialize_float(stream, *player.position.y);
            }
            return true;
        }
    };
}

GameMessageType :: enum u16 {
    PLAYER_MOVE_RESPONSE;
    PLAYER_MOVE;
    NEW_PLAYER;
    CLIENT_CONNECT;
    CLIENT_CONNECT_RESPONSE;
}

GameMessageFactory: MessageFactory : MessageSerializer.[
    PlayerMoveResponseMessage.serializer,
    PlayerMoveMessage.serializer,
    NewPlayerMessage.serializer,
    ClientConnectMessage.serializer,
    ClientConnectResponseMessage.serializer,
];

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
        case .PLAYER_MOVE_RESPONSE;     log("% PLAYER_MOVE_RESPONSE\n", prefix);
        case .PLAYER_MOVE;              log("% PLAYER_MOVE\n", prefix);
        case .NEW_PLAYER;               log("% NEW_PLAYER\n", prefix);
        case .CLIENT_CONNECT;           log("% CLIENT_CONNECT\n", prefix);
        case .CLIENT_CONNECT_RESPONSE;  log("% CLIENT_CONNECT_RESPONSE\n", prefix);
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

network_manager_update :: (using network_manager: *NetworkManager, time: float32) -> bool {
    #if SERVER {
        server_send_packets(server);
        server_receive_packets(server);
        server_advance_time(server, apollo_time);

        if !server.running
            return false;
    }

    #if CLIENT {
        client_send_packets(client);
        client_receive_packets(client);
        client_advance_time(client, apollo_time);

        if client.clientState == .Disconnected
            return false;
    }

    return true;
}

deinit :: (using network_manager: *NetworkManager) {
    #if SERVER server_stop(server);

    #if CLIENT client_disconnect(client);
}