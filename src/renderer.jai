#import "Hash_Table";

RenderState :: struct {
    window: *SDL_Window = null;
    renderer: *SDL_Renderer = null;

    textures: Table(string, *SDL_Texture);
}

make_render_state :: () -> (*RenderState, bool) {
    render_state := New(RenderState);
    #if SERVER             ok := SDL_CreateWindowAndRenderer("Game Server", xx SCREEN_SIZE.x, xx SCREEN_SIZE.y, 0, *render_state.window, *render_state.renderer);
    #if CLIENT             ok := SDL_CreateWindowAndRenderer("Game Client", xx SCREEN_SIZE.x, xx SCREEN_SIZE.y, 0, *render_state.window, *render_state.renderer);
    #if !SERVER && !CLIENT ok := SDL_CreateWindowAndRenderer("Game",        xx SCREEN_SIZE.x, xx SCREEN_SIZE.y, 0, *render_state.window, *render_state.renderer);
    if !ok {
        log("SDL_CreateWindowAndRenderer: %\n", to_string(SDL_GetError()));
        return null, false;
    }

    surface: *SDL_Surface;
    texture: *SDL_Texture;
    assets := string.["resources/mage.bmp", "resources/tileset.bmp"];
    for str: assets {
        surface = SDL_LoadBMP(str.data);
        if !surface {
            log("SDL_LoadBMP(%): %\n", str, to_string(SDL_GetError()));
            return null, false;
        }

        texture = SDL_CreateTextureFromSurface(render_state.renderer, surface);
        if !SDL_SetTextureScaleMode(texture, .SDL_SCALEMODE_NEAREST) {
            log("SDL_SetTextureScaleMode(%): %\n", str, to_string(SDL_GetError()));
            return null, false;
        }
        table_set(*render_state.textures, str, texture);
        log("Loaded asset \"%\" with id \"%\"\n", str, str);
    }

    return render_state, true;
}

render_rect :: (view: View, render_state: *RenderState, texture_rect: Rect, pos: Vector2, texture: *SDL_Texture, debug: bool = false) {
    dest_rect := Rect.{ pos.x, pos.y, texture_rect.w, texture_rect.h };
    transformed_dest_rect := Rect.{
        (dest_rect.x - view.position.x) * view.zoom + SCREEN_SIZE.x / 2, // @HARDCODED
        (dest_rect.y - view.position.y) * view.zoom + SCREEN_SIZE.y / 2, // @HARDCODED
        dest_rect.w * view.zoom,
        dest_rect.h * view.zoom
    };

    SDL_transformed_dest_rect := to_SDL_FRect(transformed_dest_rect);
    SDL_texture_rect := to_SDL_FRect(texture_rect);
    #if DEBUG {
        if debug {
            SDL_SetRenderDrawColor(render_state.renderer, 255, 0, 0, 1);
            SDL_RenderRect(render_state.renderer, *SDL_transformed_dest_rect);
        }
    }


    SDL_RenderTexture(render_state.renderer, texture, *SDL_texture_rect, *SDL_transformed_dest_rect);
}

render_world :: (view: View, world: World, render_state: *RenderState) {
    texture, ok := table_find(*render_state.textures, world.tiles[0][0].texture_id);
    assert(ok, "couldn't find texture");
    for t: world.tiles {
        for t {
            #if DEBUG {
                if     !it.is_walkable    SDL_SetTextureColorMod(texture, 255, 100, 100);
                else if it.is_path        SDL_SetTextureColorMod(texture, 100, 100, 255);
                else if it.is_hovered     SDL_SetTextureColorMod(texture, 255, 255, 100);
                else if it.is_whitelisted SDL_SetTextureColorMod(texture, 100, 255, 100);
            }

            render_rect(view, render_state, it.texture_rect, it.position, texture, false);
            SDL_SetTextureColorMod(texture, 255, 255, 255);
        }
    }
    for area: world.areas {
        rect := area.entrance_btn;
        transformed_rect := Rect.{
            (rect.x - view.position.x) * view.zoom + SCREEN_SIZE.x / 2, // @HARDCODED
            (rect.y - view.position.y) * view.zoom + SCREEN_SIZE.y / 2, // @HARDCODED
            rect.w * view.zoom,
            rect.h * view.zoom
        };
        SDL_transformed_rect := to_SDL_FRect(transformed_rect);
        SDL_SetRenderDrawColor(render_state.renderer, 40, 40, 255, 0);
        SDL_RenderFillRect(render_state.renderer, *SDL_transformed_rect);
        SDL_RenderRect(render_state.renderer, *SDL_transformed_rect);
        SDL_SetRenderDrawColor(render_state.renderer, 255, 255, 255, 0);
    }

}

render :: (current: *GameState, previous: *GameState, render_state: *RenderState, view: View, alpha: float32) {
    SDL_SetRenderDrawColor(render_state.renderer, 100, 100, 100, 1);
    SDL_RenderClear(render_state.renderer);

    render_world(view, WORLD, render_state);

    for 0..current.nr_of_players-1 {
        player := current.players[it];

        previous_player := previous.players[it];
        if it >= previous.nr_of_players // don't interpolate
            previous_player = current.players[it];

        texture, ok := table_find(*render_state.textures, player.texture_id);
        assert(ok, "couldn't find texture");

        offset := entity_feet_offset(player);
        position := player.position;
        previous_position := previous_player.position;
        if previous_player.is_interpolating then previous_position = previous_player.interpolated_position;
        if player.is_interpolating          then position          = player.interpolated_position;

        lerped := lerp(previous_position - offset, position - offset, alpha);
        render_rect(view, render_state, player.texture_rect, lerped, texture, true);
    }

    SDL_RenderPresent(render_state.renderer);
    SDL_Delay(1);
}
