const std = @import("std");

const misc = @import("misc.zig");

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

            // Perform balancing
            var backtracking_curr_node = curr_node_ptr.*;
            while (backtracking_curr_node) |backtracking_curr_node_nn| {
                const left_height: u64 = if (backtracking_curr_node_nn.left) |bcnl| {
                    break bcnl.height;
                } else {
                    break 0;
                };
                const right_height: u64 = if (backtracking_curr_node_nn.right) |bcnr| {
                    break bcnr.height;
                } else {
                    break 0;
                };
                const bf: i64 = right_height - left_height;
                // If necessary, perform rotation
                if (bf >= 2) {
                    if (backtracking_curr_node_nn.right) |bcnr| {
                        //     A
                        //  B     C
                        //       D E
                        // ==========>
                        //     C
                        //  A     E
                        // B D
                        const node_a_val = backtracking_curr_node_nn.value;
                        const node_c_val = bcnr.value;
                        const node_b = bcnr.backtracking_curr_node_nn.left;
                        const node_d = bcnr.left;
                        const node_e = bcnr.right;
                        // Node C
                        backtracking_curr_node_nn.value = node_c_val;
                        backtracking_curr_node_nn.left = bcnr;
                        bcnr.parent = backtracking_curr_node_nn;
                        backtracking_curr_node_nn.right = node_e;
                        if (node_e) |node_e_nn| {
                            node_e_nn.parent = backtracking_curr_node_nn;
                        }
                        // Node A
                        bcnr.value = node_a_val;
                        bcnr.left = node_b;
                        if (node_b) |node_b_nn| {
                            node_b_nn.parent = bcnr;
                        }
                        bcnr.right = node_d;
                        if (node_d) |node_d_nn| {
                            node_d_nn.parent = bcnr;
                        }
                    } else {
                        // This shouldn't ever happen
                        misc.hcf();
                    }
                } else if (bf <= -2) {
                    if (backtracking_curr_node_nn.left) |bcnl| {
                        //     A
                        //  B     C
                        // D E
                        // ==========>
                        //     B
                        //  D     A
                        //       E C
                        const node_a_val = backtracking_curr_node_nn.value;
                        const node_b_val = bcnl.value;
                        const node_c = backtracking_curr_node_nn.right;
                        const node_d = bcnl.left;
                        const node_e = bcnl.right;
                        // Node B
                        backtracking_curr_node_nn.value = node_b_val;
                        backtracking_curr_node_nn.left = node_d;
                        if (node_d) |node_d_nn| {
                            node_d_nn.parent = backtracking_curr_node_nn;
                        }
                        backtracking_curr_node_nn.right = bcnl;
                        bcnl.parent = backtracking_curr_node_nn;
                        // Node A
                        bcnl.value = node_a_val;
                        bcnl.left = node_e;
                        if (node_e) |node_e_nn| {
                            node_e_nn.parent = bcnl;
                        }
                        bcnl.right = node_c;
                        if (node_c) |node_c_nn| {
                            node_c_nn.parent = bcnl;
                        }
                    } else {
                        // This shouldn't ever happen
                        misc.hcf();
                    }
                }
                backtracking_curr_node_nn.height = 1 + @max(
                    left_height,
                    right_height,
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
