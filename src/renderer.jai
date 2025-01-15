#import "SDL";
Hash_Table :: #import "Hash_Table";

RenderState :: struct {
    window: *SDL_Window = null;
    renderer: *SDL_Renderer = null;

    textures: Hash_Table.Table(string, *SDL_Texture);

    view_pos: Vector2;
    view_zoom: float32 = 1.0;
}

make_render_state :: () -> (*RenderState, bool) {
    render_state := New(RenderState);
    render_state.window = SDL_CreateWindow("Game", 400, 300, cast(s32, SCREEN_SIZE.x), cast(s32, SCREEN_SIZE.y), 0);
    if !render_state.window {
        log("SDL_CreateWindow: %\n", to_string(SDL_GetError()));
        return null, false;
    }

    render_state.renderer = SDL_CreateRenderer(render_state.window, -1, 0);
    if !render_state.renderer {
        log("SDL_CreateRenderer: %\n", to_string(SDL_GetError()));
        return null, false;
    }

    surface: *SDL_Surface;
    texture: *SDL_Texture;
    ok: bool;
    assets := string.["resources/mage.bmp", "resources/tileset.bmp"];
    for str: assets {
        surface = SDL_LoadBMP(str.data);
        if !surface {
            log("SDL_LoadBMP(%): %\n", str, to_string(SDL_GetError()));
            return null, false;
        }

        texture = SDL_CreateTextureFromSurface(render_state.renderer, surface);
        Hash_Table.table_set(*render_state.textures, str, texture);
        log("Loaded asset \"%\" with id \"%\"\n", str, str);
    }

    return render_state, true;
}

apply_camera_transform :: (rect: *SDL_Rect, using render_state: *RenderState) -> SDL_Rect {
    return SDL_Rect.{
        xx ((rect.x - view_pos.x) * view_zoom + SCREEN_SIZE.x / 2), // @HARDCODED
        xx ((rect.y - view_pos.y) * view_zoom + SCREEN_SIZE.y / 2), // @HARDCODED
        xx (rect.w * view_zoom),
        xx (rect.h * view_zoom)
    };
}

render_rect :: (using render_state: *RenderState, texture_rect: SDL_Rect, pos: Vector2, texture: *SDL_Texture, debug: bool = false) {
    dest_rect := SDL_Rect.{ xx pos.x, xx pos.y, texture_rect.w, texture_rect.h };
    transformed_dest_rect := apply_camera_transform(*dest_rect, render_state);
    SDL_RenderCopy(renderer, texture, *texture_rect, *transformed_dest_rect);
    #if DEBUG {
        if debug {
            SDL_SetRenderDrawColor(renderer, 255, 0, 0, 1);
            SDL_RenderDrawRect(renderer, *transformed_dest_rect);
        }
    }
}

render :: (using state: *AppState, alpha: float32) {
    using render_state;

    SDL_SetRenderDrawColor(renderer, 100, 100, 100, 1);
    SDL_RenderClear(renderer);

    texture: *SDL_Texture;
    ok: bool;

    texture, ok = Hash_Table.table_find(*textures, game_state.tiles[0][0].texture_id);
    assert(ok, "couldn't find texture");
    for tiles: game_state.tiles
        for tiles render_rect(render_state, it.texture_rect, it.position, texture);

    render_rect(render_state, game_state.pointer.texture_rect, game_state.pointer.position, texture, true);

    texture, ok = Hash_Table.table_find(*textures, game_state.player.texture_id);
    assert(ok, "couldn't find texture");
    render_rect(render_state, game_state.player.texture_rect, lerp_vec(game_state.player.prev_position, alpha), texture, true);

    SDL_RenderPresent(renderer);
}