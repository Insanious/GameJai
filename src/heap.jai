Heap :: struct (type: Type, given_comparison_function: (type, type) -> bool) {
    nodes: [..]type;
    comparison_function :: given_comparison_function;
}

heap_push :: (heap: *Heap, node: heap.type) {
    array_add(*heap.nodes, node);
    heapify_up(heap, heap.nodes.count - 1);
}

heap_pop :: (using heap: *Heap) -> (heap.type, success: bool) {
    if nodes.count == 0 {
        dummy: type = ---;
        return dummy, false;
    }

    node := nodes[0];
    nodes[0] = nodes[nodes.count - 1];
    nodes.count -= 1;

    if nodes.count > 0 heapify_down(heap, 0);

    return node, true;
}

#scope_file

LEFT ::     (i: s64) -> s64 #expand { return 2 * i + 1; }
RIGHT ::    (i: s64) -> s64 #expand { return 2 * i + 2; }
heapify_down :: (using heap: *Heap, index: s64) {
    smallest, left, right := index, LEFT(index), RIGHT(index);

    if left < nodes.count && comparison_function(nodes[left], nodes[smallest])   smallest = left;
    if right < nodes.count && comparison_function(nodes[right], nodes[smallest]) smallest = right;

    if smallest != index {
        nodes[index], nodes[smallest] = nodes[smallest], nodes[index];
        heapify_down(heap, smallest);
    }

}

PARENT :: (i: s64) -> s64 #expand { return (i-1) / 2; }
heapify_up :: (using heap: *Heap, index: s64) {
    parent: s64;
    while index > 0 && comparison_function(nodes[index], nodes[PARENT(index)]) {
        parent = PARENT(index);
        nodes[index], nodes[parent] = nodes[parent], nodes[index];
        index = parent;
    }
}
