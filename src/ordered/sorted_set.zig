//! A set that keeps its elements sorted at all times.
//! Inserts are O(n) because elements may need to be shifted, but searching
//! is O(log n) via binary search. It is cache-friendly for traversals.

const std = @import("std");

pub fn SortedSet(
    comptime T: type,
    comptime compare: fn (lhs: T, rhs: T) std.math.Order,
) type {
    return struct {
        const Self = @This();

        items: std.ArrayList(T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        fn compareFn(key: T, item: T) std.math.Order {
            return compare(key, item);
        }

        /// Adds a value to the vector, maintaining sort order.
        pub fn add(self: *Self, value: T) !void {
            const index = std.sort.lowerBound(T, self.items.items, value, compareFn);
            try self.items.insert(self.allocator, index, value);
        }

        /// Removes an element at a given index.
        pub fn remove(self: *Self, index: usize) T {
            return self.items.orderedRemove(index);
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

    try vec.add(100);
    try vec.add(50);
    try vec.add(75);

    try std.testing.expectEqualSlices(i32, &.{ 50, 75, 100 }, vec.items.items);
    try std.testing.expect(vec.contains(75));
    try std.testing.expect(!vec.contains(99));
    try std.testing.expectEqual(@as(?usize, 1), vec.findIndex(75));

    _ = vec.remove(1); // Remove 75
    try std.testing.expectEqualSlices(i32, &.{ 50, 100 }, vec.items.items);
}
