//! A B-Tree based associative map.
//! This is a workhorse for most ordered map use cases. B-Trees are extremely
//! cache-friendly due to their high branching factor, making them faster than
//! binary search trees for larger datasets.

const std = @import("std");

pub fn BTreeMap(
    comptime K: type,
    comptime V: type,
    comptime compare: fn (lhs: K, rhs: K) std.math.Order,
    comptime BRANCHING_FACTOR: u16,
) type {
    std.debug.assert(BRANCHING_FACTOR >= 3);
    const MIN_KEYS = (BRANCHING_FACTOR - 1) / 2;

    return struct {
        const Self = @This();
        const Node = struct {
            keys: [BRANCHING_FACTOR - 1]K,
            values: [BRANCHING_FACTOR - 1]V,
            children: [BRANCHING_FACTOR]?*Node,
            len: u16 = 0,
            is_leaf: bool = true,
        };

        root: ?*Node = null,
        allocator: std.mem.Allocator,
        len: usize = 0,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            if (self.root) |r| self.deinitNode(r);
            self.* = undefined;
        }

        fn deinitNode(self: *Self, node: *Node) void {
            if (!node.is_leaf) {
                for (node.children[0 .. node.len + 1]) |child| {
                    if (child) |c| self.deinitNode(c);
                }
            }
            self.allocator.destroy(node);
        }

        fn createNode(self: *Self) !*Node {
            const new_node = try self.allocator.create(Node);
            new_node.* = Node{
                .keys = undefined,
                .values = undefined,
                .children = [_]?*Node{null} ** BRANCHING_FACTOR,
                .len = 0,
                .is_leaf = true,
            };
            return new_node;
        }

        fn compareFn(key_as_context: K, item: K) std.math.Order {
            return compare(key_as_context, item);
        }

        /// Retrieves a pointer to the value associated with `key`.
        pub fn get(self: *const Self, key: K) ?*const V {
            var current = self.root;
            while (current) |node| {
                const res = std.sort.binarySearch(K, node.keys[0..node.len], key, compareFn);
                if (res) |index| return &node.values[index];

                if (node.is_leaf) return null;

                const insertion_point = std.sort.lowerBound(K, node.keys[0..node.len], key, compareFn);
                current = node.children[insertion_point];
            }
            return null;
        }

        /// Inserts a key-value pair. If the key exists, the value is updated.
        pub fn put(self: *Self, key: K, value: V) !void {
            // Check if key exists and just update the value in place
            if (self.get(key) != null) {
                _ = self.remove(key);
                // Don't increment len here, it will be incremented below
            }

            var root_node = if (self.root) |r| r else {
                const new_node = try self.createNode();
                new_node.keys[0] = key;
                new_node.values[0] = value;
                new_node.len = 1;
                self.root = new_node;
                self.len = 1;
                return;
            };

            if (root_node.len == BRANCHING_FACTOR - 1) {
                const new_root = try self.createNode();
                new_root.is_leaf = false;
                new_root.children[0] = root_node;
                self.root = new_root;
                self.splitChild(new_root, 0);
                root_node = new_root;
            }

            self.insertNonFull(root_node, key, value);
            self.len += 1;
        }

        fn splitChild(self: *Self, parent: *Node, index: u16) void {
            const child = parent.children[index].?;
            const new_sibling = self.createNode() catch @panic("OOM");
            new_sibling.is_leaf = child.is_leaf;

            const t = MIN_KEYS;
            // Calculate how many keys go to the right sibling
            // Full node has BRANCHING_FACTOR - 1 keys
            // Left child keeps t keys, parent gets 1, right sibling gets the rest
            const right_keys = BRANCHING_FACTOR - 1 - t - 1;
            new_sibling.len = right_keys;

            // Copy the right half of keys to the new sibling
            var j: u16 = 0;
            while (j < right_keys) : (j += 1) {
                new_sibling.keys[j] = child.keys[j + t + 1];
                new_sibling.values[j] = child.values[j + t + 1];
            }

            if (!child.is_leaf) {
                j = 0;
                while (j <= right_keys) : (j += 1) {
                    new_sibling.children[j] = child.children[j + t + 1];
                }
            }
            child.len = t;

            // Insert new sibling into parent
            j = parent.len;
            while (j > index) : (j -= 1) {
                parent.children[j + 1] = parent.children[j];
            }
            parent.children[index + 1] = new_sibling;

            j = parent.len;
            while (j > index) : (j -= 1) {
                parent.keys[j] = parent.keys[j - 1];
                parent.values[j] = parent.values[j - 1];
            }

            parent.keys[index] = child.keys[t];
            parent.values[index] = child.values[t];
            parent.len += 1;
        }

        fn insertNonFull(self: *Self, node: *Node, key: K, value: V) void {
            var i = node.len;
            if (node.is_leaf) {
                while (i > 0 and compare(key, node.keys[i - 1]) == .lt) : (i -= 1) {
                    node.keys[i] = node.keys[i - 1];
                    node.values[i] = node.values[i - 1];
                }
                node.keys[i] = key;
                node.values[i] = value;
                node.len += 1;
            } else {
                while (i > 0 and compare(key, node.keys[i - 1]) == .lt) : (i -= 1) {}
                if (node.children[i].?.len == BRANCHING_FACTOR - 1) {
                    self.splitChild(node, i);
                    if (compare(node.keys[i], key) == .lt) {
                        i += 1;
                    }
                }
                self.insertNonFull(node.children[i].?, key, value);
            }
        }

        pub fn remove(self: *Self, key: K) ?V {
            if (self.root == null) return null;
            const old_len = self.len;
            const val = self.deleteFromNode(self.root.?, key);
            if (self.root.?.len == 0 and !self.root.?.is_leaf) {
                const old_root = self.root.?;
                self.root = old_root.children[0];
                self.allocator.destroy(old_root);
            }
            if (old_len > self.len) return val;
            return null;
        }

        fn deleteFromNode(self: *Self, node: *Node, key: K) ?V {
            const res = std.sort.binarySearch(K, node.keys[0..node.len], key, compareFn);
            var val: ?V = null;

            if (res) |index_usize| {
                const index = @as(u16, @intCast(index_usize));
                val = node.values[index];
                self.len -= 1;
                if (node.is_leaf) {
                    self.removeFromLeaf(node, index);
                } else {
                    self.removeFromInternal(node, index);
                }
            } else if (!node.is_leaf) {
                const insertion_point = std.sort.lowerBound(K, node.keys[0..node.len], key, compareFn);
                const key_exists_in_child = self.ensureChildHasEnoughKeys(node, @as(u16, @intCast(insertion_point)));
                if (key_exists_in_child) {
                    return self.deleteFromNode(node, key);
                }
                return self.deleteFromNode(node.children[insertion_point].?, key);
            }
            return val;
        }

        fn removeFromLeaf(_: *Self, node: *Node, index: u16) void {
            var i = index;
            while (i < node.len - 1) : (i += 1) {
                node.keys[i] = node.keys[i + 1];
                node.values[i] = node.values[i + 1];
            }
            node.len -= 1;
        }

        fn removeFromInternal(self: *Self, node: *Node, index: u16) void {
            const key = node.keys[index];
            if (node.children[index].?.len > MIN_KEYS) {
                const pred = self.getPredecessor(node, index);
                node.keys[index] = pred.key;
                node.values[index] = pred.value;
                _ = self.deleteFromNode(node.children[index].?, pred.key);
                self.len += 1;
            } else if (node.children[index + 1].?.len > MIN_KEYS) {
                const succ = self.getSuccessor(node, index);
                node.keys[index] = succ.key;
                node.values[index] = succ.value;
                _ = self.deleteFromNode(node.children[index + 1].?, succ.key);
                self.len += 1;
            } else {
                self.merge(node, index);
                _ = self.deleteFromNode(node.children[index].?, key);
                self.len += 1;
            }
        }

        const PredSucc = struct { key: K, value: V };
        fn getPredecessor(_: *Self, node: *Node, index: u16) PredSucc {
            var current = node.children[index].?;
            while (!current.is_leaf) current = current.children[current.len].?;
            return .{ .key = current.keys[current.len - 1], .value = current.values[current.len - 1] };
        }
        fn getSuccessor(_: *Self, node: *Node, index: u16) PredSucc {
            var current = node.children[index + 1].?;
            while (!current.is_leaf) current = current.children[0].?;
            return .{ .key = current.keys[0], .value = current.values[0] };
        }

        fn ensureChildHasEnoughKeys(self: *Self, node: *Node, index: u16) bool {
            if (node.children[index].?.len > MIN_KEYS) return false;

            if (index != 0 and node.children[index - 1].?.len > MIN_KEYS) {
                self.borrowFromPrev(node, index);
            } else if (index != node.len and node.children[index + 1].?.len > MIN_KEYS) {
                self.borrowFromNext(node, index);
            } else {
                if (index != node.len) {
                    self.merge(node, index);
                } else {
                    self.merge(node, index - 1);
                    return true;
                }
            }
            return false;
        }

        fn borrowFromPrev(_: *Self, node: *Node, index: u16) void {
            const child = node.children[index].?;
            const sibling = node.children[index - 1].?;

            var i = child.len;
            while (i > 0) : (i -= 1) {
                child.keys[i] = child.keys[i - 1];
                child.values[i] = child.values[i - 1];
            }
            if (!child.is_leaf) {
                i = child.len + 1;
                while (i > 0) : (i -= 1) {
                    child.children[i] = child.children[i - 1];
                }
                child.children[0] = sibling.children[sibling.len];
            }

            child.keys[0] = node.keys[index - 1];
            child.values[0] = node.values[index - 1];
            child.len += 1;

            node.keys[index - 1] = sibling.keys[sibling.len - 1];
            node.values[index - 1] = sibling.values[sibling.len - 1];
            sibling.len -= 1;
        }

        fn borrowFromNext(_: *Self, node: *Node, index: u16) void {
            const child = node.children[index].?;
            const sibling = node.children[index + 1].?;
            child.keys[child.len] = node.keys[index];
            child.values[child.len] = node.values[index];
            child.len += 1;
            if (!child.is_leaf) {
                child.children[child.len] = sibling.children[0];
            }

            node.keys[index] = sibling.keys[0];
            node.values[index] = sibling.values[0];

            var i: u16 = 0;
            while (i < sibling.len - 1) : (i += 1) {
                sibling.keys[i] = sibling.keys[i + 1];
                sibling.values[i] = sibling.values[i + 1];
            }
            if (!sibling.is_leaf) {
                i = 0;
                while (i < sibling.len) : (i += 1) {
                    sibling.children[i] = sibling.children[i + 1];
                }
            }
            sibling.len -= 1;
        }

        fn merge(self: *Self, node: *Node, index: u16) void {
            const child = node.children[index].?;
            const sibling = node.children[index + 1].?;

            child.keys[MIN_KEYS] = node.keys[index];
            child.values[MIN_KEYS] = node.values[index];

            var i: u16 = 0;
            while (i < sibling.len) : (i += 1) {
                child.keys[i + MIN_KEYS + 1] = sibling.keys[i];
                child.values[i + MIN_KEYS + 1] = sibling.values[i];
            }
            if (!child.is_leaf) {
                i = 0;
                while (i <= sibling.len) : (i += 1) {
                    child.children[i + MIN_KEYS + 1] = sibling.children[i];
                }
            }

            child.len += sibling.len + 1;

            i = index;
            while (i < node.len - 1) : (i += 1) {
                node.keys[i] = node.keys[i + 1];
                node.values[i] = node.values[i + 1];
            }
            i = index + 1;
            while (i < node.len) : (i += 1) {
                node.children[i] = node.children[i + 1];
            }
            node.len -= 1;
            self.allocator.destroy(sibling);
        }
    };
}

