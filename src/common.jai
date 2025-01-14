Clock :: struct {
    last_time: float64;
}

clock_now :: () -> Clock {
    clock: Clock;
    clock.last_time = seconds_since_init();

    return clock;
}

clock_reset :: (clock: *Clock) -> float32 {
    now := seconds_since_init();
    delta := now - clock.last_time;
    clock.last_time = now;

    return xx delta;
}

snapped :: (n: float32, step: float32) -> float32 {
    return step * floor(n / step);
}
snapped :: (vec: Vector2, step: float32) -> Vector2 {
    return Vector2.{ snapped(vec.x, step), snapped(vec.y, step) };
}
snapped :: (vec: Vector2, step: Vector2) -> Vector2 {
    return Vector2.{ snapped(vec.x, step.x), snapped(vec.y, step.y) };
}

round_f32 :: (num: float32) -> float32 {
    sign := ifx num >= 0 then 1 else -1;
    return floor(num + sign * 0.5);
}