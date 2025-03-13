#import "Basic";
#import "Math";
#import "raylib";
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
#load "client.jai";

convert_input_to_actions :: (input_state: *InputState, game_state: *GameState) -> []ActionRequest {
    actions: [..]ActionRequest;
    uuid: u64 = ifx game_state.player_index != -1 then game_state.players[game_state.player_index].uuid else 69420;

    if input_state.RMB_pressed {
        if game_state.player_index != -1 {
            mouse_pos: = mouse_to_screen(game_state) - HALF_TILE_RECT_SIZE;
            mouse_grid := screen_to_map(mouse_pos);
            // @TODO: consider unbounding this so it doesn't have to be checked here
            if in_bounds(mouse_grid) // doesn't make sense to walk outside of the grid...
                array_add(*actions, ActionRequest.{ kind=.MOVE, point=mouse_grid, uuid=uuid });
        }
    }

    if input_state.LMB_pressed {
        mouse_pos: = mouse_to_screen(game_state);
        array_add(*actions, ActionRequest.{ kind=.CLICK, position=mouse_pos, uuid=uuid });
    }

    if input_state.space {
        action := ActionRequest.{
            kind    = .ADD_PLAYER,
            point   = Vector2i.{ xx(random_get() % TILES_X), xx(random_get() % TILES_Y) },
            uuid    = uuid,
            b_value = game_state.player_index == -1,
            ignore  = false
        };
        #if CLIENT { action.ignore = true; } // this is needed to circumvent double actions on multiplayer

        array_add(*actions, action);
    }

    input_state.RMB_pressed = false;
    input_state.LMB_pressed = false;
    input_state.space = false;
    return actions;
}

main :: () {
    random_seed(cast,no_check(u64) to_milliseconds(current_time_consensus())); // used to randomize client id

    #if CLIENT {
        if !yojimbo_init() exit(0);
    }

    app, ok := init_app(get_command_line_arguments());
    if !ok
        quit_app(*app);

    previous_input: InputState;
    accumulated_input: InputState;
    game_state: *GameState;
    while !WindowShouldClose() {
        reset_temporary_storage();

        delta := clock_reset(*app.clock);
        app.accumulator += delta;
        num_ticks := cast(u8, floor(app.accumulator / FRAMETIME));

        check_input(*accumulated_input, *previous_input);
        update_view(*app.view, *accumulated_input, delta);

        if accumulated_input.reset {
            #if !CLIENT init_world(*WORLD);
            accumulated_input.reset = false;
        }

        #if CLIENT {
            app.network_manager.apollo_time += to_apollo(delta);
            if !network_update(app.network_manager.client, app.network_manager.apollo_time)
                break;
        }

        if num_ticks > 0 {
            #if CLIENT process_messages(*app);

            accumulated_input.mouse_position = GetMousePosition();
            game_actions := convert_input_to_actions(*accumulated_input, *GAME_STATES[app.current],, temp);

            for 0..num_ticks-1 {
                previous := app.current;
                app.current = next_state_index(app.current);
                game_state = *GAME_STATES[app.current];

                copy_game_state(game_state, *GAME_STATES[previous]);
                game_state.view = app.view;
                game_state.input_state = accumulated_input;

                game_state.nr_of_actions = 0;
                for game_actions
                    add_action(game_state, it);

                log("simulating: %\n", app.current);
                simulate(game_state, FRAMETIME);
            }
            app.previous = prev_state_index(app.current, num_ticks);
            app.accumulator -= FRAMETIME * xx num_ticks;

            memcpy(*previous_input, *accumulated_input, size_of(InputState));

            #if CLIENT {
                // since only the first tick will perform actions, take the next of the previous
                send_actions_to_server(*app, *GAME_STATES[next_state_index(app.previous)]);
            }
        }

        app.render_state.alpha = cast(float32) clamp(app.accumulator / FRAMETIME, 0.0, 1.0);
        render(*GAME_STATES[app.current], *GAME_STATES[app.previous], app.render_state, app.view);
    }

    quit_app(*app);
}