fn strCompare(lhs: []const u8, rhs: []const u8) std.math.Order {
    return std.mem.order(u8, lhs, rhs);
}

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

test "BTreeMap: put, get, and delete" {
    const allocator = std.testing.allocator;
    const B = 4;
    var map = BTreeMap(i32, []const u8, i32Compare, B).init(allocator);
    defer map.deinit();

    try map.put(10, "ten");
    try map.put(20, "twenty");
    try map.put(5, "five");
    try map.put(6, "six");
    try map.put(12, "twelve");
    try map.put(30, "thirty");
    try map.put(7, "seven");
    try map.put(17, "seventeen");
    try std.testing.expectEqual(@as(usize, 8), map.len);

    try std.testing.expectEqualStrings("five", map.get(5).?.*);
    try std.testing.expectEqualStrings("seven", map.get(7).?.*);

    const deleted = map.remove(10);
    try std.testing.expectEqualStrings("ten", deleted.?);
    try std.testing.expect(map.get(10) == null);
    try std.testing.expectEqual(@as(usize, 7), map.len);

    _ = map.remove(6);
    _ = map.remove(7);
    _ = map.remove(5);
    try std.testing.expectEqual(@as(usize, 4), map.len);

    try std.testing.expectEqualStrings("twenty", map.get(20).?.*);

    var str_map = BTreeMap([]const u8, i32, strCompare, B).init(allocator);
    defer str_map.deinit();
    try str_map.put("c", 3);
    try str_map.put("a", 1);
    try str_map.put("b", 2);
    try std.testing.expectEqual(2, str_map.get("b").?.*);
}

