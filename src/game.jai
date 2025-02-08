#load "pathfinding.jai";

TILES_Y ::              16;
TILES_X ::              16;
TILE_SIZE ::            Vector2.{ 32, 16 };
HALF_TILE_SIZE ::       Vector2.{ 16, 8 };
TILE_RECT_SIZE ::       SDL_Point.{ 32, 32 };
HALF_TILE_RECT_SIZE ::  SDL_Point.{ 16, 16 };

View :: struct {
    position: Vector2;
    zoom: float32 = 1.0;
}

MAX_PLAYERS :: 4;
GameState :: struct {
    players: [MAX_PLAYERS]Entity;
    nr_of_players: s32 = 0;
    tiles: [TILES_Y][TILES_X] Tile;
    client_index: s32 = -1;

    view: View;
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

ENTITY_PATH_COUNT :: 64;
Entity :: struct {
    using sprite: Sprite;
    sprite.texture_id = "resources/mage.bmp";
    sprite.texture_rect = SDL_Rect.{ x=0, y=0, w=32, h=48 };

    state: ENTIY_STATE = .IDLE;
    speed: float32 = 160;

    path: [ENTITY_PATH_COUNT]Vector2;
    current_path_index: s16;
    actions: [..]ActionResult;

    uuid: u64 = 0;
    is_client := false;
}

ACTION :: enum u16 {
    MOVE;
}

ActionRequest :: struct {
    action: ACTION;
    x: u16;
    y: u16;
}

ActionResult :: struct {
    action: ACTION;
    x: u16;
    y: u16;
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

init_game_state :: (game_state: *GameState) {
    for tiles, y: game_state.tiles {
        for * tile, x: tiles {
            tile.texture_rect = .{ 0, 0, TILE_RECT_SIZE.x, TILE_RECT_SIZE.y };
            tile.position = map_to_screen(x, y);
        }
    }
}

add_player :: (using game_state: *GameState, uuid: u64, x: u16, y: u16, is_client: bool) {
    log("is_client: %\n", is_client);
    players[nr_of_players] = Entity.{ position=map_to_screen(xx x, xx y), uuid=uuid, is_client=is_client };
    players[nr_of_players].actions.allocator = temp;

    if is_client game_state.client_index = nr_of_players;
    nr_of_players += 1;
}

perform_action_request :: (using game_state: *GameState, player: *Entity, request: ActionRequest) {
    if request.action == {
        case .MOVE; {
            player_grid := screen_to_map(player.position);
            destination := Vector2i.{ x=request.x, y=request.y };
            if !in_bounds(player_grid) || !in_bounds(destination) {
                log("tried pathfinding out of bounds\n");
            } else {
                paths: []Vector2i;
                new_context := context;
                new_context.allocator = temp;
                push_context new_context { paths = jump_point_search(player_grid, destination, tiles); }

                if paths.count {
                    player.state = .RUNNING;
                    for tiles, y: game_state.tiles
                        for * tile, x: tiles
                            tile.is_path = false;

                    if paths.count >= ENTITY_PATH_COUNT { // truncate if too many paths
                        diff := paths.count - ENTITY_PATH_COUNT;
                        paths.data, paths.count += diff, -diff;
                    }
                    player.current_path_index = xx(paths.count-1);

                    for paths {
                        player.path[it_index] = map_to_screen(it);
                        tiles[it.y][it.x].is_path = true; // TODO: should prob not be here
                    }
                }
            }
        }
    }
}

simulate :: (using game_state: *GameState, input_state: *InputState, dt: float32) {
    update_view(*game_state.view, input_state, dt);

    for tiles, y: game_state.tiles
        for * tile, x: tiles
            tile.is_hovered = false;

    mouse_pos: = mouse_to_screen(game_state, input_state) - tile_size_offset();
    mouse_grid := screen_to_map(mouse_pos);
    if in_bounds(mouse_grid)
        tiles[mouse_grid.y][mouse_grid.x].is_hovered = true;

    if input_state.RMB_pressed {
        if client_index != -1 {
            player := *players[client_index];
            player_grid := screen_to_map(player.position);

            if !in_bounds(player_grid) || !in_bounds(mouse_grid) {
                log("tried pathfinding out of bounds\n");
            } else {
                array_add(*player.actions, ActionResult.{ action=.MOVE, x=xx mouse_grid.x, y=xx mouse_grid.y });
                paths: []Vector2i;
                new_context := context;
                new_context.allocator = temp;
                push_context new_context { paths = jump_point_search(player_grid, mouse_grid, tiles); }

                if paths.count {
                    player.state = .RUNNING;
                    for tiles, y: game_state.tiles
                        for * tile, x: tiles
                            tile.is_path = false;

                    if paths.count >= ENTITY_PATH_COUNT { // truncate if too many paths
                        diff := paths.count - ENTITY_PATH_COUNT;
                        paths.data, paths.count += diff, -diff;
                    }
                    player.current_path_index = xx(paths.count-1);

                    for paths {
                        player.path[it_index] = map_to_screen(it);
                        tiles[it.y][it.x].is_path = true;
                    }
                }
            }
        }
    }

    {
        for 0..nr_of_players-1 {
            player := *players[it];
            using player;
            if state == .RUNNING {
                if current_path_index >= 0 {
                    if entity_move_to_target(player, path[current_path_index]) {
                        current_path_index -= 1;
                        if current_path_index < 0 then state = .IDLE;
                    }
                }
            }
        }
    }
}

update_view :: (view: *View, input_state: *InputState, dt: float32) {
    pan_dir := Vector2.{ 0, 0 };
    pan_speed := 300.0;
    if input_state.left         pan_dir.x += -1;
    if input_state.right        pan_dir.x +=  1;
    if input_state.up           pan_dir.y += -1;
    if input_state.down         pan_dir.y +=  1;
    if pan_dir.x || pan_dir.y
        view.position += pan_dir * pan_speed * dt;

    if input_state.scroll_delta != 0 {
        view.zoom *= 1.0 + (xx input_state.scroll_delta / 10.0); // multiply by 1.1 or 0.9
        if view.zoom <= 0.6 then view.zoom = 0.6;
        if view.zoom >= 4 then view.zoom = 4;
    }
}

entity_move_to_target :: (entity: *Entity, target: Vector2) -> bool {
    dir := normalize(target - entity.position);
    vel := dir * FRAMETIME * entity.speed;
    no_remaining := length_squared(target - entity.position) <= length_squared(vel);
    entity.position = ifx no_remaining then target else entity.position + vel;
    return no_remaining;
}

entity_feet_offset :: (using entity: Entity) -> Vector2 {
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

mouse_to_screen :: (using game_state: *GameState, input_state: *InputState) -> Vector2 {
    offset := input_state.mouse_position - (SCREEN_SIZE / 2);
    return Vector2.{
        offset.x / game_state.view.zoom + game_state.view.position.x,
        offset.y / game_state.view.zoom + game_state.view.position.y
    };
}

in_bounds :: (using vector: Vector2i) -> bool { return (x >= 0 && x < TILES_X && y >= 0 && y < TILES_Y); }
