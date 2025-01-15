#import "Basic";
#import "SDL";
#import "Math";
#load "renderer.jai";
#load "game.jai";
#load "input.jai";
#load "common.jai";

FRAMETIME   ::      1.0 / 60.0;
SCREEN_SIZE ::      Vector2.{ 800, 600 };

AppState :: struct {
    clock:        Clock;

    input_state:  *InputState;
    game_state:   *GameState;
    render_state: *RenderState;
}

init :: (args: []string) -> (AppState, bool) {
    SDL_Init(SDL_INIT_EVERYTHING);

    render_state, render_ok := make_render_state();
    if !render_ok return .{}, false;

    game_state, game_ok := make_game_state();
    if !game_ok return .{}, false;

    input_state := New(InputState);

    return AppState.{ clock_now(), input_state, game_state, render_state }, true;
}

quit :: (state: *AppState) {
    if state.render_state {
        if state.render_state.window    SDL_DestroyWindow(state.render_state.window);
        if state.render_state.renderer  SDL_DestroyRenderer(state.render_state.renderer);
    }
    SDL_Quit();
    exit(0);
}

main :: () {
    app, ok := init(get_command_line_arguments());
    if !ok quit(*app);

    accumulator: float64;
    alpha: float32;
    delta: float32;
    event: SDL_Event;
    while true {
        reset_temporary_storage();

        while SDL_PollEvent(*event)
            input(*app, *event);

        if app.input_state.exit == true break;

        delta = clock_reset(*app.clock);
        accumulator += delta;
        alpha = cast(float32, clamp(accumulator / FRAMETIME, 0.0, 1.0));
        while accumulator >= FRAMETIME {
            accumulator -= FRAMETIME;
            simulate(*app);
        }
        update(*app, delta);

        render(*app, alpha);
    }

    quit(*app);
}