test "BTreeMap: empty map operations" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 4).init(allocator);
    defer map.deinit();

    try std.testing.expect(map.get(42) == null);
    try std.testing.expectEqual(@as(usize, 0), map.len);
    try std.testing.expect(map.remove(42) == null);
}

test "BTreeMap: single element operations" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, []const u8, i32Compare, 4).init(allocator);
    defer map.deinit();

    try map.put(42, "answer");
    try std.testing.expectEqual(@as(usize, 1), map.len);
    try std.testing.expectEqualStrings("answer", map.get(42).?.*);

    const removed = map.remove(42);
    try std.testing.expect(removed != null);
    try std.testing.expectEqualStrings("answer", removed.?);
    try std.testing.expectEqual(@as(usize, 0), map.len);
}

test "BTreeMap: update existing keys" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 4).init(allocator);
    defer map.deinit();

    try map.put(10, 100);
    try map.put(20, 200);
    try map.put(10, 999); // Update

    try std.testing.expectEqual(@as(usize, 2), map.len);
    try std.testing.expectEqual(@as(i32, 999), map.get(10).?.*);
}

test "BTreeMap: sequential insertion" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 5).init(allocator);
    defer map.deinit();

    var i: i32 = 0;
    while (i < 50) : (i += 1) {
        try map.put(i, i * 2);
    }

    try std.testing.expectEqual(@as(usize, 50), map.len);

    i = 0;
    while (i < 50) : (i += 1) {
        try std.testing.expectEqual(i * 2, map.get(i).?.*);
    }
}

