//! A set that keeps its elements sorted at all times.
//! Inserts are O(n) because elements may need to be shifted, but searching
//! is O(log n) via binary search. It is cache-friendly for traversals.
//!
//! ## Thread Safety
//! This data structure is not thread-safe. External synchronization is required
//! for concurrent access.
//!
//! ## Iterator Invalidation
//! WARNING: Modifying the set (via put, remove, or clear) while iterating will
//! cause undefined behavior. Complete all iterations before modifying the structure.

const std = @import("std");

pub fn SortedSet(
    comptime T: type,
    comptime compare: fn (lhs: T, rhs: T) std.math.Order,
) type {
    return struct {
        const Self = @This();

        items: std.ArrayList(T),
        allocator: std.mem.Allocator,

        /// Returns the number of elements in the set.
        pub fn count(self: *const Self) usize {
            return self.items.items.len;
        }

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        /// Removes all elements from the set.
        pub fn clear(self: *Self) void {
            self.items.clearRetainingCapacity();
        }

        fn compareFn(key: T, item: T) std.math.Order {
            return compare(key, item);
        }

        /// Adds a value to the set, maintaining sort order.
        /// Returns true if the value was added, false if it already existed.
        pub fn put(self: *Self, value: T) !bool {
            const index = std.sort.lowerBound(T, self.items.items, value, compareFn);
            // Check if value already exists
            if (index < self.items.items.len and compare(self.items.items[index], value) == .eq) {
                return false;
            }
            try self.items.insert(self.allocator, index, value);
            return true;
        }

        /// Removes an element at a given index.
        pub fn remove(self: *Self, index: usize) T {
            return self.items.orderedRemove(index);
        }

        /// Removes a value from the set and returns it if it existed.
        /// Returns null if the value was not found.
        pub fn removeValue(self: *Self, value: T) ?T {
            const index = self.findIndex(value) orelse return null;
            return self.remove(index);
        }

        /// Returns true if the set contains the given value.
        pub fn contains(self: *Self, value: T) bool {
            return self.findIndex(value) != null;
        }

        /// Finds the index of a value. Returns null if not found.
        pub fn findIndex(self: *Self, value: T) ?usize {
            return std.sort.binarySearch(T, self.items.items, value, compareFn);
        }

        /// Iterator for traversing the set in sorted order.
        pub const Iterator = struct {
            items: []const T,
            index: usize = 0,

            pub fn next(self: *Iterator) ?T {
                if (self.index >= self.items.len) return null;
                const value = self.items[self.index];
                self.index += 1;
                return value;
            }
        };

        /// Returns an iterator over the set in sorted order.
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{ .items = self.items.items };
        }
    };
}

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

test "SortedSet basic functionality" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    _ = try set.put(100);
    _ = try set.put(50);
    _ = try set.put(75);

    try std.testing.expectEqualSlices(i32, &.{ 50, 75, 100 }, set.items.items);
    try std.testing.expect(set.contains(75));
    try std.testing.expect(!set.contains(99));
    try std.testing.expectEqual(@as(?usize, 1), set.findIndex(75));

    _ = set.remove(1); // Remove 75
    try std.testing.expectEqualSlices(i32, &.{ 50, 100 }, set.items.items);
}

test "SortedSet: empty set operations" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    try std.testing.expect(!set.contains(42));
    try std.testing.expectEqual(@as(?usize, null), set.findIndex(42));
    try std.testing.expectEqual(@as(usize, 0), set.items.items.len);
}

test "SortedSet: single element" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    _ = try set.put(42);
    try std.testing.expect(set.contains(42));
    try std.testing.expectEqual(@as(usize, 1), set.items.items.len);

    const removed = set.remove(0);
    try std.testing.expectEqual(@as(i32, 42), removed);
    try std.testing.expectEqual(@as(usize, 0), set.items.items.len);
}

test "SortedSet: duplicate values rejected" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    const added1 = try set.put(10);
    const added2 = try set.put(10);
    const added3 = try set.put(10);

    // Duplicates should be rejected in a proper Set
    try std.testing.expect(added1);
    try std.testing.expect(!added2);
    try std.testing.expect(!added3);
    try std.testing.expectEqual(@as(usize, 1), set.items.items.len);
}

test "SortedSet: negative numbers" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    _ = try set.put(-5);
    _ = try set.put(-10);
    _ = try set.put(0);
    _ = try set.put(5);

    try std.testing.expectEqualSlices(i32, &.{ -10, -5, 0, 5 }, set.items.items);
}

test "SortedSet: large dataset" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    // Insert in reverse order
    var i: i32 = 100;
    while (i >= 0) : (i -= 1) {
        _ = try set.put(i);
    }

    // Verify sorted
    try std.testing.expectEqual(@as(usize, 101), set.items.items.len);
    for (set.items.items, 0..) |val, idx| {
        try std.testing.expectEqual(@as(i32, @intCast(idx)), val);
    }
}

test "SortedSet: remove boundary cases" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    _ = try set.put(1);
    _ = try set.put(2);
    _ = try set.put(3);
    _ = try set.put(4);
    _ = try set.put(5);

    // Remove first
    _ = set.remove(0);
    try std.testing.expectEqualSlices(i32, &.{ 2, 3, 4, 5 }, set.items.items);

    // Remove last
    _ = set.remove(3);
    try std.testing.expectEqualSlices(i32, &.{ 2, 3, 4 }, set.items.items);

    // Remove middle
    _ = set.remove(1);
    try std.testing.expectEqualSlices(i32, &.{ 2, 4 }, set.items.items);
}

test "SortedSet: removeValue method" {
    const allocator = std.testing.allocator;
    var set = SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    _ = try set.put(10);
    _ = try set.put(20);
    _ = try set.put(30);
    _ = try set.put(40);

    // Remove existing value
    const removed = set.removeValue(20);
    try std.testing.expectEqual(@as(i32, 20), removed.?);
    try std.testing.expectEqual(@as(usize, 3), set.items.items.len);
    try std.testing.expect(!set.contains(20));

    // Try to remove non-existent value
    const not_found = set.removeValue(99);
    try std.testing.expect(not_found == null);
    try std.testing.expectEqual(@as(usize, 3), set.items.items.len);
}
