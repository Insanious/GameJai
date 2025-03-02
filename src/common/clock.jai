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