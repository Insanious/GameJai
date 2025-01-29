#import "Basic";
#import "SDL";
#import "Math";
#import "Random";
#import "Yojimbo"()(ENABLE_LOGGING=true);
#import "IPAddress"()(ENABLE_LOGGING=true);
#import "Serialize"()(ENABLE_LOGGING=true);
#import "Reliable"()(ENABLE_LOGGING=true);
#load "renderer.jai";
#load "game.jai";
#load "input.jai";
#load "common.jai";
#load "network.jai";

FRAMETIME   :: 1.0 / 60.0;
SCREEN_SIZE :: Vector2i.{ 800, 600 };

STATE_COUNT :: 256;
GAME_STATES : [STATE_COUNT]GameState;
INPUT_STATES: [STATE_COUNT]InputState;


AppState :: struct {
    clock: Clock;
    render_state: *RenderState;

    current: s16 = 0;
    previous: s16 = 0;
}

init :: (args: []string) -> (AppState, bool) {
    SDL_Init(SDL_INIT_EVERYTHING);

    render_state, render_ok := make_render_state();
    if !render_ok return .{}, false;

    init_game_state(*GAME_STATES[0]);

    return AppState.{ clock=clock_now(), render_state=render_state }, true;
}

quit :: (using state: *AppState, network_manager: *NetworkManager = null) {
    if network_manager deinit(network_manager);

    if render_state {
        if render_state.window    SDL_DestroyWindow(render_state.window);
        if render_state.renderer  SDL_DestroyRenderer(render_state.renderer);
    }
    SDL_Quit();
    exit(0);
}

on_client_connected_override :: (server: *Server, clientIndex: int) {
    log("on_client_connected_override w/ client '%'\n", clientIndex);
}

logger :: (message: string, data: *void, info: Log_Info) {
    if !message
        return;
    if info.common_flags & .VERY_VERBOSE_ONLY && context.log_level < .VERY_VERBOSE
        return;
    if info.common_flags & .VERBOSE_ONLY && context.log_level < .VERBOSE
        return;

    to_standard_error := false;

    if message[message.count-1] != #char "\n" {
        write_strings(message, "\n", to_standard_error = to_standard_error);
    } else {
        write_string(message, to_standard_error = to_standard_error);
    }
}

main :: () {
    context.logger = logger;
    context.log_level = .VERY_VERBOSE;

    app, ok := init(get_command_line_arguments());
    if !ok quit(*app, null);
    if !yojimbo_init() quit(*app, null);

    network_manager: NetworkManager;
    make_network_manager(*network_manager);

    accumulator: float64;
    event: SDL_Event;
    previous_input: InputState;
    accumulated_input: InputState;
    game_state: *GameState;
    input_state: *InputState;

    while true {
        reset_temporary_storage();

        while SDL_PollEvent(*event)
            input(*accumulated_input, *previous_input, *event);

        if accumulated_input.exit == true break;

        delta := clock_reset(*app.clock);
        accumulator += delta;
        num_ticks := cast(u8, floor(accumulator / FRAMETIME));

        network_manager.apollo_time += to_apollo(delta);

        if num_ticks > 0 {
            if !network_manager_update(*network_manager, delta)
                break;

            accumulator -= FRAMETIME * xx num_ticks;
            for 0..num_ticks-1 {
                previous := app.current;
                app.current = (app.current + 1) % STATE_COUNT;

                game_state = *GAME_STATES[app.current];
                input_state = *INPUT_STATES[app.current];

                memcpy(game_state, *GAME_STATES[previous], size_of(GameState));
                memcpy(input_state, *accumulated_input, size_of(InputState));

                SDL_GetMouseState(xx *input_state.mouse_position.x, xx *input_state.mouse_position.y);

                simulate(game_state, input_state, FRAMETIME);

                // reset transient inputs
                accumulated_input.LMB_pressed = false;
                accumulated_input.RMB_pressed = false;
                accumulated_input.scroll_delta = 0;
            }
            memcpy(*previous_input, *accumulated_input, size_of(InputState));
            app.previous = (app.current - num_ticks + STATE_COUNT) % STATE_COUNT;
        }

        alpha := cast(float32) clamp(accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, alpha);
    }

    quit(*app, *network_manager);
}