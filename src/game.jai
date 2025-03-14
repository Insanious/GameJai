#load "pathfinding.jai";
#load "world.jai";

MAX_PLAYERS :: 4;
MAX_ACTIONS :: 16;
GameState :: struct {
    players: [MAX_PLAYERS]Player;
    nr_of_players: s32 = 0;
    player_index: s32 = -1;

    actions: [MAX_ACTIONS]ActionRequest;
    nr_of_actions: s32 = 0;

    input_state: InputState;
    view: View;

    income_tick: float32 = 1;
    current_income_tick: float32 = 0;
}

Sprite :: struct {
    texture_id: string;
    texture_rect: Rect;
}

PLAYER_STATE :: enum u16 {
    IDLE;
    RUNNING;
}

PLAYER_PATH_COUNT :: 16;
Player :: struct {
    using sprite: Sprite;
    sprite.texture_id = "resources/mage.bmp";
    sprite.texture_rect = Rect.{ x=0, y=0, w=32, h=48 };
    position: Vector2;
    interpolated_position: Vector2;
    is_interpolating: bool = false;

    state: PLAYER_STATE = .IDLE;
    speed: float32 = 160;

    path: [PLAYER_PATH_COUNT]Vector2i;
    current_path_index: s16;

    gold: s32 = 0;
    gold_income: s32 = 0;

    uuid: u64 = 0;
    is_client := false;
}

ActionResult :: struct {
    RESULT :: enum u16 {
        MOVE;
        ADD_PLAYER;
        CLAIM_REGION;
    }
    kind: RESULT;

    network_id: u32 = 0;
}

ActionRequest :: struct {
    ACTION :: enum u16 {
        MOVE;
        ADD_PLAYER;
        CLICK;
    }
    kind: ACTION;

    uuid: u64 = 0;
    point: Vector2i;
    position: Vector2;
    b_value: bool = false;
    ignore: bool = false;
}

copy_game_state :: (dst: *GameState, src: *GameState) {
    dst.players = src.players;
    dst.nr_of_players = src.nr_of_players;
    dst.player_index = src.player_index;
    dst.current_income_tick = src.current_income_tick;
}

temp_get_rect_points :: (start: Vector2i, end: Vector2i) -> []Vector2i {
    points: [..]Vector2i;
    for y: start.y..end.y for x: start.x..end.x array_add(*points, .{x, y});
    return points;
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
    if action.kind == {
        case .MOVE;
            for 0..nr_of_actions-1 {
                if action.point == actions[it].point && action.uuid == actions[it].uuid {
                    actions[it] = actions[nr_of_actions-1];
                    nr_of_actions -= 1;
                    return;
                }
            }

        case .CLICK;
            for 0..nr_of_actions-1 {
                if action.position == actions[it].position && action.uuid == actions[it].uuid {
                    actions[it] = actions[nr_of_actions-1];
                    nr_of_actions -= 1;
                    return;
                }
            }
    }
    log("couldn't find action in actions\n");
    log("%\n", action);
    for 0..nr_of_actions-1 log("%\n", actions[it]);
}

get_player :: (using game_state: *GameState, uuid: u64) -> *Player {
    assert(uuid != 0, "get_player: uuid == 0");

    for 0..nr_of_players
        if players[it].uuid == uuid
            return *players[it];

    return null;
}

add_player :: (using game_state: *GameState, uuid: u64, point: Vector2i, is_client: bool) {
    assert(nr_of_players != MAX_PLAYERS-1, "add_player: nr_of_players == MAX_PLAYERS-1");
    players[nr_of_players] = Player.{ position=map_to_screen(point), uuid=uuid, is_client=is_client };

    if is_client
        game_state.player_index = nr_of_players;

    nr_of_players += 1;
}

