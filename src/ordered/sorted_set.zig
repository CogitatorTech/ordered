//! A set that keeps its elements sorted at all times.
//! Inserts are O(n) because elements may need to be shifted, but searching
//! is O(log n) via binary search. It is cache-friendly for traversals.
//!
//! ## Thread Safety
//! This data structure is not thread-safe. External synchronization is required
//! for concurrent access.
//!
//! ## Iterator Invalidation
//! WARNING: Modifying the set (via add/remove/clear) while iterating over
//! `.items.items` will cause undefined behavior. Complete all iterations before
//! modifying the structure.

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
                .items = std.ArrayList(T){},
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

        /// Returns true if the vector contains the given value.
        pub fn contains(self: *Self, value: T) bool {
            return self.findIndex(value) != null;
        }

        /// Finds the index of a value. Returns null if not found.
        pub fn findIndex(self: *Self, value: T) ?usize {
            return std.sort.binarySearch(T, self.items.items, value, compareFn);
        }
    };
}

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

test "SortedSet basic functionality" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    _ = try vec.put(100);
    _ = try vec.put(50);
    _ = try vec.put(75);

    try std.testing.expectEqualSlices(i32, &.{ 50, 75, 100 }, vec.items.items);
    try std.testing.expect(vec.contains(75));
    try std.testing.expect(!vec.contains(99));
    try std.testing.expectEqual(@as(?usize, 1), vec.findIndex(75));

    _ = vec.remove(1); // Remove 75
    try std.testing.expectEqualSlices(i32, &.{ 50, 100 }, vec.items.items);
}

test "SortedSet: empty set operations" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    try std.testing.expect(!vec.contains(42));
    try std.testing.expectEqual(@as(?usize, null), vec.findIndex(42));
    try std.testing.expectEqual(@as(usize, 0), vec.items.items.len);
}

test "SortedSet: single element" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    _ = try vec.put(42);
    try std.testing.expect(vec.contains(42));
    try std.testing.expectEqual(@as(usize, 1), vec.items.items.len);

    const removed = vec.remove(0);
    try std.testing.expectEqual(@as(i32, 42), removed);
    try std.testing.expectEqual(@as(usize, 0), vec.items.items.len);
}

test "SortedSet: duplicate values rejected" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    const added1 = try vec.put(10);
    const added2 = try vec.put(10);
    const added3 = try vec.put(10);

    // Duplicates should be rejected in a proper Set
    try std.testing.expect(added1);
    try std.testing.expect(!added2);
    try std.testing.expect(!added3);
    try std.testing.expectEqual(@as(usize, 1), vec.items.items.len);
}

test "SortedSet: negative numbers" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    _ = try vec.put(-5);
    _ = try vec.put(-10);
    _ = try vec.put(0);
    _ = try vec.put(5);

    try std.testing.expectEqualSlices(i32, &.{ -10, -5, 0, 5 }, vec.items.items);
}

test "SortedSet: large dataset" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    // Insert in reverse order
    var i: i32 = 100;
    while (i >= 0) : (i -= 1) {
        _ = try vec.put(i);
    }

    // Verify sorted
    try std.testing.expectEqual(@as(usize, 101), vec.items.items.len);
    for (vec.items.items, 0..) |val, idx| {
        try std.testing.expectEqual(@as(i32, @intCast(idx)), val);
    }
}

test "SortedSet: remove boundary cases" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    _ = try vec.put(1);
    _ = try vec.put(2);
    _ = try vec.put(3);
    _ = try vec.put(4);
    _ = try vec.put(5);

    // Remove first
    _ = vec.remove(0);
    try std.testing.expectEqualSlices(i32, &.{ 2, 3, 4, 5 }, vec.items.items);

    // Remove last
    _ = vec.remove(3);
    try std.testing.expectEqualSlices(i32, &.{ 2, 3, 4 }, vec.items.items);

    // Remove middle
    _ = vec.remove(1);
    try std.testing.expectEqualSlices(i32, &.{ 2, 4 }, vec.items.items);
}

test "SortedSet: removeValue method" {
    const allocator = std.testing.allocator;
    var vec = SortedSet(i32, i32Compare).init(allocator);
    defer vec.deinit();

    _ = try vec.put(10);
    _ = try vec.put(20);
    _ = try vec.put(30);
    _ = try vec.put(40);

    // Remove existing value
    const removed = vec.removeValue(20);
    try std.testing.expectEqual(@as(i32, 20), removed.?);
    try std.testing.expectEqual(@as(usize, 3), vec.items.items.len);
    try std.testing.expect(!vec.contains(20));

    // Try to remove non-existent value
    const not_found = vec.removeValue(99);
    try std.testing.expect(not_found == null);
    try std.testing.expectEqual(@as(usize, 3), vec.items.items.len);
}
