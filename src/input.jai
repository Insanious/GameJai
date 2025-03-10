InputState :: struct {
    mouse_position: Vector2;
    scroll_delta: s8 = 0;
    left, right, up, down: bool = false;
    RMB_pressed, LMB_pressed: bool = false;
    space: bool = false;
    reset: bool = false;
}

check_input :: (using current: *InputState, previous: *InputState) {
    left    = IsKeyDown(.KEY_A);
    right   = IsKeyDown(.KEY_D);
    up      = IsKeyDown(.KEY_W);
    down    = IsKeyDown(.KEY_S);

    if IsKeyPressed(.KEY_R)     reset = true;
    if IsKeyPressed(.KEY_SPACE) space = true;

    if IsMouseButtonPressed(MOUSE_LEFT_BUTTON)  LMB_pressed = true;
    if IsMouseButtonPressed(MOUSE_RIGHT_BUTTON) RMB_pressed = true;

    scroll_delta += xx GetMouseWheelMove();
}
