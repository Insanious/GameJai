#load "pathfinding.jai";

TILES_Y ::              16;
TILES_X ::              16;
TILE_SIZE ::            Vector2.{ 32, 16 };
HALF_TILE_SIZE ::       Vector2.{ 16, 8 };
TILE_RECT_SIZE ::       SDL_Point.{ 32, 32 };
HALF_TILE_RECT_SIZE ::  SDL_Point.{ 16, 16 };

GameState :: struct {
    player: *Entity;
    tiles: [TILES_Y][TILES_X] Tile;
}

ENTIY_STATE :: enum u16 {
    IDLE;
    RUNNING;
}

Sprite :: struct {
    texture_id: string;
    texture_rect: SDL_Rect;
    position: Vector2;
}

Entity :: struct {
    using sprite: Sprite;
    sprite.texture_id = "resources/mage.bmp";
    prev_position: Vector2;

    state: ENTIY_STATE = .IDLE;
    speed: float32 = 160;

    path: [..]Vector2;
    current_path: []Vector2;
}

Tile :: struct {
    using sprite: Sprite;
    sprite.texture_id = "resources/tileset.bmp";

    is_walkable:    bool = true;
    is_hovered:     bool = false;
    is_path:        bool = false;
}

temp_get_rect_points :: (start: Vector2i, end: Vector2i) -> []Vector2i {
    points: [..]Vector2i;
    for y: start.y..end.y for x: start.x..end.x array_add(*points, .{x, y});
    return points;
}

make_game_state :: () -> (*GameState, bool) {
    game_state := New(GameState);
    game_state.player = New(Entity);
    game_state.player.texture_rect = .{ x=0, y=0, w=32, h=48 };
    game_state.player.position += map_to_screen(1, 1);

    for tiles, y: game_state.tiles {
        for * tile, x: tiles {
            tile.texture_rect = .{ 0, 0, TILE_RECT_SIZE.x, TILE_RECT_SIZE.y };
            tile.position = map_to_screen(x, y);
            if x == 2 && y == 1  game_state.tiles[y][x].is_walkable = false;
            if x == 1 && y == 2  game_state.tiles[y][x].is_walkable = false;
        }
    }

    for temp_get_rect_points(.{4, 4}, .{5, 5})
        game_state.tiles[it.y][it.x].is_walkable = false;

    return game_state, true;
}

simulate :: (using app_state: *AppState) {
    using game_state;
    {
        using player;
        prev_position = position;

        if state == .RUNNING {
            if current_path.count {
                if entity_move_to_target(player, current_path[0]) {
                    current_path.count, current_path.data += -1, 1;

                    if current_path.count == 0 {
                        path.count = 0;
                        state = .IDLE;
                    }
                }
            } else {
                state = .IDLE;
            }
        }
    }
}

update_view :: (using state: *AppState, dt: float32) {
    pan_dir := Vector2.{ 0, 0 };
    pan_speed := 300.0;
    if input_state.left         pan_dir.x += -1;
    if input_state.right        pan_dir.x +=  1;
    if input_state.up           pan_dir.y += -1;
    if input_state.down         pan_dir.y +=  1;
    if pan_dir.x || pan_dir.y
        render_state.view_pos += pan_dir * pan_speed * dt;

    if input_state.scroll != 0 {
        render_state.view_zoom *= 1.0 + (xx input_state.scroll / 10.0); // multiply by 1.1 or 0.9
        input_state.scroll = 0;
    }
}

update :: (using state: *AppState, dt: float32) {
    temp_mouse : SDL_Point;
    SDL_GetMouseState(*temp_mouse.x, *temp_mouse.y);
    input_state.mouse_position.x, input_state.mouse_position.y = temp_mouse.x, temp_mouse.y;

    update_view(state, dt);

    for tiles, y: game_state.tiles
        for * tile, x: tiles
            tile.is_hovered = false;

    mouse_pos: = mouse_to_screen(state) - tile_size_offset();
    mouse_grid := screen_to_map(mouse_pos);
    if in_bounds(mouse_grid)
        game_state.tiles[mouse_grid.y][mouse_grid.x].is_hovered = true;

    if input_state.right_mouse_click {
        using game_state;
        player.current_path.count, player.path.count = 0, 0;
        player_grid := screen_to_map(player.position);

        if !in_bounds(player_grid) || !in_bounds(mouse_grid) {
            log("tried pathfinding out of bounds\n");
        } else {
            paths: []Vector2i;
            new_context := context;
            new_context.allocator = temp;
            push_context new_context { paths = jump_point_search(player_grid, mouse_grid, tiles); }

            if paths.count {
                player.state = .RUNNING;
                for tiles, y: game_state.tiles
                    for * tile, x: tiles
                        tile.is_path = false;

                for < paths {
                    tile_pos := map_to_screen(it);
                    array_add(*player.path, tile_pos);
                    tiles[it.y][it.x].is_path = true;
                }
                player.current_path = player.path;
            }
        }
    }

    if input_state.left_mouse_click then input_state.left_mouse_click = false;
    if input_state.right_mouse_click then input_state.right_mouse_click = false;
}

entity_move_to_target :: (entity: *Entity, target: Vector2) -> bool {
    dir := normalize(target - entity.position);
    vel := dir * FRAMETIME * entity.speed;
    no_remaining := length_squared(target - entity.position) < length_squared(vel);
    entity.position = ifx no_remaining then target else entity.position + vel;
    return no_remaining;
}

entity_feet_offset :: (using entity: *Entity) -> Vector2 {
    return Vector2.{
        cast(float32, texture_rect.w) * 0,  // kinda @HARDCODED
        cast(float32, texture_rect.h) * 3/4 // kinda @HARDCODED
    };
}

tile_size_offset :: () -> Vector2 { return .{ xx HALF_TILE_RECT_SIZE.x, xx HALF_TILE_RECT_SIZE.y }; }

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

mouse_to_screen :: (using state: *AppState) -> Vector2 {
    offset := input_state.mouse_position - (SCREEN_SIZE / 2);
    return Vector2.{
        offset.x / render_state.view_zoom + render_state.view_pos.x,
        offset.y / render_state.view_zoom + render_state.view_pos.y
    };
}

in_bounds :: (using vector: Vector2i) -> bool { return (x >= 0 && x < TILES_X && y >= 0 && y < TILES_Y); }
