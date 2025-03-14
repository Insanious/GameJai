#load "view.jai";

FRAMETIME   :: 1.0 / 10.0;
SCREEN_SIZE :: Vector2.{ 800, 600 };

STATE_COUNT :: 256;
GAME_STATES : [STATE_COUNT]GameState;
WORLD       : World;

next_state_index :: (index: s16, increment: s16 = 1) -> s16 { return (index + increment) % STATE_COUNT; }
prev_state_index :: (index: s16, increment: s16 = 1) -> s16 { return (index - increment + STATE_COUNT) % STATE_COUNT; }
state_index_diff :: (low: s16, high: s16) -> s16            { return prev_state_index(high, low); }

fast_forward_state :: (start: s16, end: s16) {
    ticks := state_index_diff(start, end);
    log("fastforward %: %-%\n", ticks, start, end);
    current := start;
    for 0..ticks { // @NOTE: this will iterate atleast once!
        simulate(*GAME_STATES[current], FRAMETIME);
        next := next_state_index(current);

        copy_game_state(*GAME_STATES[next], *GAME_STATES[current]);
        current = next;
    }
}

fast_forward_state_with_request :: (start: s16, end: s16, request: ActionRequest) {
    copy_game_state(*GAME_STATES[start], *GAME_STATES[prev_state_index(start)]);
    add_action(*GAME_STATES[start], request);

    fast_forward_state(start, end);
}

perform_clean_action_request :: (game_state: *GameState, index: s16, request: *ActionRequest) -> (ActionResult, bool) {
    memcpy(game_state, *GAME_STATES[prev_state_index(index)], size_of(GameState));
    result, ok := perform_action_request(game_state, request);
    return result, ok;
}

AppState :: struct {
    clock: Clock;
    accumulator: float64 = 0;
    render_state: *RenderState = null;
    view: View;
    network_manager: *NetworkManager = null;

    current: s16 = 0;
    previous: s16 = 0;
}

init_app :: (args: []string) -> (AppState, bool) {
    render_state, render_ok := make_render_state();
    if !render_ok return .{}, false;

    init_world(*WORLD);

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
    CloseWindow();

    exit(0);
}