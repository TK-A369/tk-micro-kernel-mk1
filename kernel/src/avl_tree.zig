pub fn AvlTree(comptime T: type) type {
    return struct {
        root: ?*Node,
        cmp_fn: *const fn (*T, *T) bool,

        pub const Node = struct {
            value: *T,
            height: u64,
            left: ?*Node,
            right: ?*Node,
        };

        pub fn insert(self: *AvlTree, value: *T) void {
            // TODO
            _ = self;
            _ = value;
        }

        pub fn search(self: *AvlTree, value: *T) ?*Node {
            var curr_node: ?*Node = self.root;
            while (curr_node) |curr_node_nn| {
                if (self.cmp_fn(curr_node_nn.value, value)) {
                    curr_node = curr_node_nn.right;
                } else if (self.cmp_fn(value, curr_node_nn.value)) {
                    curr_node = curr_node_nn.left;
                } else {
                    return curr_node_nn;
                }
            }
            return null;
        }
    };
}
