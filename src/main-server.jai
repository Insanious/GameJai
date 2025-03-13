#import "Basic";
#import "raylib";
#import "Math";
#import "Random";
#import "Yojimbo"()(ENABLE_LOGGING=true);
#import "IPAddress"()(ENABLE_LOGGING=true);
#import "Serialize"()(ENABLE_LOGGING=true);
#import "Reliable";
#load "renderer.jai";
#load "game.jai";
#load "input.jai";
#load "common/common.jai";
#load "network.jai";
#load "infrastructure.jai";
#load "server.jai";

main :: () {
    if !yojimbo_init() exit(0);

    app, ok := init_app(get_command_line_arguments());
    if !ok
        quit_app(*app);

    game_state: *GameState;
    input_state: InputState;
    dummy_input: InputState;
    while !WindowShouldClose() {
        reset_temporary_storage();

        delta := clock_reset(*app.clock);
        app.accumulator += delta;
        app.network_manager.apollo_time += to_apollo(delta);

        check_input(*input_state, *dummy_input);
        update_view(*app.view, *input_state, delta);

        if !network_update(app.network_manager.server, app.network_manager.apollo_time)
            break;

        num_ticks := cast(u8, floor(app.accumulator / FRAMETIME));
        if num_ticks > 0 {
            process_messages(*app);

            for 0..num_ticks-1 {
                previous := app.current;
                app.current = next_state_index(app.current);
                game_state = *GAME_STATES[app.current];
                copy_game_state(game_state, *GAME_STATES[previous]);
                game_state.nr_of_actions = 0;

                log("simulating: %\n", app.current);
                simulate(game_state, FRAMETIME);
           }
           app.previous = prev_state_index(app.current, num_ticks);
           app.accumulator -= FRAMETIME * xx num_ticks;
        }

        app.render_state.alpha = cast(float32) clamp(app.accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, app.view);
    }

    quit_app(*app);
}