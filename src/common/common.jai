#load "vector.jai";
#load "clock.jai";
#load "rectangle.jai";

ROOT_2 :: 1.41421356237;

snapped :: (n: float32, step: float32) -> float32   { return step * floor(n / step); }
snapped :: (vec: Vector2, step: float32) -> Vector2 { return Vector2.{ snapped(vec.x, step  ), snapped(vec.y, step  ) }; }
snapped :: (vec: Vector2, step: Vector2) -> Vector2 { return Vector2.{ snapped(vec.x, step.x), snapped(vec.y, step.y) }; }

round_f32 :: (num: float32) -> float32 {
    sign := ifx num >= 0 then 1 else -1;
    return floor(num + sign * 0.5);
}
