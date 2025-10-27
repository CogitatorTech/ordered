//! A B-tree based associative map with configurable branching factor.
//!
//! B-trees are self-balancing tree data structures that maintain sorted data and allow
//! searches, sequential access, insertions, and deletions in logarithmic time. They are
//! optimized for systems that read and write large blocks of data.
//!
//! ## Complexity
//! - Insert: O(log n)
//! - Remove: O(log n)
//! - Search: O(log n)
//! - Space: O(n)
//!
//! ## Use Cases
//! - Large datasets where cache efficiency matters
//! - Ordered key-value storage with frequent range queries
//! - Database indices and file systems
//!
//! ## Thread Safety
//! This data structure is not thread-safe. External synchronization is required
//! for concurrent access.
//!
//! ## Iterator Invalidation
//! WARNING: Modifying the map (via put, remove, or clear) while iterating will cause
//! undefined behavior. Complete all iterations before modifying the structure.

const std = @import("std");

/// Creates a B-tree map type with the specified key type, value type, comparison function,
/// and branching factor.
///
/// ## Parameters
/// - `K`: The key type. Must be comparable via the `compare` function.
/// - `V`: The value type.
/// - `compare`: Function that compares two keys and returns their ordering.
/// - `BRANCHING_FACTOR`: Number of children per node (must be >= 3). Higher values
///   improve cache efficiency but use more memory per node. Typical values: 4-16.
///
/// ## Example
/// ```zig
/// fn i32Compare(a: i32, b: i32) std.math.Order {
///     return std.math.order(a, b);
/// }
/// var map = BTreeMap(i32, []const u8, i32Compare, 4).init(allocator);
/// ```
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

        /// Creates a new empty B-tree map.
        ///
        /// The map must be deinitialized with `deinit()` to free allocated memory.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// Returns the number of elements in the map.
        ///
        /// Time complexity: O(1)
        pub fn count(self: *const Self) usize {
            return self.len;
        }

        /// Frees all memory used by the map.
        ///
        /// After calling this, the map is no longer usable. All references to keys
        /// and values become invalid.
        pub fn deinit(self: *Self) void {
            self.clear();
            self.* = undefined;
        }

        /// Removes all elements from the map while keeping the allocated structure.
        ///
        /// Time complexity: O(n)
        pub fn clear(self: *Self) void {
            if (self.root) |r| self.deinitNode(r);
            self.root = null;
            self.len = 0;
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

        /// Retrieves an immutable pointer to the value associated with the given key.
        ///
        /// Returns `null` if the key does not exist in the map.
        ///
        /// Time complexity: O(log n)
        ///
        /// ## Example
        /// ```zig
        /// if (map.get(42)) |value| {
        ///     std.debug.print("Value: {}\n", .{value.*});
        /// }
        /// ```
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

        /// Retrieves a mutable pointer to the value associated with the given key.
        ///
        /// Returns `null` if the key does not exist. The returned pointer can be used
        /// to modify the value in place without re-inserting.
        ///
        /// Time complexity: O(log n)
        ///
        /// ## Example
        /// ```zig
        /// if (map.getPtr(42)) |value_ptr| {
        ///     value_ptr.* += 10;  // Modify in place
        /// }
        /// ```
        pub fn getPtr(self: *Self, key: K) ?*V {
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

        /// Checks whether the map contains the given key.
        ///
        /// Time complexity: O(log n)
        pub fn contains(self: *const Self, key: K) bool {
            return self.get(key) != null;
        }

        /// Inserts a key-value pair into the map. If the key already exists, updates its value.
        ///
        /// Time complexity: O(log n)
        ///
        /// ## Errors
        /// Returns `error.OutOfMemory` if allocation fails.
        ///
        /// ## Example
        /// ```zig
        /// try map.put(1, "one");
        /// try map.put(1, "ONE");  // Updates the value
        /// ```
        pub fn put(self: *Self, key: K, value: V) !void {
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
                try self.splitChild(new_root, 0);
                root_node = new_root;
            }

            const is_new = try self.insertNonFull(root_node, key, value);
            if (is_new) {
                self.len += 1;
            }
        }

        fn splitChild(self: *Self, parent: *Node, index: u16) !void {
            const child = parent.children[index].?;
            const new_sibling = try self.createNode();
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

        fn insertNonFull(self: *Self, node: *Node, key: K, value: V) !bool {
            var i = node.len;
            if (node.is_leaf) {
                // Check if key already exists
                var j: u16 = 0;
                while (j < node.len) : (j += 1) {
                    if (compare(key, node.keys[j]) == .eq) {
                        // Update existing value
                        node.values[j] = value;
                        return false; // Not a new insertion
                    }
                }

                // Insert new key
                while (i > 0 and compare(key, node.keys[i - 1]) == .lt) : (i -= 1) {
                    node.keys[i] = node.keys[i - 1];
                    node.values[i] = node.values[i - 1];
                }
                node.keys[i] = key;
                node.values[i] = value;
                node.len += 1;
                return true; // New insertion
            } else {
                // Check if key exists in current node
                var j: u16 = 0;
                while (j < node.len) : (j += 1) {
                    if (compare(key, node.keys[j]) == .eq) {
                        // Update existing value
                        node.values[j] = value;
                        return false; // Not a new insertion
                    }
                }

                while (i > 0 and compare(key, node.keys[i - 1]) == .lt) : (i -= 1) {}
                if (node.children[i].?.len == BRANCHING_FACTOR - 1) {
                    try self.splitChild(node, i);
                    if (compare(node.keys[i], key) == .lt) {
                        i += 1;
                    }
                }
                return try self.insertNonFull(node.children[i].?, key, value);
            }
        }

        /// Removes a key-value pair from the map and returns the value.
        ///
        /// Returns `null` if the key does not exist.
        ///
        /// Time complexity: O(log n)
        ///
        /// ## Example
        /// ```zig
        /// if (map.remove(42)) |value| {
        ///     std.debug.print("Removed value: {}\n", .{value});
        /// }
        /// ```
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
                // deleteFromNode already decremented self.len, so increment it back
                // because we're replacing, not actually removing
                const old_len = self.len;
                _ = self.deleteFromNode(node.children[index].?, pred.key);
                self.len = old_len;
            } else if (node.children[index + 1].?.len > MIN_KEYS) {
                const succ = self.getSuccessor(node, index);
                node.keys[index] = succ.key;
                node.values[index] = succ.value;
                const old_len = self.len;
                _ = self.deleteFromNode(node.children[index + 1].?, succ.key);
                self.len = old_len;
            } else {
                self.merge(node, index);
                const old_len = self.len;
                _ = self.deleteFromNode(node.children[index].?, key);
                self.len = old_len;
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

        /// Iterator for in-order traversal of the B-tree.
        ///
        /// The iterator visits keys in sorted order.
        pub const Iterator = struct {
            stack: std.ArrayList(StackFrame),
            allocator: std.mem.Allocator,

            const StackFrame = struct {
                node: *Node,
                index: u16,
            };

            pub const Entry = struct {
                key: K,
                value: V,
            };

            fn init(allocator: std.mem.Allocator, root: ?*Node) !Iterator {
                var stack = std.ArrayList(StackFrame){};

                if (root) |r| {
                    try stack.append(allocator, StackFrame{ .node = r, .index = 0 });
                    // Descend to leftmost leaf
                    var current = r;
                    while (!current.is_leaf) {
                        if (current.children[0]) |child| {
                            try stack.append(allocator, StackFrame{ .node = child, .index = 0 });
                            current = child;
                        } else break;
                    }
                }

                return Iterator{
                    .stack = stack,
                    .allocator = allocator,
                };
            }

            pub fn deinit(self: *Iterator) void {
                self.stack.deinit(self.allocator);
            }

            pub fn next(self: *Iterator) !?Entry {
                while (self.stack.items.len > 0) {
                    var frame = &self.stack.items[self.stack.items.len - 1];

                    if (frame.index < frame.node.len) {
                        const result = Entry{
                            .key = frame.node.keys[frame.index],
                            .value = frame.node.values[frame.index],
                        };

                        // Move to next position
                        if (!frame.node.is_leaf) {
                            // Go to right child of current key
                            if (frame.node.children[frame.index + 1]) |child| {
                                frame.index += 1;
                                try self.stack.append(self.allocator, StackFrame{ .node = child, .index = 0 });

                                // Descend to leftmost leaf
                                var current = child;
                                while (!current.is_leaf) {
                                    if (current.children[0]) |left_child| {
                                        try self.stack.append(self.allocator, StackFrame{ .node = left_child, .index = 0 });
                                        current = left_child;
                                    } else break;
                                }
                            } else {
                                frame.index += 1;
                            }
                        } else {
                            frame.index += 1;
                        }

                        return result;
                    } else {
                        _ = self.stack.pop();
                    }
                }

                return null;
            }
        };

        /// Returns an iterator over the map in sorted key order.
        ///
        /// Time complexity: O(1) for initialization
        ///
        /// ## Example
        /// ```zig
        /// var iter = try map.iterator();
        /// defer iter.deinit();
        /// while (try iter.next()) |entry| {
        ///     std.debug.print("{} => {}\n", .{entry.key, entry.value});
        /// }
        /// ```
        pub fn iterator(self: *const Self) !Iterator {
            return Iterator.init(self.allocator, self.root);
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
}

test "BTreeMap: iterator in-order traversal" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, []const u8, i32Compare, 4).init(allocator);
    defer map.deinit();

    // Insert in random order
    try map.put(30, "thirty");
    try map.put(10, "ten");
    try map.put(20, "twenty");
    try map.put(5, "five");
    try map.put(25, "twenty-five");
    try map.put(15, "fifteen");

    // Verify iterator returns items in sorted key order
    var iter = try map.iterator();
    defer iter.deinit();

    const expected_keys = [_]i32{ 5, 10, 15, 20, 25, 30 };
    const expected_values = [_][]const u8{ "five", "ten", "fifteen", "twenty", "twenty-five", "thirty" };

    var count: usize = 0;
    while (try iter.next()) |entry| {
        try std.testing.expect(count < expected_keys.len);
        try std.testing.expectEqual(expected_keys[count], entry.key);
        try std.testing.expectEqualStrings(expected_values[count], entry.value);
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 6), count);
}

test "BTreeMap: iterator on empty map" {
    const allocator = std.testing.allocator;
    var map = BTreeMap(i32, i32, i32Compare, 4).init(allocator);
    defer map.deinit();

    var iter = try map.iterator();
    defer iter.deinit();

    try std.testing.expect((try iter.next()) == null);
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
