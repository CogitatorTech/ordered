const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

/// A Cartesian Tree implementation that maintains both BST property for keys
/// and heap property for priorities. Useful for range minimum queries and
/// as a treap data structure.
pub fn CartesianTree(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            key: K,
            value: V,
            priority: u32,
            left: ?*Node = null,
            right: ?*Node = null,

            fn init(key: K, value: V, priority: u32) Node {
                return Node{
                    .key = key,
                    .value = value,
                    .priority = priority,
                };
            }
        };

        root: ?*Node = null,
        allocator: Allocator,
        len: usize = 0,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.destroySubtree(self.root);
            self.* = undefined;
        }

        fn destroySubtree(self: *Self, node: ?*Node) void {
            if (node) |n| {
                self.destroySubtree(n.left);
                self.destroySubtree(n.right);
                self.allocator.destroy(n);
            }
        }

        /// Insert a key-value pair with random priority
        pub fn put(self: *Self, key: K, value: V) !void {
            const priority = std.crypto.random.int(u32);
            try self.putWithPriority(key, value, priority);
        }

        /// Insert a key-value pair with explicit priority
        pub fn putWithPriority(self: *Self, key: K, value: V, priority: u32) !void {
            const new_node = try self.allocator.create(Node);
            new_node.* = Node.init(key, value, priority);

            if (self.root == null) {
                self.root = new_node;
                self.len += 1;
                return;
            }

            self.root = try self.insertNode(self.root, new_node);
        }

        fn insertNode(self: *Self, root: ?*Node, new_node: *Node) !?*Node {
            if (root == null) {
                self.len += 1;
                return new_node;
            }

            const node = root.?;
            const key_cmp = std.math.order(new_node.key, node.key);

            if (key_cmp == .eq) {
                // Replace existing value
                node.value = new_node.value;
                node.priority = new_node.priority;
                self.allocator.destroy(new_node);
                return root;
            }

            if (new_node.priority > node.priority) {
                // New node becomes root, split current tree
                const split_result = self.split(root, new_node.key);
                new_node.left = split_result.left;
                new_node.right = split_result.right;
                self.len += 1;
                return new_node;
            }

            if (key_cmp == .lt) {
                node.left = try self.insertNode(node.left, new_node);
            } else {
                node.right = try self.insertNode(node.right, new_node);
            }

            return root;
        }

        const SplitResult = struct {
            left: ?*Node,
            right: ?*Node,
        };

        fn split(self: *Self, root: ?*Node, key: K) SplitResult {
            if (root == null) {
                return SplitResult{ .left = null, .right = null };
            }

            const node = root.?;
            const key_cmp = std.math.order(key, node.key);

            if (key_cmp == .lt) {
                const split_result = self.split(node.left, key);
                node.left = split_result.right;
                return SplitResult{ .left = split_result.left, .right = node };
            } else {
                const split_result = self.split(node.right, key);
                node.right = split_result.left;
                return SplitResult{ .left = node, .right = split_result.right };
            }
        }

        /// Get value by key
        pub fn get(self: *const Self, key: K) ?V {
            return self.getNode(self.root, key);
        }

        fn getNode(self: *const Self, root: ?*Node, key: K) ?V {
            if (root == null) return null;

            const node = root.?;
            const key_cmp = std.math.order(key, node.key);

            return switch (key_cmp) {
                .eq => node.value,
                .lt => self.getNode(node.left, key),
                .gt => self.getNode(node.right, key),
            };
        }

        /// Remove key from tree
        pub fn remove(self: *Self, key: K) bool {
            const result = self.removeNode(self.root, key);
            self.root = result.root;
            return result.removed;
        }

        const RemoveResult = struct {
            root: ?*Node,
            removed: bool,
        };

        fn removeNode(self: *Self, root: ?*Node, key: K) RemoveResult {
            if (root == null) {
                return RemoveResult{ .root = null, .removed = false };
            }

            const node = root.?;
            const key_cmp = std.math.order(key, node.key);

            if (key_cmp == .eq) {
                const merged = self.merge(node.left, node.right);
                self.allocator.destroy(node);
                self.len -= 1;
                return RemoveResult{ .root = merged, .removed = true };
            }

            if (key_cmp == .lt) {
                const result = self.removeNode(node.left, key);
                node.left = result.root;
                return RemoveResult{ .root = root, .removed = result.removed };
            } else {
                const result = self.removeNode(node.right, key);
                node.right = result.root;
                return RemoveResult{ .root = root, .removed = result.removed };
            }
        }

        fn merge(self: *Self, left: ?*Node, right: ?*Node) ?*Node {
            if (left == null) return right;
            if (right == null) return left;

            const left_node = left.?;
            const right_node = right.?;

            if (left_node.priority > right_node.priority) {
                left_node.right = self.merge(left_node.right, right);
                return left;
            } else {
                right_node.left = self.merge(left, right_node.left);
                return right;
            }
        }

        /// Check if key exists in tree
        pub fn contains(self: *const Self, key: K) bool {
            return self.get(key) != null;
        }

        /// Get the number of elements in the tree
        pub fn count(self: *const Self) usize {
            return self.len;
        }

        /// Check if the tree is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Iterator for in-order traversal
        pub const Iterator = struct {
            stack: std.ArrayList(*Node),
            allocator: Allocator,

            pub fn init(allocator: Allocator, root: ?*Node) Iterator {
                var it = Iterator{
                    .stack = .{},
                    .allocator = allocator,
                };
                it.pushLeft(root);
                return it;
            }

            pub fn deinit(self: *Iterator) void {
                self.stack.deinit(self.allocator);
            }

            fn pushLeft(self: *Iterator, node: ?*Node) void {
                var current = node;
                while (current) |n| {
                    self.stack.append(self.allocator, n) catch return; // Handle potential allocation failure
                    current = n.left;
                }
            }

            // src/cartesian_tree.zig

            pub fn next(self: *Iterator) ?struct { key: K, value: V } {
                // self.stack.pop() returns `?*Node`.
                // The `if` statement correctly handles the optional, unwrapping it into `node`.
                if (self.stack.pop()) |node| {
                    // 'node' is now a valid `*Node` pointer.
                    if (node.right) |right_node| {
                        self.pushLeft(right_node);
                    }
                    return .{ .key = node.key, .value = node.value };
                } else {
                    return null;
                }
            }
        };

        /// Create iterator for in-order traversal
        pub fn iterator(self: *const Self, allocator: Allocator) Iterator {
            return Iterator.init(allocator, self.root);
        }
    };
}

