InputState :: struct {
    exit:   bool;
    mouse_position: Vector2i;
    scroll_delta: s8 = 0;
    left, right, up, down: bool = false;
    LMB, LMB_pressed: bool = false;
    RMB, RMB_pressed: bool = false;
}

input :: (using current: *InputState, previous: *InputState, event: *SDL_Event) {
    if event.type == {
        case SDL_QUIT; exit = true;

        case SDL_KEYDOWN; #through;
        case SDL_KEYUP;
            key_down := event.type == SDL_KEYDOWN;
            if event.key.keysym.sym == {
                case SDLK_ESCAPE;   exit    = key_down;
                case SDLK_a;        left    = key_down;
                case SDLK_d;        right   = key_down;
                case SDLK_w;        up      = key_down;
                case SDLK_s;        down    = key_down;
            }

        case SDL_MOUSEWHEEL; scroll_delta += xx event.wheel.y;

        case SDL_MOUSEBUTTONDOWN;
        {
            if event.button.button == {
                case SDL_BUTTON_LEFT;   LMB, LMB_pressed = true, !previous.LMB_pressed;
                case SDL_BUTTON_RIGHT;  RMB, RMB_pressed = true, !previous.RMB_pressed;
            }
        }
        case SDL_MOUSEBUTTONUP;
        {
            if event.button.button == {
                case SDL_BUTTON_LEFT;   LMB = false;
                case SDL_BUTTON_RIGHT;  RMB = false;
            }
        }
    }
}