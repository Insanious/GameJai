AppState :: struct {
    clock: Clock;
    accumulator: float64 = 0;
    render_state: *RenderState = null;
    network_manager: *NetworkManager = null;

    current: s16 = 0;
    previous: s16 = 0;
}

init_app :: (args: []string) -> (AppState, bool) {
    SDL_Init(SDL_INIT_EVERYTHING);

    render_state, render_ok := make_render_state();
    if !render_ok return .{}, false;

    init_game_state(*GAME_STATES[0]);

    network_manager: *NetworkManager = null;
    #if SERVER || CLIENT {
        network_manager = New(NetworkManager);
        #if SERVER make_server(network_manager);
        #if CLIENT make_client(network_manager);
    }

    return AppState.{ clock=clock_now(), render_state=render_state, network_manager=network_manager }, true;
}

quit_app :: (using state: *AppState) {
    if network_manager deinit(network_manager);

    if render_state {
        if render_state.window    SDL_DestroyWindow(render_state.window);
        if render_state.renderer  SDL_DestroyRenderer(render_state.renderer);
    }
    SDL_Quit();
    exit(0);
}