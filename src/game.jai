TILES_Y ::          8;
TILES_X ::          8;
TILE_SIZE ::        Vector2.{ 32, 16 };
HALF_TILE_SIZE ::   Vector2.{ 16, 8 };
TILE_RECT_SIZE ::   SDL_Point.{ 32, 32 };

GameState :: struct {
    player: *Player;
    tiles: [TILES_Y][TILES_X] Tile;

    pointer: Tile;
}

Player :: struct {
    texture_id: string = "resources/mage.bmp";
    texture_rect: SDL_Rect;
    position: Vector2;
}

Tile :: struct {
    texture_id: string = "resources/tileset.bmp";
    texture_rect: SDL_Rect;
    position: Vector2;
}

make_game_state :: () -> (*GameState, bool) {
    game_state := New(GameState);
    game_state.player = New(Player);
    game_state.player.texture_rect = .{ x=0, y=0, w=32, h=48 };

    for tiles, y: game_state.tiles {
        for * tile, x: tiles {
            tile.texture_rect = .{ 0, 0, TILE_RECT_SIZE.x, TILE_RECT_SIZE.y };
            tile.position = map_to_screen(x, y);
        }
    }

    game_state.pointer.texture_rect = .{ TILE_RECT_SIZE.x * 8, TILE_RECT_SIZE.y * 0, TILE_RECT_SIZE.x, TILE_RECT_SIZE.y };
    game_state.pointer.position = map_to_screen(0, 0);

    return game_state, true;
}

simulate :: (state: *AppState) {}

update :: (using state: *AppState, delta: float32) {
    pan_dir: Vector2;
    pan_speed: float32 = 300;
    if input_state.left         pan_dir.x += -1;
    if input_state.right        pan_dir.x +=  1;
    if input_state.up           pan_dir.y += -1;
    if input_state.down         pan_dir.y +=  1;
    if pan_dir.x || pan_dir.y
        render_state.view_pos += pan_dir * pan_speed * delta;


    if input_state.scroll != 0 {
        render_state.view_zoom *= 1.0 + (xx input_state.scroll / 10.0); // multiply by 1.1 or 0.9
        input_state.scroll = 0;
    }

    SDL_GetMouseState(*input_state.mouse_position.x, *input_state.mouse_position.y);
    mouse_pos := mouse_to_screen(state);
    mouse_pos.x -= TILE_RECT_SIZE.x / 4;                        // @MAGIC (kind of)
    mouse_pos.y -= TILE_RECT_SIZE.y / 2 - TILE_RECT_SIZE.y / 6; // @MAGIC (kind of)
    mouse_pos = snapped(mouse_pos, HALF_TILE_SIZE);
    game_state.pointer.position = mouse_pos;

    if input_state.left_mouse {

    }
}

map_to_screen :: (x: s64, y: s64) -> Vector2 {
    return Vector2.{
        (x - y) * HALF_TILE_SIZE.x,
        (x + y) * HALF_TILE_SIZE.y
    };
}

screen_to_map :: (x: float32, y: float32) -> Vector2 {
    return Vector2.{
        x / TILE_SIZE.x + y / TILE_SIZE.x,
        y / TILE_SIZE.y - x / TILE_SIZE.y
    };
}

mouse_to_screen :: (using state: *AppState) -> Vector2 {
    center := Vector2.{ cast(float32, SCREEN_SIZE.x) / 2, cast(float32, SCREEN_SIZE.y) / 2 };
    offset_pos := Vector2.{
        cast(float32, input_state.mouse_position.x) - center.x,
        cast(float32, input_state.mouse_position.y) - center.y,
    };
    return Vector2.{
        offset_pos.x / render_state.view_zoom + render_state.view_pos.x,
        offset_pos.y / render_state.view_zoom + render_state.view_pos.y
    };
}