View :: struct {
    position: Vector2 = .{0, 0};
    zoom: float32 = 1.0;
}

update_view :: (view: *View, input_state: *InputState, dt: float32) {
    pan_dir := Vector2.{ 0, 0 };
    pan_speed := 300.0;
    if input_state.left         pan_dir.x += -1;
    if input_state.right        pan_dir.x +=  1;
    if input_state.up           pan_dir.y += -1;
    if input_state.down         pan_dir.y +=  1;
    if pan_dir.x || pan_dir.y
        view.position += pan_dir * pan_speed * dt;

    if input_state.scroll_delta != 0 {
        view.zoom *= 1.0 + (xx input_state.scroll_delta / 10.0); // multiply by 1.1 or 0.9
        if view.zoom <= 0.6 then view.zoom = 0.6;
        if view.zoom >= 4 then view.zoom = 4;

        input_state.scroll_delta = 0;
    }
}