test "BTreeMap: reverse insertion" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 5).init(allocator);
    defer map.deinit();

    var i: i32 = 50;
    while (i > 0) : (i -= 1) {
        try map.put(i, i * 3);
    }

    try std.testing.expectEqual(@as(usize, 50), map.len);

    i = 1;
    while (i <= 50) : (i += 1) {
        try std.testing.expectEqual(i * 3, map.get(i).?.*);
    }
}

test "BTreeMap: random operations" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 4).init(allocator);
    defer map.deinit();

    const values = [_]i32{ 15, 3, 27, 8, 42, 1, 19, 33, 11, 25 };
    for (values) |val| {
        try map.put(val, val * 10);
    }

    try std.testing.expectEqual(@as(usize, 10), map.len);

    for (values) |val| {
        try std.testing.expectEqual(val * 10, map.get(val).?.*);
    }

    // Remove some
    _ = map.remove(15);
    _ = map.remove(27);
    _ = map.remove(1);

    try std.testing.expectEqual(@as(usize, 7), map.len);
    try std.testing.expect(map.get(15) == null);
    try std.testing.expect(map.get(27) == null);
    try std.testing.expect(map.get(1) == null);
}

test "BTreeMap: remove all elements" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 4).init(allocator);
    defer map.deinit();

    try map.put(1, 1);
    try map.put(2, 2);
    try map.put(3, 3);
    try map.put(4, 4);
    try map.put(5, 5);

    _ = map.remove(1);
    _ = map.remove(2);
    _ = map.remove(3);
    _ = map.remove(4);
    _ = map.remove(5);

    try std.testing.expectEqual(@as(usize, 0), map.len);
    try std.testing.expect(map.get(3) == null);
}

test "BTreeMap: minimum branching factor" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 3).init(allocator);
    defer map.deinit();

    var i: i32 = 0;
    while (i < 20) : (i += 1) {
        try map.put(i, i);
    }

    try std.testing.expectEqual(@as(usize, 20), map.len);

    i = 0;
    while (i < 20) : (i += 1) {
        try std.testing.expectEqual(i, map.get(i).?.*);
    }
}

test "BTreeMap: negative keys" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 4).init(allocator);
    defer map.deinit();

    try map.put(-10, 10);
    try map.put(-5, 5);
    try map.put(0, 0);
    try map.put(5, -5);

    try std.testing.expectEqual(@as(i32, 10), map.get(-10).?.*);
    try std.testing.expectEqual(@as(i32, -5), map.get(5).?.*);
}
