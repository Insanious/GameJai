TILES_Y ::              16;
TILES_X ::              16;
MIN_TILES ::            Vector2i.{0, 0};
MAX_TILES ::            Vector2i.{TILES_X, TILES_Y};

TILE_SIZE ::            Vector2.{32, 16};
HALF_TILE_SIZE ::       Vector2.{16,  8};
TILE_RECT_SIZE ::       Vector2.{32, 32};
HALF_TILE_RECT_SIZE ::  Vector2.{16, 16};

MAX_AREAS :: 0;
World :: struct {
    tiles: [TILES_Y][TILES_X]Tile;
    areas: [MAX_AREAS]Area;
}

Tile :: struct {
    using sprite: Sprite;
    sprite.texture_id = "resources/tileset.bmp";
    position: Vector2;

    is_walkable: bool = true;
    is_hovered:  bool = false;
    is_path:     bool = false;
    is_whitelisted: bool = false;
}

ENTRANCE_SIZE :: 3;
Area :: struct {
    rect: IntRect;
    entrance: [ENTRANCE_SIZE]Vector2i;
    entrance_btn: Rect;
}

random_span :: (min: u64, max: u64) -> u64 { return random_get() % (max + 1 - min) + min; }

random_area :: () -> Area {
    rect: IntRect;
    entrance: [3]Vector2i;
    while true {
        left := cast(s32, (random_get() % TILES_X));
        top := cast(s32, (random_get() % TILES_Y));
        width: s32 = 6;
        height: s32 = 6;

        rect = .{x=left, y=top, w=width, h=height};
        if in_bounds(rect.top_left) && in_bounds(rect.top_left + rect.size)
            break;
    }

    while true {
        side := random_get() % 4;
        if  (side == 0 && rect.y == 0)                     || // TOP
            (side == 1 && rect.y+rect.height == TILES_Y-1) || // BOTTOM
            (side == 2 && rect.x == 0)                     || // LEFT
            (side == 3 && rect.x+rect.width == TILES_X-1)     // RIGHT
            continue;

        if side == 0 || side == 1 { // TOP | BOTTOM
            min: u64 = xx (rect.x + 1);
            max: u64 = xx (rect.x + rect.width - ENTRANCE_SIZE);
            rand_val: s64 = xx random_span(min, max);
            static_val := ifx (side == 0) rect.y else rect.y+rect.height;

            for 0..ENTRANCE_SIZE-1
                entrance[it] = .{x=cast(s32, rand_val + it), y=static_val};
        } else { // LEFT | RIGHT
            min: u64 = xx (rect.y + 1);
            max: u64 = xx (rect.y + rect.height - ENTRANCE_SIZE);
            rand_val: s64 = xx random_span(min, max);
            static_val := ifx (side == 2) rect.x else rect.x+rect.width;

            for 0..ENTRANCE_SIZE-1
                entrance[it] = .{x=static_val, y=cast(s32, rand_val + it)};
        }
        break;
    }

    mid := map_to_screen(entrance[ENTRANCE_SIZE/2]);
    entrance_btn: Rect = .{x=xx (mid.x + 10), y=xx (mid.y - 5), w=10, h=10};

    return Area.{ rect=rect, entrance=entrance, entrance_btn=entrance_btn};
}

init_world :: (using world: *World) {
    for tiles, y: tiles {
        for * tile, x: tiles {
            tile.texture_rect = .{ 0, 0, TILE_RECT_SIZE.x, TILE_RECT_SIZE.y };
            tile.position = map_to_screen(x, y);
            tile.is_walkable = true;
            tile.is_hovered  = false;
            tile.is_path     = false;
        }
    }

    for 0..MAX_AREAS-1 {
        world.areas[it] = random_area();
        {
            using world.areas[it];
            for 0..rect.width {
                tiles[rect.y            ][rect.x+it].is_walkable = false;
                tiles[rect.y+rect.height][rect.x+it].is_walkable = false;
            }
            for 0..rect.height {
                tiles[rect.y+it][rect.x           ].is_walkable = false;
                tiles[rect.y+it][rect.x+rect.width].is_walkable = false;
            }
            for entrance
                tiles[it.y][it.x].is_walkable = true;
        }
    }
}

map_to_screen :: (x: s64, y: s64) -> Vector2 {
    return Vector2.{
        (x - y) * HALF_TILE_SIZE.x,
        (x + y) * HALF_TILE_SIZE.y
    };
}

map_to_screen :: (vector: Vector2i) -> Vector2 { return map_to_screen(vector.x, vector.y); }

screen_to_map :: (using vector: Vector2) -> Vector2i {
    return Vector2i.{
        cast(s32, ceil((x / HALF_TILE_SIZE.x + y / HALF_TILE_SIZE.y) / 2)),
        cast(s32, ceil((y / HALF_TILE_SIZE.y - x / HALF_TILE_SIZE.x) / 2))
    };
}


in_bounds :: (using vector: Vector2i) -> bool { return (x >= 0 && x < TILES_X && y >= 0 && y < TILES_Y); }