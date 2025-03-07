InputState :: struct {
    exit:   bool;
    mouse_position: Vector2;
    scroll_delta: s8 = 0;
    left, right, up, down: bool = false;
    RMB, RMB_pressed: bool = false;
    LMB, LMB_pressed: bool = false;
    space: bool = false;
    r    : bool = false;
}

input :: (using current: *InputState, previous: *InputState, event: *SDL_Event) {
    if event.type == {
        case .SDL_EVENT_QUIT; exit = true;

        case .SDL_EVENT_KEY_DOWN;
            if event.key.key == {
                case SDLK_ESCAPE;   exit    = true;
                case SDLK_A;        left    = true;
                case SDLK_D;        right   = true;
                case SDLK_W;        up      = true;
                case SDLK_S;        down    = true;
                case SDLK_SPACE;    space   = !previous.space;
                case SDLK_R;            r   = !previous.r;
            }

        case .SDL_EVENT_KEY_UP;
            if event.key.key == {
                case SDLK_ESCAPE;   exit    = false;
                case SDLK_A;        left    = false;
                case SDLK_D;        right   = false;
                case SDLK_W;        up      = false;
                case SDLK_S;        down    = false;
                case SDLK_SPACE;    space   = false;
                case SDLK_R;            r   = false;
            }

        case .SDL_EVENT_MOUSE_WHEEL; scroll_delta += xx event.wheel.y;

        case .SDL_EVENT_MOUSE_BUTTON_DOWN;
        {
            if event.button.button == {
                case SDL_BUTTON_RIGHT;  RMB, RMB_pressed = true, !previous.RMB_pressed;
                case SDL_BUTTON_LEFT;   LMB, LMB_pressed = true, !previous.LMB_pressed;
            }
        }
        case .SDL_EVENT_MOUSE_BUTTON_UP;
        {
            if event.button.button == {
                case SDL_BUTTON_RIGHT;  RMB = false;
                case SDL_BUTTON_LEFT;   LMB = false;
            }
        }
    }
}