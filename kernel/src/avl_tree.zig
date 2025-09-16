const std = @import("std");

/// This isn't the optimal implementation, because we perform an allcoation for every node, and they might therefore be spread out in the memory
pub fn AvlTree(comptime T: type) type {
    return struct {
        root: ?*Node,
        cmp_fn: *const fn (*T, *T) bool,
        allocator: std.mem.Allocator,

        pub const Node = struct {
            value: *T,
            // It should be possible not to store exact absolute height, and only the balance factor
            height: u64,
            left: ?*Node,
            right: ?*Node,
            parent: ?*Node,
        };

        pub fn insert(self: *AvlTree, value: *T) void {
            // TODO
            var curr_node_ptr: *?*Node = &self.root;
            var parent_node: ?*Node = null;
            while (curr_node_ptr.*) |curr_node_nn| {
                parent_node = curr_node_nn;
                if (self.cmp_fn(value, curr_node_nn.value)) {
                    curr_node_ptr = &curr_node_nn.left;
                } else {
                    curr_node_ptr = &curr_node_nn.right;
                }
            }
            curr_node_ptr.* = try self.allocator.create(Node);
            curr_node_ptr.*.?.* = .{
                .value = value,
                .height = 1,
                .left = null,
                .right = null,
                .parent = parent_node,
            };

            var backtracking_curr_node = curr_node_ptr.*;
            while (backtracking_curr_node) |backtracking_curr_node_nn| {
                const left_height = if (backtracking_curr_node_nn.left) |bcnl| {
                    break bcnl.height;
                } else {
                    break 0;
                };
                const right_height = if (backtracking_curr_node_nn.right) |bcnr| {
                    break bcnr.height;
                } else {
                    break 0;
                };
                backtracking_curr_node_nn.height = 1 + @max(
                    (backtracking_curr_node_nn.left orelse (&0)).*,
                    (backtracking_curr_node_nn.right orelse (&0)).*,
                );
                backtracking_curr_node = backtracking_curr_node_nn.parent;
            }
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
