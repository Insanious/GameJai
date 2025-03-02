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
operator / :: (vector: Vector2i, scalar: s32) -> Vector2i #symmetric { return .{ vector.x / scalar, vector.y / scalar }; }

hash_vector2 :: (vec: Vector2) -> u32 { return get_hash(vec.x) ^ (get_hash(vec.y) << 1); }
hash_vector2i :: (vec: Vector2i) -> u32 { return get_hash(vec.x) ^ (get_hash(vec.y) << 1); }
compare_vector2 :: (a: Vector2, b: Vector2) -> bool { return a.x == b.x && a.y == b.y; }
compare_vector2i :: (a: Vector2i, b: Vector2i) -> bool { return a.x == b.x && a.y == b.y; }
