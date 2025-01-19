InputState :: struct {
    exit: bool;

    left, right, up, down: bool = false;
    scroll: s8 = 0;

    mouse_position: Vector2i;
    left_mouse, right_mouse: bool = false;
    left_mouse_click, right_mouse_click: bool = false;
}

input :: (using state: *AppState, event: *SDL_Event) {
    using input_state;

    if event.type == {
        case SDL_QUIT; exit = true;

        case SDL_KEYDOWN; #through;
        case SDL_KEYUP;
            button_down := event.type == SDL_KEYDOWN;
            if event.key.keysym.sym == {
                case SDLK_ESCAPE;   exit    = true;
                case SDLK_a;        left    = button_down;
                case SDLK_d;        right   = button_down;
                case SDLK_w;        up      = button_down;
                case SDLK_s;        down    = button_down;
            }

        case SDL_MOUSEWHEEL; scroll = xx event.wheel.y;

        case SDL_MOUSEBUTTONUP; #through;
        case SDL_MOUSEBUTTONDOWN;
            button_down := event.type == SDL_MOUSEBUTTONDOWN;
            if event.button.button == {
                case SDL_BUTTON_LEFT; {
                    left_mouse = button_down;
                    left_mouse_click = button_down;
                }
                case SDL_BUTTON_RIGHT; {
                    right_mouse = button_down;
                    right_mouse_click = button_down;
                }
            }
    }
}
