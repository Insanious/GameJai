Rect :: struct
{
	x, y, w, h: float32;

	#place x;
	component: [4]float32 = ---;
	#place x;
	top_left: Vector2 = ---;
	#place w;
	size: Vector2 = ---;
	#place w;
	width: float32 = ---;
	#place h;
	height: float32 = ---;
}

IntRect :: struct
{
	x, y, w, h: s32;

	#place x;
	component: [4]s32 = ---;
	#place x;
	top_left: Vector2i = ---;
	#place w;
	size: Vector2i = ---;
	#place w;
	width: s32 = ---;
	#place h;
	height: s32 = ---;
}

operator == :: (left: Rect, right: Rect)       -> bool { return (left.x == right.x && left.y == right.y && left.w == right.w && left.h == right.h); }
operator == :: (left: IntRect, right: IntRect) -> bool { return (left.x == right.x && left.y == right.y && left.w == right.w && left.h == right.h); }

operator + :: (rect: Rect, offset: Vector2i)    -> Rect    { return    Rect.{ rect.x + offset.x, rect.y + offset.y, rect.width, rect.height }; }
operator + :: (rect: IntRect, offset: Vector2i) -> IntRect { return IntRect.{ rect.x + offset.x, rect.y + offset.y, rect.width, rect.height }; }
operator - :: (rect: Rect, offset: Vector2i)    -> Rect    { return    Rect.{ rect.x - offset.x, rect.y - offset.y, rect.width, rect.height }; }
operator - :: (rect: IntRect, offset: Vector2i) -> IntRect { return IntRect.{ rect.x - offset.x, rect.y - offset.y, rect.width, rect.height }; }

operator * :: (rect: Rect, scalar: s32)    -> Rect    #symmetric { return    Rect.{ rect.x * scalar, rect.y * scalar, rect.width * scalar, rect.height * scalar }; }
operator * :: (rect: IntRect, scalar: s32) -> IntRect #symmetric { return IntRect.{ rect.x * scalar, rect.y * scalar, rect.width * scalar, rect.height * scalar }; }
operator / :: (rect: Rect, scalar: s32)    -> Rect    { return    Rect.{ rect.x / scalar, rect.y / scalar, rect.width / scalar, rect.height / scalar }; }
operator / :: (rect: IntRect, scalar: s32) -> IntRect { return IntRect.{ rect.x / scalar, rect.y / scalar, rect.width / scalar, rect.height / scalar }; }

rect_contains :: (r: Rect, p: Vector2)     -> bool { return p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h; }
rect_contains :: (r: IntRect, p: Vector2i) -> bool { return p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h; }
rect_contains :: (r: Rect, p: Vector2i)    -> bool { return rect_contains(r,  Vector2.{ xx p.x, xx p.y }); }
rect_contains :: (r: IntRect, p: Vector2)  -> bool { return rect_contains(r, Vector2i.{ xx p.x, xx p.y }); }

to_raylib_rect :: (rect: Rect) -> Rectangle { return Rectangle.{ x=rect.x, y=rect.y, width=rect.w, height=rect.h}; }
