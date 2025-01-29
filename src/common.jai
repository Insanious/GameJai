Vector2i :: struct
{
	x, y: s32;

	#place x;
	component: [2]s32 = ---;
	#place x;
	width: s32 = ---;
	#place y;
	height: s32 = ---;
}

operator == :: (left: Vector2i, right: Vector2i) -> bool { return (left.x == right.x && left.y == right.y); }
operator + :: (left: Vector2i, right: Vector2i) -> Vector2i { return .{ left.x + right.x, left.y + right.y }; }
operator - :: (left: Vector2i, right: Vector2i) -> Vector2i { return .{ left.x - right.x, left.y - right.y }; }
operator * :: (left: Vector2i, right: Vector2i) -> Vector2i { return .{ left.x * right.x, left.y * right.y }; }
operator * :: (vector: Vector2i, scalar: s32) -> Vector2i #symmetric { return .{ vector.x * scalar, vector.y * scalar }; }
operator / :: (vector: Vector2i, divisor: s32) -> Vector2i #symmetric { return .{ vector.x / divisor, vector.y / divisor }; }

hash_vector2 :: (vec: Vector2) -> u32 { return get_hash(vec.x) ^ (get_hash(vec.y) << 1); }
hash_vector2i :: (vec: Vector2i) -> u32 { return get_hash(vec.x) ^ (get_hash(vec.y) << 1); }
compare_vector2 :: (a: Vector2, b: Vector2) -> bool { return a.x == b.x && a.y == b.y; }
compare_vector2i :: (a: Vector2i, b: Vector2i) -> bool { return a.x == b.x && a.y == b.y; }

ROOT_2 :: 1.41421356237;

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

lerp_vec :: (a: Vector2, b: Vector2, alpha: float32) -> Vector2 {
    return Vector2.{ lerp(a.x, b.x, alpha), lerp(a.y, b.y, alpha) };
}

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