perform_action_request :: (using game_state: *GameState, request: *ActionRequest) -> (ActionResult, bool) {
    player := get_player(game_state, request.uuid);
    if #complete request.kind == {
        case .MOVE; {
            assert(player != null, tprint("perform_action_request: Found no player with uuid == %", request.uuid));

            player_grid := screen_to_map(player.position);
            destination := request.point;
            if !in_bounds(player_grid) || !in_bounds(destination)
                return ActionResult.{}, false;

            path := jump_point_search(player_grid, destination, WORLD.tiles,, temp);
            if path.count {
                player.state = .RUNNING;
                for tiles: WORLD.tiles
                    for * tile: tiles
                        tile.flags &= ~.PATH;

                if path.count >= PLAYER_PATH_COUNT { // truncate if too many points in path
                    diff := path.count - PLAYER_PATH_COUNT;
                    path.data, path.count += diff, -diff;
                }
                player.current_path_index = xx(path.count-1);

                for path {
                    player.path[it_index] = it;
                    WORLD.tiles[it.y][it.x].flags |= .PATH;
                }
            } else {
                player.current_path_index = -1;
            }

            return ActionResult.{ kind=.MOVE }, true;
        }

        case .ADD_PLAYER; { // @TODO: find better solution for this guy...
            if !request.ignore
                add_player(game_state, request.uuid, request.point, request.b_value);

            return ActionResult.{ kind=.ADD_PLAYER }, true;
        }

        case .CLICK; {
            if !player return ActionResult.{}, false;

            for 0..MAX_REGIONS-1 {
                region := *WORLD.regions[it];
                if rect_contains(region.entrance_btn, request.position) {
                    if region.owner_uuid return ActionResult.{}, false;

                    for index: region.entrance WORLD.tiles[index.y][index.x].flags |= .WHITELISTED;
                    region.owner_uuid = request.uuid;
                    player.gold_income += 1;

                    return ActionResult.{ kind=.CLAIM_REGION, network_id=region.network_id }, true;
                }
            }
        }
    }

    return ActionResult.{}, false;
}

simulate :: (using game_state: *GameState, dt: float32) {
    for tiles: WORLD.tiles
        for * tile: tiles
            tile.flags &= ~.HOVERED;

    mouse_pos: = mouse_to_screen(game_state) - HALF_TILE_RECT_SIZE;
    mouse_grid := screen_to_map(mouse_pos);
    if in_bounds(mouse_grid)
        WORLD.tiles[mouse_grid.y][mouse_grid.x].flags |= .HOVERED;

    for 0..nr_of_actions-1 perform_action_request(game_state, *actions[it]);

    is_income_tick := false;
    current_income_tick += dt;
    if current_income_tick >= income_tick {
        current_income_tick -= income_tick;
        is_income_tick = true;
    }

    for 0..nr_of_players-1 {
        player := *players[it];
        {
            using player;
            if is_income_tick
                gold += gold_income;

            if state == .RUNNING {
                if current_path_index >= 0 {
                    if move_position_to_target(*position, map_to_screen(path[current_path_index]), speed, dt) {
                        current_path_index -= 1;
                        if current_path_index < 0 then state = .IDLE;
                    }
                }
            }
            if is_interpolating {
                if move_position_to_target(*interpolated_position, position, speed, dt)
                    is_interpolating = false;
            }
        }
    }
}

move_position_to_target :: (position: *Vector2, target: Vector2, speed: float32, dt: float32) -> bool {
    distance := normalize(target - position) * dt * speed;
    no_remaining := length_squared(target - position) <= length_squared(distance);
    position.* = ifx no_remaining then target else position + distance;
    return no_remaining;
}

player_feet_offset :: (using player: Player) -> Vector2 {
    return Vector2.{
        cast(float32, texture_rect.w) * 0,  // kinda @HARDCODED
        cast(float32, texture_rect.h) * 3/4 // kinda @HARDCODED
    };
}

mouse_to_screen :: (using game_state: *GameState) -> Vector2 {
    offset := input_state.mouse_position - (SCREEN_SIZE / 2);
    return Vector2.{
        offset.x / game_state.view.zoom + game_state.view.position.x,
        offset.y / game_state.view.zoom + game_state.view.position.y
    };
}
