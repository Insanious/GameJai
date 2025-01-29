SERVER_ADDRESS      :: "127.0.0.1";
SERVER_PORT         :: 60000;
WAIT_FOR_PACKETS_MS :: 16;
MAX_CLIENTS         :: 8;

TestMessage :: struct {
    using #as base: Message;

    sequence: u16;

    serializer :: MessageSerializer.{
        create = () -> *Message {
            return New(TestMessage);
        },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*TestMessage) message;
            serialize_bits(stream, *m.sequence, 16);
            return true;
        }
    };
}

TestMessageFactory: MessageFactory : MessageSerializer.[
    TestMessage.serializer,
];

NetworkManager :: struct {
    apollo_time: Apollo_Time;
    config: ClientServerConfig;
    private_key: [KeyBytes] u8;
    server_address : IPAddress;

    server: *Server = null;
    client: *Client = null;
}

make_network_manager :: (using network_manager: *NetworkManager) {
    apollo_time = seconds_to_apollo(100);
    server_address = address_init_v4(SERVER_ADDRESS, SERVER_PORT);

    #if SERVER {
        server = New(Server);
        server.onClientConnected = on_client_connected_override;
        server_init(server, private_key, server_address, config, TestMessageFactory, apollo_time);
        server_start(server, MAX_CLIENTS);

        log("server address is %\n", address_to_string(server_address,, temp));
    }

    #if CLIENT {
        client = New(Client);
        client_id := random_get();
        client_address := address_init_v4("0.0.0.0");

        client_init(client, client_address, config, TestMessageFactory, apollo_time);
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