test "CartesianTree basic operations" {
    var tree = CartesianTree(i32, []const u8).init(testing.allocator);
    defer tree.deinit();

    // Test insertion and retrieval
    try tree.putWithPriority(5, "five", 10);
    try tree.putWithPriority(3, "three", 5);
    try tree.putWithPriority(7, "seven", 15);
    try tree.putWithPriority(1, "one", 3);

    try testing.expectEqual(@as(usize, 4), tree.count());
    try testing.expect(!tree.isEmpty());

    // Test get
    try testing.expectEqualStrings("five", tree.get(5).?);
    try testing.expectEqualStrings("three", tree.get(3).?);
    try testing.expectEqualStrings("seven", tree.get(7).?);
    try testing.expectEqualStrings("one", tree.get(1).?);
    try testing.expect(tree.get(99) == null);

    // Test contains
    try testing.expect(tree.contains(5));
    try testing.expect(tree.contains(3));
    try testing.expect(!tree.contains(99));

    // Test removal
    try testing.expect(tree.remove(3));
    try testing.expect(!tree.contains(3));
    try testing.expectEqual(@as(usize, 3), tree.count());
    try testing.expect(!tree.remove(99));
}

test "CartesianTree iterator" {
    var tree = CartesianTree(i32, i32).init(testing.allocator);
    defer tree.deinit();

    // Insert values with specific priorities to control structure
    try tree.putWithPriority(5, 50, 10);
    try tree.putWithPriority(3, 30, 5);
    try tree.putWithPriority(7, 70, 15);
    try tree.putWithPriority(1, 10, 3);
    try tree.putWithPriority(9, 90, 8);

    var it = tree.iterator(testing.allocator);
    defer it.deinit();

    // Should iterate in sorted key order
    const expected_keys = [_]i32{ 1, 3, 5, 7, 9 };
    const expected_values = [_]i32{ 10, 30, 50, 70, 90 };

    var i: usize = 0;
    while (it.next()) |entry| {
        try testing.expectEqual(expected_keys[i], entry.key);
        try testing.expectEqual(expected_values[i], entry.value);
        i += 1;
    }
    try testing.expectEqual(@as(usize, 5), i);
}

test "CartesianTree heap property" {
    // Test that heap property is maintained (higher priority nodes are ancestors)
    var tree = CartesianTree(i32, i32).init(testing.allocator);
    defer tree.deinit();

    try tree.putWithPriority(5, 50, 100); // Root (highest priority)
    try tree.putWithPriority(3, 30, 80); // Left subtree
    try tree.putWithPriority(7, 70, 90); // Right subtree
    try tree.putWithPriority(1, 10, 60); // Left-left
    try tree.putWithPriority(9, 90, 70); // Right-right

    // Verify structure maintains heap property
    // Root should have highest priority
    try testing.expectEqual(@as(u32, 100), tree.root.?.priority);
    try testing.expectEqual(@as(i32, 5), tree.root.?.key);
}
