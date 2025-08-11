//! A probabilistic data structure built in layers of linked lists.
//! SkipList offers O(log n) performance on average and is simpler to implement
//! correctly than balanced binary trees. It uses less memory per-node than B-Trees
//! and has excellent concurrent-friendly properties.

const std = @import("std");

pub fn SkipList(
    comptime K: type,
    comptime V: type,
    comptime compare: fn (lhs: K, rhs: K) std.math.Order,
    comptime MAX_LEVEL: u8,
) type {
    std.debug.assert(MAX_LEVEL > 0 and MAX_LEVEL <= 32);

    return struct {
        const Self = @This();
        const Node = struct {
            key: K,
            value: V,
            forward: []?*Node,

            fn init(allocator: std.mem.Allocator, key: K, value: V, level: u8) !*Node {
                const node = try allocator.create(Node);
                node.key = key;
                node.value = value;
                node.forward = try allocator.alloc(?*Node, level + 1);
                @memset(node.forward, null);
                return node;
            }

            fn deinit(self: *Node, allocator: std.mem.Allocator) void {
                allocator.free(self.forward);
                allocator.destroy(self);
            }
        };

        header: *Node,
        level: u8,
        len: usize,
        allocator: std.mem.Allocator,
        rng: std.Random.DefaultPrng,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const header = try allocator.create(Node);
            header.key = undefined;
            header.value = undefined;
            header.forward = try allocator.alloc(?*Node, MAX_LEVEL);
            @memset(header.forward, null);

            const rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));

            return Self{
                .header = header,
                .level = 0,
                .len = 0,
                .allocator = allocator,
                .rng = rng,
            };
        }

        pub fn deinit(self: *Self) void {
            var current = self.header.forward[0];
            while (current) |node| {
                const next = node.forward[0];
                node.deinit(self.allocator);
                current = next;
            }
            self.allocator.free(self.header.forward);
            self.allocator.destroy(self.header);
            self.* = undefined;
        }

        fn randomLevel(self: *Self) u8 {
            var level: u8 = 0;
            while (self.rng.random().boolean() and level < MAX_LEVEL - 1) {
                level += 1;
            }
            return level;
        }

        /// Retrieves a pointer to the value associated with `key`.
        pub fn get(self: *const Self, key: K) ?*const V {
            var current = self.header;
            var i = self.level;

            while (true) {
                while (current.forward[i] != null and
                    compare(current.forward[i].?.key, key) == .lt)
                {
                    current = current.forward[i].?;
                }

                if (i == 0) break;
                i -= 1;
            }

            current = current.forward[0] orelse return null;
            if (compare(current.key, key) == .eq) {
                return &current.value;
            }
            return null;
        }

        /// Retrieves a mutable pointer to the value associated with `key`.
        pub fn getPtr(self: *Self, key: K) ?*V {
            var current = self.header;
            var i = self.level;

            while (true) {
                while (current.forward[i] != null and
                    compare(current.forward[i].?.key, key) == .lt)
                {
                    current = current.forward[i].?;
                }

                if (i == 0) break;
                i -= 1;
            }

            current = current.forward[0] orelse return null;
            if (compare(current.key, key) == .eq) {
                return &current.value;
            }
            return null;
        }

        /// Inserts a key-value pair. If the key exists, the value is updated.
        pub fn put(self: *Self, key: K, value: V) !void {
            var update: [MAX_LEVEL]?*Node = undefined;
            var current = self.header;
            var i = self.level;

            // Find position to insert
            while (true) {
                while (current.forward[i] != null and
                    compare(current.forward[i].?.key, key) == .lt)
                {
                    current = current.forward[i].?;
                }
                update[i] = current;

                if (i == 0) break;
                i -= 1;
            }

            // Check if key exists in the next node
            const next_node = current.forward[0];
            if (next_node != null and compare(next_node.?.key, key) == .eq) {
                next_node.?.value = value;
                return;
            }

            // Create new node
            const new_level = self.randomLevel();
            const new_node = try Node.init(self.allocator, key, value, new_level);

            // Update header forward pointers if new level is higher
            if (new_level > self.level) {
                for (self.level + 1..new_level + 1) |level| {
                    update[level] = self.header;
                }
                self.level = new_level;
            }

            // Insert node
            for (0..new_level + 1) |level| {
                new_node.forward[level] = update[level].?.forward[level];
                update[level].?.forward[level] = new_node;
            }

            self.len += 1;
        }

        /// Removes a key-value pair and returns the value if it existed.
        pub fn delete(self: *Self, key: K) ?V {
            var update: [MAX_LEVEL]?*Node = undefined;
            var current = self.header;
            var i = self.level;

            // Find position to delete
            while (true) {
                while (current.forward[i] != null and
                    compare(current.forward[i].?.key, key) == .lt)
                {
                    current = current.forward[i].?;
                }
                update[i] = current;

                if (i == 0) break;
                i -= 1;
            }

            // Check if key exists in the next node
            const next_node = current.forward[0];
            if (next_node == null or compare(next_node.?.key, key) != .eq) {
                return null;
            }

            const deleted_value = next_node.?.value;

            // Remove node from all levels
            for (0..self.level + 1) |level| {
                if (update[level].?.forward[level] != next_node) break;
                update[level].?.forward[level] = next_node.?.forward[level];
            }

            next_node.?.deinit(self.allocator);

            // Update level if necessary
            while (self.level > 0 and self.header.forward[self.level] == null) {
                self.level -= 1;
            }

            self.len -= 1;
            return deleted_value;
        }

        /// Returns true if the skip list contains the given key.
        pub fn contains(self: *const Self, key: K) bool {
            return self.get(key) != null;
        }

        /// Iterator for traversing the skip list in sorted order.
        pub const Iterator = struct {
            current: ?*Node,

            pub fn next(self: *Iterator) ?struct { key: K, value: V } {
                const node = self.current orelse return null;
                self.current = node.forward[0];
                return .{ .key = node.key, .value = node.value };
            }
        };

        /// Returns an iterator over the skip list.
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{ .current = self.header.forward[0] };
        }
    };
}

