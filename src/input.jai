InputState :: struct {
    exit: bool;

    left, right, up, down: bool;
    scroll: s8;

    mouse_position: SDL_Point;
    left_mouse: bool;
}

input :: (state: *AppState, event: *SDL_Event) {
    using state;

    if event.type == {
        case SDL_QUIT;
            input_state.exit = true;
        case SDL_KEYDOWN; #through;
        case SDL_KEYUP;
            down := event.type == SDL_KEYDOWN;
            if event.key.keysym.sym == {
                case SDLK_ESCAPE;   input_state.exit    = true;
                case SDLK_a;        input_state.left    = down;
                case SDLK_d;        input_state.right   = down;
                case SDLK_w;        input_state.up      = down;
                case SDLK_s;        input_state.down    = down;
            }
        case SDL_MOUSEWHEEL;        input_state.scroll = xx event.wheel.y;
        case SDL_MOUSEBUTTONUP; #through;
        case SDL_MOUSEBUTTONDOWN;
            down := event.type == SDL_MOUSEBUTTONDOWN;
            if event.button.button == {
                case SDL_BUTTON_LEFT; input_state.left_mouse = down;
            }
    }
}