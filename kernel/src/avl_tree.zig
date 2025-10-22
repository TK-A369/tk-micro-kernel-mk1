const std = @import("std");

const misc = @import("misc.zig");

/// This isn't the optimal implementation, because we perform an allocation for every node, and they might therefore be spread out in the memory
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

        const This = @This();

        pub fn init(allocator: std.mem.Allocator, cmp_fn: *const fn (*T, *T) bool) This {
            return .{
                .root = null,
                .cmp_fn = cmp_fn,
                .allocator = allocator,
            };
        }

        fn getHeight(node: ?*Node) u64 {
            if (node) |node_nn| {
                return node_nn.height;
            } else {
                return 0;
            }
        }

        fn updateHeight(node: ?*Node) void {
            if (node) |node_nn| {
                const left_height = getHeight(node_nn.left);
                const right_height = getHeight(node_nn.right);
                node_nn.height = @max(left_height, right_height) + 1;
            }
        }

        // From:
        //     A
        //  e     B
        //       c d
        // To:
        //     B
        //  A     d
        // e c
        fn rotateLeft(self: *This, node_a: *Node) !*Node {
            const node_b = node_a.right;
            if (node_b) |node_b_nn| {
                const node_c = node_b_nn.left;
                // const node_d = node_b_nn.right;
                // const node_e = node_a.left;
                const par_a = node_a.parent;

                node_b_nn.left = node_a;
                node_b.parent = par_a;
                node_a.parent = node_b_nn;
                if (par_a) |par_a_nn| {
                    if (par_a_nn.left == node_a) {
                        par_a_nn.left = node_b_nn;
                    } else {
                        par_a_nn.right = node_b_nn;
                    }
                } else {
                    self.root = node_b_nn;
                }

                node_a.right = node_c;
                if (node_c) |node_c_nn| {
                    node_c_nn.parent = node_a;
                }

                return node_b_nn;
            } else {
                return error.IllegalRotation;
            }
        }

        //     A
        //  B     e
        // c d
        // To:
        //     B
        //  c     A
        //       d e
        fn rotateRight(self: *This, node_a: *Node) !*Node {
            const node_b = node_a.left;
            if (node_b) |node_b_nn| {
                // const node_c = node_b_nn.left;
                const node_d = node_b_nn.right;
                // const node_e = node_a.right;
                const par_a = node_a.parent;

                node_b_nn.right = node_a;
                node_b_nn.parent = par_a;
                node_a.parent = node_b;
                if (par_a) |par_a_nn| {
                    if (par_a_nn.left == node_a) {
                        par_a_nn.left = node_b_nn;
                    } else {
                        par_a_nn.right = node_b_nn;
                    }
                } else {
                    self.root = node_b_nn;
                }

                node_a.left = node_d;
                if (node_d) |node_d_nn| {
                    node_d_nn.parent = node_a;
                }

                return node_b_nn;
            } else {
                return error.IllegalRotation;
            }
        }

        pub fn insert(self: *This, value: *T, curr_node: ?*Node, parent_node: ?*Node) *Node {
            if (curr_node) |curr_node_nn| {
                if (self.cmp_fn(value, curr_node_nn.value)) {
                    curr_node_nn.left = self.insert(value, curr_node_nn.left, curr_node_nn);
                } else {
                    curr_node_nn.right = self.insert(value, curr_node_nn.rigth, curr_node_nn);
                }
                updateHeight(curr_node_nn);

                const bf = @as(i64, getHeight(curr_node_nn.left)) - @as(i64, getHeight(curr_node_nn.right));
                if (bf >= 2) {
                    // Left-heavy
                    if (self.cmp_fn(curr_node_nn.left.?, value)) {
                        self.rotateLeft(curr_node_nn.left.?);
                        return self.rotateRight(curr_node_nn);
                    } else {
                        return rotateRight(curr_node_nn);
                    }
                } else if (bf <= -2) {
                    // Right-heavy
                    if (self.cmp_fn(value, curr_node.right.?.data)) {
                        rotateRight(curr_node_nn.right);
                        return rotateLeft(curr_node_nn);
                    } else {
                        return rotateLeft(curr_node_nn);
                    }
                } else {
                    return curr_node_nn;
                }
            } else {
                curr_node = self.allocator.create(Node);
                curr_node.?.* = .{
                    .value = value,
                    .height = 1,
                    .left = null,
                    .right = null,
                    .parent = parent_node,
                };
                return curr_node.?;
            }
        }

        pub fn search(self: *This, value: *T) ?*Node {
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

        pub fn delete(self: *This, value: *T, curr_node: ?*Node) !?*Node {
            if (curr_node) |curr_node_nn| {
                if (self.cmp_fn(value, curr_node_nn.data)) {
                    curr_node_nn.left = self.delete(value, curr_node_nn.left);
                } else if (self.cmp_fn(curr_node_nn.data, value)) {
                    curr_node_nn.right = self.devele(value, curr_node_nn.right);
                } else {
                    // TODO
                    if (curr_node_nn.left) |left_nn| {} else {
                        if (curr_node_nn.right) |right_nn| {} else {
                            self.allocator.destroy(curr_node_nn);
                        }
                    }
                }
            } else {
                return null;
            }
        }
    };
}
