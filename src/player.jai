PLAYER_STATE :: enum u16 {
    IDLE;
    RUNNING;
}

MAX_CLAIMED_REGIONS :: 2;
MAX_QUEUED_ACTIONS :: 2;
PLAYER_PATH_COUNT :: 16;
Player :: struct {
    path: [PLAYER_PATH_COUNT]Vector2i;
    using sprite: Sprite = .{ texture_id="resources/mage.bmp", texture_rect=Rect.{ x=0, y=0, w=32, h=48 } };
    claimed_regions: [MAX_CLAIMED_REGIONS]s64;
    queued_actions: [MAX_QUEUED_ACTIONS]ActionRequest;
    interpolated_position: Vector2;

    uuid: u64 = 0;
    gold: s32 = 0;
    speed: float32 = 160;
    nr_of_queued_actions: s16 = 0;
    nr_of_claimed_regions: s16 = 0;
    current_path_index: s16 = 0;

    state: PLAYER_STATE = .IDLE;
    is_client := false;
    is_interpolating: bool = false;
}

add_player :: (using game_state: *GameState, uuid: u64, point: Vector2i, is_client: bool) {
    assert(nr_of_players != MAX_PLAYERS-1, "add_player: nr_of_players == MAX_PLAYERS-1");
    players[nr_of_players] = Player.{ position=map_to_screen(point), uuid=uuid, is_client=is_client };

    if is_client
        game_state.player_index = nr_of_players;

    nr_of_players += 1;
}

get_player :: (using game_state: *GameState, uuid: u64) -> *Player {
    assert(uuid != 0, "get_player: uuid == 0");

    for 0..nr_of_players
        if players[it].uuid == uuid
            return *players[it];

    return null;
}

player_queue_action :: (using player: *Player, action: ActionRequest) {
    assert(nr_of_queued_actions < MAX_QUEUED_ACTIONS);
    queued_actions[nr_of_queued_actions] = action;
    nr_of_queued_actions += 1;
}

player_feet_offset :: (using player: Player) -> Vector2 {
    return Vector2.{
        cast(float32, texture_rect.w) * 0,  // kinda @HARDCODED
        cast(float32, texture_rect.h) * 3/4 // kinda @HARDCODED
    };
}

player_claim_region :: (using player: *Player, region: s64) {
    assert(nr_of_claimed_regions < MAX_CLAIMED_REGIONS, "nr_of_claimed_regions >= MAX_CLAIMED_REGIONS");
    claimed_regions[nr_of_claimed_regions] = region;
    nr_of_claimed_regions += 1;
}

calculate_gold_income :: (using player: *Player) -> s32 {
    return nr_of_claimed_regions;
}
