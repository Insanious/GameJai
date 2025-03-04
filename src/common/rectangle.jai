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

to_SDL_FRect :: (rect: Rect) -> SDL_FRect { return SDL_FRect.{ x=rect.x, y=rect.y, w=rect.w, h=rect.h}; }
