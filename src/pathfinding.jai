#import "Hash";
#load "heap.jai";

#scope_file
Node :: struct {
    pos: Vector2i;
    parent: Vector2i;
    f: float32;
    g: float32;
    h: float32;
}

comparison_node :: (a: Node, b: Node) -> bool { return a.f < b.f; }

DIRECTIONS :: Vector2i.[ .{0, -1}, .{-1, 0}, .{1, 0}, .{0, 1}, .{-1, -1}, .{1, -1}, .{-1, 1}, .{1, 1} ];
#scope_export

heuristic :: (a: Vector2i, b: Vector2i) -> float32 {
    dx : float32 = xx abs(a.x - b.x);
    dy : float32 = xx abs(a.y - b.y);
    return (dx + dy) + xx(ROOT_2 - 2) * min(dx, dy);
}

is_walkable :: (using vector: Vector2i, tiles: [TILES_Y][TILES_X]Tile) -> bool {
    return x >= 0 && x < TILES_X && y >= 0 && y < TILES_Y && tiles[y][x].flags & .WALKABLE;
}

jump_diagonal :: (current: Vector2i, dir: Vector2i, goal: Vector2i, tiles: [TILES_Y][TILES_X]Tile) -> Vector2i {
    next := current + dir;
    if !is_walkable(next, tiles)        return .{-1, -1};

    h_inv_blocked := !is_walkable(Vector2i.{-dir.x, 0} + next, tiles);
    v_inv_blocked := !is_walkable(Vector2i.{0, -dir.y} + next, tiles);
    // Check blocked inverted neighbors before checking goal to circumvent illegal diagonal move
    if h_inv_blocked && v_inv_blocked   return .{-1, -1};
    if next == goal                     return next;

    h_blocked := !is_walkable(Vector2i.{ dir.x, 0 } + next, tiles);
    v_blocked := !is_walkable(Vector2i.{ 0, dir.y } + next, tiles);
    // Check forced neighbors
    if h_blocked && !v_blocked || v_blocked && !h_blocked return next;

    // Check horizontal and vertical directions
    if (jump_orthogonal(next, .{dir.x, 0}, goal, tiles).x != -1) ||
       (jump_orthogonal(next, .{0, dir.y}, goal, tiles).x != -1)
        return next;

    return jump_diagonal(next, dir, goal, tiles);
}

jump_orthogonal :: (current: Vector2i, dir: Vector2i, goal: Vector2i, tiles: [TILES_Y][TILES_X]Tile) -> Vector2i {
    next := current + dir;
    if !is_walkable(next, tiles) return .{-1, -1};
    if next == goal              return next;

    l := Vector2i.{ dir.y, -dir.x } + next;
    r := Vector2i.{ -dir.y, dir.x } + next;
    // Check forced neighbors on diagonal
    if !is_walkable(l, tiles) && is_walkable(l+dir, tiles) ||
       !is_walkable(r, tiles) && is_walkable(r+dir, tiles)
        return next;

    return jump_orthogonal(next, dir, goal, tiles);
}

successors :: (current: Node, goal: Vector2i, tiles: [TILES_Y][TILES_X]Tile) -> []Node {
    successors: [..]Node;
    for dir: DIRECTIONS {
        if !is_walkable(current.pos + dir, tiles) continue;

        jump_point := ifx (dir.x != 0 && dir.y != 0)
            then jump_diagonal(current.pos, dir, goal, tiles)
            else jump_orthogonal(current.pos, dir, goal, tiles);
        if jump_point.x != -1 {
            g := current.g + heuristic(current.pos, jump_point);
            h := heuristic(jump_point, goal);
            array_add(*successors, Node.{ pos=jump_point, parent=current.pos, f=h+g, g=g, h=h });
        }
    }

    return successors;
}

// returns a reversed path. Why? Because I say so.
jump_point_search :: (start: Vector2i, goal: Vector2i, tiles: [TILES_Y][TILES_X]Tile) -> []Vector2i {
    not_visited: Heap(Node, comparison_node);
    visited: Table(Vector2i, Node, hash_vector2i, compare_vector2i);
    path: [..]Vector2i;

    start_node := Node.{ pos=start, parent=.{-1, -1}, f=heuristic(start, goal), g=0, h=heuristic(start, goal) };
    heap_push(*not_visited, start_node);
    while not_visited.nodes.count {
        current := heap_pop(*not_visited);

        if current.pos == goal {
            node, ok := current, true;
            while ok && node.pos != start_node.pos {
                array_add(*path, node.pos);
                node, ok = table_find(*visited, node.parent);
            }
            return path;
        }

        if table_contains(*visited, current.pos) continue;
        table_set(*visited, current.pos, current);

        for successors(current, goal, tiles) heap_push(*not_visited, it);
    }

    return path;
}

// @REFACTOR needs special touch prob
// returns a reversed path. Why? Because I say so.
a_star :: (start: Vector2i, goal: Vector2i, tiles: [TILES_Y][TILES_X]Tile) -> []Vector2i {
    open_list: Heap(Node, comparison_node);
    closed_set: Table(Vector2i, Node, hash_vector2i, compare_vector2i);
    all_nodes: Table(Vector2i, Node, hash_vector2i, compare_vector2i);
    path: [..]Vector2i;

    start_node := Node.{ pos=start, f=heuristic(start, goal), g=0, h=heuristic(start, goal) };
    heap_push(*open_list, start_node);
    table_set(*all_nodes, start, start_node);
    while open_list.nodes.count {
        current := heap_pop(*open_list);

        if current.pos == goal {
            node, ok := current, true;
            while ok && node.pos != start_node.pos {
                array_add(*path, node.pos);
                node, ok = table_find(*closed_set, node.parent);
            }
            return path;
        }
        table_set(*closed_set, current.pos, current);

        for dir: DIRECTIONS {
            pos := current.pos + dir;
            if is_walkable(pos, tiles) && !table_contains(*closed_set, pos) {
                cost: float32 = ifx (pos.x != current.pos.x && pos.y != current.pos.y) xx ROOT_2 else 1.0;
                g := current.g + cost;
                h := heuristic(pos, goal);
                f := g + h;
                node, ok := table_find(*all_nodes, pos);
                if !ok || g < node.g {
                    neighbor := Node.{pos=pos, f=f, g=g, h=h, parent=current.pos};
                    heap_push(*open_list, neighbor);
                    table_set(*all_nodes, neighbor.pos, neighbor);
                }
            }
        }
    }

    return path;
}
