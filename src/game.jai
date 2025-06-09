#load "pathfinding.jai";
#load "world.jai";
#load "player.jai";

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
    position: Vector2;
}

get_sprite_rect :: (using sprite: Sprite) -> Rect { return Rect.{ position.x, position.y, texture_rect.w, texture_rect.h }; }

ActionResult :: struct {
    network_id: u32 = 0;

    RESULT :: enum u16 {
        MOVE;
        ADD_PLAYER;
        CLAIM_REGION;
        MOVE_STRUCTURE;
    }
    kind: RESULT;
}

ActionRequest :: struct {
    uuid: u64 = 0;

    point: Vector2i;
    position: Vector2;
    network_id: u32 = 0;
    b_value: bool = false;
    ignore: bool = false;

    ACTION :: enum u16 {
        MOVE;
        ADD_PLAYER;
        CLICK;

        CLAIM_REGION;
    }
    kind: ACTION;
}

copy_game_state :: (dst: *GameState, src: *GameState) {
    dst.players = src.players;
    dst.nr_of_players = src.nr_of_players;
    dst.player_index = src.player_index;
    dst.current_income_tick = src.current_income_tick;
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
    for 0..nr_of_actions-1 {
        matches := false;
        if action.kind == {
            case .MOVE;  matches = action.point == actions[it].point;
            case .CLICK; matches = action.position == actions[it].position;
        }
        if matches {
            actions[it] = actions[nr_of_actions-1];
            nr_of_actions -= 1;
            return;
        }
    }

    log("couldn't find action in actions:\n%\n", action);
    for 0..nr_of_actions-1 log("%\n", actions[it]);
}

region_is_claimed :: (using game_state: *GameState, region: s64) -> bool {
    for player: 0..nr_of_players-1
        for 0..players[player].nr_of_claimed_regions-1
            if players[player].claimed_regions[it] == region
                return true;

    return false;
}

calculate_path :: (player: *Player, destination: Vector2i) {
    player_grid := screen_to_map(player.position);
    path := jump_point_search(player_grid, destination, WORLD.tiles,, temp);
    if path.count {
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
}

perform_action_request :: (using game_state: *GameState, request: *ActionRequest) -> (ActionResult, bool) {
    player := get_player(game_state, request.uuid);
    if #complete request.kind == {
        case .MOVE;
            assert(player != null, tprint("perform_action_request: Found no player with uuid == %", request.uuid));

            if !in_bounds(screen_to_map(player.position)) || !in_bounds(request.point)
                return ActionResult.{}, false;

            calculate_path(player, request.point);
            player.state = ifx player.current_path_index >= 0 then .RUNNING else .IDLE;

            return ActionResult.{ kind=.MOVE }, true;

        case .ADD_PLAYER; // @TODO: find better solution for this guy...
            if !request.ignore
                add_player(game_state, request.uuid, request.point, request.b_value);

            return ActionResult.{ kind=.ADD_PLAYER }, true;

        case .CLICK;
            if !player return ActionResult.{}, false;

            for 0..MAX_REGIONS-1 {
                region := *WORLD.regions[it];
                // if rect_contains(region.entrance_btn, request.position) {
                //     if region_is_claimed(game_state, it) || player.nr_of_claimed_regions >= MAX_CLAIMED_REGIONS
                //         return ActionResult.{}, false;

                //     for index: region.entrance WORLD.tiles[index.y][index.x].flags |= .WHITELISTED;
                //     player_claim_region(player, it);

                //     return ActionResult.{ kind=.CLAIM_REGION, network_id=region.network_id }, true;
                // }
                if player.nr_of_queued_actions >= MAX_QUEUED_ACTIONS
                    return ActionResult.{}, false;

                if rect_contains(get_sprite_rect(region.headquarter_sprite), request.position) {
                    // if region_is_claimed(game_state, it) || player.nr_of_claimed_regions >= MAX_CLAIMED_REGIONS
                    //     return ActionResult.{}, false;

                    destination := screen_to_map(request.position); // TEMP, good enough?
                    // destination := screen_to_map(request.position - HALF_TILE_RECT_SIZE);
                    calculate_path(player, destination);
                    player.state = ifx player.current_path_index >= 0 then .RUNNING else .IDLE;
                    player_queue_action(player, ActionRequest.{ kind=.CLAIM_REGION, network_id=region.network_id, uuid=request.uuid });

                    return ActionResult.{ kind=.MOVE_STRUCTURE, network_id=region.network_id }, true;
                }
            }

        case .CLAIM_REGION;
            if !player return ActionResult.{}, false;

            for 0..MAX_REGIONS-1 {
                region := *WORLD.regions[it];
                if region.network_id == request.network_id {
                    if region_is_claimed(game_state, it) || player.nr_of_claimed_regions >= MAX_CLAIMED_REGIONS
                        return ActionResult.{}, false;

                    for index: region.entrance WORLD.tiles[index.y][index.x].flags |= .WHITELISTED;
                    player_claim_region(player, it);
                }
            }
    }

    return ActionResult.{}, false;
}

simulate :: (using game_state: *GameState, dt: float32) {
    for tiles: WORLD.tiles
        for * tile: tiles
            tile.flags &= ~.HOVERED;

    mouse_pos := mouse_to_screen(game_state);
    mouse_grid := screen_to_map(mouse_pos - HALF_TILE_RECT_SIZE);
    if in_bounds(mouse_grid)
        WORLD.tiles[mouse_grid.y][mouse_grid.x].flags |= .HOVERED;

    for 0..nr_of_actions-1 perform_action_request(game_state, *actions[it]);

    for 0..MAX_REGIONS-1 {
        region := *WORLD.regions[it];
        rect := get_sprite_rect(region.headquarter_sprite);
        region.headquarter_tint = ifx rect_contains(rect, mouse_pos) MAROON else DARKBLUE;
    }

    current_income_tick += dt;
    is_income_tick := (current_income_tick >= income_tick);
    if is_income_tick then current_income_tick -= income_tick;

    for 0..nr_of_players-1 {
        player := *players[it];
        {
            using player;
            if is_income_tick
                gold += calculate_gold_income(player);

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

            if nr_of_queued_actions != 0 && state == .IDLE { // there was an action queued up
                nr_of_queued_actions -= 1;
                action := queued_actions[nr_of_queued_actions];
                perform_action_request(game_state, *action);
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

mouse_to_screen :: (using game_state: *GameState) -> Vector2 {
    offset := input_state.mouse_position - (SCREEN_SIZE / 2);
    return Vector2.{
        offset.x / game_state.view.zoom + game_state.view.position.x,
        offset.y / game_state.view.zoom + game_state.view.position.y
    };
}
