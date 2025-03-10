#import "Hash_Table";

RenderState :: struct {
    textures: Table(string, Texture);
    alpha: float32;
}

make_render_state :: () -> (*RenderState, bool) {
    render_state := New(RenderState);
    #if SERVER             InitWindow(xx SCREEN_SIZE.x, xx SCREEN_SIZE.y, "Game Server");
    #if CLIENT             InitWindow(xx SCREEN_SIZE.x, xx SCREEN_SIZE.y, "Game Client");
    #if !SERVER && !CLIENT InitWindow(xx SCREEN_SIZE.x, xx SCREEN_SIZE.y, "Game");

    assets := string.["resources/mage.bmp", "resources/tileset.bmp"];
    for str: assets {
        table_set(*render_state.textures, str, LoadTexture(str.data));
        log("- Loaded asset \"%\" with id \"%\"\n", str, str);
    }

    return render_state, true;
}

transform_to_view :: (view: View, rect: Rect, position: Vector2) -> Rectangle {
    return Rectangle.{
        (position.x - view.position.x) * view.zoom + SCREEN_SIZE.x / 2, // @HARDCODED
        (position.y - view.position.y) * view.zoom + SCREEN_SIZE.y / 2, // @HARDCODED
        rect.w * view.zoom,
        rect.h * view.zoom
    };
}

transform_to_view :: (view: View, rect: Rect) -> Rectangle { return transform_to_view(view, rect, Vector2.{ rect.x, rect.y }); }

draw_textured_rect :: (view: View, texture_rect: Rect, position: Vector2, texture: *Texture, tint: Color) {
    dest_rect := transform_to_view(view, texture_rect, position);
    src_rect := to_raylib_rect(texture_rect);
    DrawTexturePro(texture, src_rect, dest_rect, Vector2.{0, 0}, 0.0, tint);
}

draw_world :: (view: View, world: World, render_state: *RenderState) {
    texture, ok := table_find(*render_state.textures, world.tiles[0][0].texture_id);
    assert(ok, "couldn't find texture");

    for tiles: world.tiles {
        for tiles {
            tint := WHITE;
            if      !(it.flags & .WALKABLE)    tint = .{255, 100, 100, 255};
            else if   it.flags & .PATH         tint = .{100, 100, 255, 255};
            else if   it.flags & .HOVERED      tint = .{255, 255, 100, 255};
            else if   it.flags & .WHITELISTED  tint = .{100, 255, 100, 255};

            draw_textured_rect(view, it.texture_rect, it.position, *texture, tint);
        }
    }

    for area: world.areas
        DrawRectangleRec(transform_to_view(view, area.entrance_btn), DARKBLUE);
}

draw_players :: (view: View, current: *GameState, previous: *GameState, render_state: *RenderState) {
    for 0..current.nr_of_players-1 {
        player := current.players[it];

        prev_player := previous.players[it];
        if it >= previous.nr_of_players // don't interpolate
            prev_player = current.players[it];

        texture, ok := table_find(*render_state.textures, player.texture_id);
        assert(ok, "couldn't find texture");

        offset := entity_feet_offset(player);
        position :=          ifx player.is_interpolating          then player.interpolated_position          else player.position;
        previous_position := ifx prev_player.is_interpolating     then prev_player.interpolated_position     else prev_player.position;

        lerped := lerp(previous_position - offset, position - offset, render_state.alpha);
        draw_textured_rect(view, player.texture_rect, lerped, *texture, WHITE);
    }
}

render :: (current: *GameState, previous: *GameState, render_state: *RenderState, view: View) {
    ClearBackground(.{100, 100, 100, 255});
    BeginDrawing();
    {
        draw_world(view, WORLD, render_state);
        draw_players(view, current, previous, render_state);

        DrawFPS(0, 0);
    }
    EndDrawing();
}