fn strCompare(lhs: []const u8, rhs: []const u8) std.math.Order {
    return std.mem.order(u8, lhs, rhs);
}

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

test "SkipList: basic operations" {
    const allocator = std.testing.allocator;
    var list = try SkipList(i32, []const u8, i32Compare, 16).init(allocator);
    defer list.deinit();

    // Test put and get
    try list.put(10, "ten");
    try list.put(20, "twenty");
    try list.put(5, "five");
    try list.put(15, "fifteen");

    try std.testing.expectEqual(@as(usize, 4), list.len);
    try std.testing.expectEqualStrings("ten", list.get(10).?.*);
    try std.testing.expectEqualStrings("five", list.get(5).?.*);
    try std.testing.expect(list.get(99) == null);

    // Test update
    try list.put(10, "updated_ten");
    try std.testing.expectEqualStrings("updated_ten", list.get(10).?.*);
    try std.testing.expectEqual(@as(usize, 4), list.len);

    // Test delete
    const deleted = list.delete(20);
    try std.testing.expectEqualStrings("twenty", deleted.?);
    try std.testing.expect(list.get(20) == null);
    try std.testing.expectEqual(@as(usize, 3), list.len);

    // Test contains
    try std.testing.expect(list.contains(10));
    try std.testing.expect(!list.contains(20));
}

test "SkipList: iteration order" {
    const allocator = std.testing.allocator;
    var list = try SkipList(i32, i32, i32Compare, 16).init(allocator);
    defer list.deinit();

    // Insert in random order
    const keys = [_]i32{ 30, 10, 20, 5, 25, 15 };
    for (keys) |key| {
        try list.put(key, key * 2);
    }

    // Verify sorted iteration
    var iter = list.iterator();
    const expected_keys = [_]i32{ 5, 10, 15, 20, 25, 30 };
    var index: usize = 0;

    while (iter.next()) |entry| {
        try std.testing.expect(index < expected_keys.len);
        try std.testing.expectEqual(expected_keys[index], entry.key);
        try std.testing.expectEqual(expected_keys[index] * 2, entry.value);
        index += 1;
    }

    // Ensure we iterated through all expected items
    try std.testing.expectEqual(expected_keys.len, index);
}

test "SkipList: string keys" {
    const allocator = std.testing.allocator;
    var list = try SkipList([]const u8, i32, strCompare, 16).init(allocator);
    defer list.deinit();

    try list.put("banana", 2);
    try list.put("apple", 1);
    try list.put("cherry", 3);

    try std.testing.expectEqual(@as(i32, 1), list.get("apple").?.*);
    try std.testing.expectEqual(@as(i32, 2), list.get("banana").?.*);
    try std.testing.expectEqual(@as(i32, 3), list.get("cherry").?.*);

    // Test iteration maintains lexicographic order
    var iter = list.iterator();
    const first = iter.next().?;
    try std.testing.expectEqualStrings("apple", first.key);
    const second = iter.next().?;
    try std.testing.expectEqualStrings("banana", second.key);
    const third = iter.next().?;
    try std.testing.expectEqualStrings("cherry", third.key);
    try std.testing.expect(iter.next() == null);
}
