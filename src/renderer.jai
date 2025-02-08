#import "SDL";
#import "Hash_Table";

RenderState :: struct {
    window: *SDL_Window = null;
    renderer: *SDL_Renderer = null;

    textures: Table(string, *SDL_Texture);
}

make_render_state :: () -> (*RenderState, bool) {
    render_state := New(RenderState);
    #if SERVER              render_state.window = SDL_CreateWindow("Game Server", 400, 300, SCREEN_SIZE.x, SCREEN_SIZE.y, 0);
    #if CLIENT              render_state.window = SDL_CreateWindow("Game Client", 400, 300, SCREEN_SIZE.x, SCREEN_SIZE.y, 0);
    #if !SERVER && !CLIENT  render_state.window = SDL_CreateWindow("Game", 400, 300, SCREEN_SIZE.x, SCREEN_SIZE.y, 0);
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
        table_set(*render_state.textures, str, texture);
        log("Loaded asset \"%\" with id \"%\"\n", str, str);
    }

    return render_state, true;
}

render_rect :: (view: View, render_state: *RenderState, texture_rect: SDL_Rect, pos: Vector2, texture: *SDL_Texture, debug: bool = false) {
    dest_rect := SDL_Rect.{ xx pos.x, xx pos.y, texture_rect.w, texture_rect.h };
    transformed_dest_rect := SDL_Rect.{
        xx ((dest_rect.x - view.position.x) * view.zoom + SCREEN_SIZE.x / 2), // @HARDCODED
        xx ((dest_rect.y - view.position.y) * view.zoom + SCREEN_SIZE.y / 2), // @HARDCODED
        xx (dest_rect.w * view.zoom),
        xx (dest_rect.h * view.zoom)
    };
    #if DEBUG {
        if debug {
            SDL_SetRenderDrawColor(render_state.renderer, 255, 0, 0, 1);
            SDL_RenderDrawRect(render_state.renderer, *transformed_dest_rect);
        }
    }

    SDL_RenderCopy(render_state.renderer, texture, *texture_rect, *transformed_dest_rect);
}

render_tiles :: (view: View, tiles: [TILES_Y][TILES_X] Tile, render_state: *RenderState) {
    texture, ok := table_find(*render_state.textures, tiles[0][0].texture_id);
    assert(ok, "couldn't find texture");
    for t: tiles {
        for t {
            #if DEBUG {
                if     !it.is_walkable  SDL_SetTextureColorMod(texture, 255, 100, 100);
                else if it.is_path      SDL_SetTextureColorMod(texture, 100, 100, 255);
                else if it.is_hovered   SDL_SetTextureColorMod(texture, 100, 255, 100);
            }

            render_rect(view, render_state, it.texture_rect, it.position, texture, false);
            SDL_SetTextureColorMod(texture, 255, 255, 255);
        }
    }
}

render :: (using current: *GameState, previous: *GameState, render_state: *RenderState, alpha: float32) {
    SDL_SetRenderDrawColor(render_state.renderer, 100, 100, 100, 1);
    SDL_RenderClear(render_state.renderer);

    lerped_view := View.{ lerp_vec(previous.view.position, view.position, alpha), lerp(previous.view.zoom, view.zoom, alpha) };

    render_tiles(lerped_view, tiles, render_state);

    for 0..nr_of_players-1 {
        player := players[it];
        previous_player := previous.players[it];
        texture, ok := table_find(*render_state.textures, player.texture_id);
        assert(ok, "couldn't find texture");
        offset := entity_feet_offset(player);
        lerped := lerp_vec(previous_player.position - offset, player.position - offset, alpha);
        render_rect(lerped_view, render_state, player.texture_rect, lerped, texture, true);
    }

    SDL_RenderPresent(render_state.renderer);
}
