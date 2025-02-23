#load "pathfinding.jai";

TILES_Y ::              16;
TILES_X ::              16;
TILE_SIZE ::            Vector2.{ 32, 16 };
HALF_TILE_SIZE ::       Vector2.{ 16, 8 };
TILE_RECT_SIZE ::       SDL_Point.{ 32, 32 };
HALF_TILE_RECT_SIZE ::  SDL_Point.{ 16, 16 };

MAX_PLAYERS :: 4;
MAX_ACTIONS :: 16;
GameState :: struct {
    players: [MAX_PLAYERS]Entity;
    nr_of_players: s32 = 0;

    tiles: [TILES_Y][TILES_X] Tile;
    player_index: s32 = -1;

    actions: [MAX_ACTIONS]ActionRequest;
    nr_of_actions: s32 = 0;

    input_state: InputState;
    view: View;
}

ENTIY_STATE :: enum u16 {
    IDLE;
    RUNNING;
}

Sprite :: struct {
    texture_id: string;
    texture_rect: SDL_Rect;
}

ENTITY_PATH_COUNT :: 64;
Entity :: struct {
    using sprite: Sprite;
    sprite.texture_id = "resources/mage.bmp";
    sprite.texture_rect = SDL_Rect.{ x=0, y=0, w=32, h=48 };
    position: Vector2;
    interpolated_position: Vector2;
    is_interpolating: bool = false;

    state: ENTIY_STATE = .IDLE;
    speed: float32 = 160;

    path: [ENTITY_PATH_COUNT]Vector2i;
    current_path_index: s16;

    uuid: u64 = 0;
    is_client := false;
}

ACTION :: enum u16 {
    MOVE;
    MOVE_CORRECTION;
}

ActionRequest :: struct {
    action: ACTION;
    x: u16;
    y: u16;
    uuid: u64 = 0;
    path: []Vector2i;
}

ActionResult :: struct {
    action: ACTION;
    x: u16;
    y: u16;
    uuid: u64 = 0;
    path: []Vector2i;
}

Tile :: struct {
    using sprite: Sprite;
    sprite.texture_id = "resources/tileset.bmp";
    position: Vector2;

    is_walkable:    bool = true;
    is_hovered:     bool = false;
    is_path:        bool = false;
}

copy_game_state :: (dst: *GameState, src: *GameState) {
    memcpy(*dst.players, *src.players, MAX_PLAYERS * size_of(Entity));
    dst.nr_of_players = src.nr_of_players;
    dst.player_index = src.player_index;

    for y: 0..TILES_Y-1
        for x: 0..TILES_X-1
            dst.tiles[y][x] = src.tiles[y][x];
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

add_action :: (using game_state: *GameState, action: ActionRequest) {
    if nr_of_actions > MAX_ACTIONS {
        log("nr_of_actions > MAX_ACTIONS...\n");
        return;
    }

    actions[nr_of_actions] = action;
    nr_of_actions += 1;
}

remove_action :: (using game_state: *GameState, action: ActionRequest) {
    if action.action == {
        case .MOVE; {
            for 0..nr_of_actions-1 {
                if action.x == actions[it].x && action.y == actions[it].y && action.uuid == actions[it].uuid {
                    actions[it] = actions[nr_of_actions-1];
                    nr_of_actions -= 1;
                    return;
                }
            }

            log("couldn't find action in actions: %, %\n", action, actions);
        }
    }
}

get_player :: (using game_state: *GameState, uuid: u64) -> *Entity {
    assert(uuid != 0, "get_player: uuid == 0");

    for 0..nr_of_players
        if players[it].uuid == uuid
            return *players[it];

    return null;
}

add_player :: (using game_state: *GameState, uuid: u64, x: u16, y: u16, is_client: bool) {
    log("is_client: %\n", is_client);
    players[nr_of_players] = Entity.{ position=map_to_screen(xx x, xx y), uuid=uuid, is_client=is_client };

    if is_client game_state.player_index = nr_of_players;
    nr_of_players += 1;
}

perform_action_request :: (using game_state: *GameState, request: ActionRequest) -> (ActionResult, bool) {
    player := get_player(game_state, request.uuid);
    assert(player != null, tprint("perform_action_request: Found no player with uuid == %", request.uuid));

    if request.action == {
        case .MOVE; {
            player_grid := screen_to_map(player.position);
            destination := Vector2i.{ x=request.x, y=request.y };
            assert(in_bounds(player_grid), tprint("perform_action_request: in_bounds(player_grid): %", in_bounds(player_grid)));
            assert(in_bounds(destination), tprint("perform_action_request: in_bounds(destination): %", in_bounds(destination)));

            path := jump_point_search(player_grid, destination, tiles,, temp);
            if path.count {
                player.state = .RUNNING;
                for tiles, y: game_state.tiles
                    for * tile, x: tiles
                        tile.is_path = false;

                if path.count >= ENTITY_PATH_COUNT { // truncate if too many points in path
                    diff := path.count - ENTITY_PATH_COUNT;
                    path.data, path.count += diff, -diff;
                }
                player.current_path_index = xx(path.count-1);

                for path {
                    player.path[it_index] = it;
                    tiles[it.y][it.x].is_path = true;
                }

                log("perform_action_request result: %, %, %\n", path, player.position, player_grid);
            }

            return ActionResult.{ action=.MOVE, path=path, uuid=request.uuid }, true;
        }

        case .MOVE_CORRECTION; {
            for tiles, y: game_state.tiles
                for * tile, x: tiles
                    tile.is_path = false;

            for request.path {
                player.path[it_index] = it;
                tiles[it.y][it.x].is_path = true;
            }
            player.current_path_index = xx(request.path.count-1);

            if player.current_path_index >= 0
                player.state = .RUNNING;
            else
                player.state = .IDLE;
        }
    }

    return ActionResult.{}, false;
}

simulate :: (using game_state: *GameState, dt: float32) {
    for tiles, y: game_state.tiles
        for * tile, x: tiles
            tile.is_hovered = false;

    mouse_pos: = mouse_to_screen(game_state) - tile_size_offset();
    mouse_grid := screen_to_map(mouse_pos);
    if in_bounds(mouse_grid)
        tiles[mouse_grid.y][mouse_grid.x].is_hovered = true;

    for 0..nr_of_actions-1 perform_action_request(game_state, actions[it]);

    for 0..nr_of_players-1 {
        player := *players[it];
        {
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

        if player.is_interpolating {
            if length_squared(player.interpolated_position - player.position) <= 4 { // @HARDCODED
                player.is_interpolating = false;
            } else {
                dist := player.position - player.interpolated_position;
                dist /= 3; // @HACK: good enough though
                player.interpolated_position += dist;
            }
        }
    }
}

entity_move_to_target :: (entity: *Entity, position: Vector2i) -> bool {
    target := map_to_screen(position);
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

mouse_to_screen :: (using game_state: *GameState) -> Vector2 {
    offset := input_state.mouse_position - (SCREEN_SIZE / 2);
    return Vector2.{
        offset.x / game_state.view.zoom + game_state.view.position.x,
        offset.y / game_state.view.zoom + game_state.view.position.y
    };
}

in_bounds :: (using vector: Vector2i) -> bool { return (x >= 0 && x < TILES_X && y >= 0 && y < TILES_Y); }
