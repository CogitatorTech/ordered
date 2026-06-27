//! Naive, obviously-correct reference containers used as differential-testing
//! oracles for the library's sets and maps.
//!
//! Each oracle keeps its elements in a sorted, duplicate-free `std.ArrayList`
//! via linear scan. The implementations are small enough to audit by
//! inspection, so when a real container and its oracle agree across a long
//! random sequence of operations (count, membership, value, removal success,
//! and in-order iteration), that agreement is strong evidence the container is
//! correct. This module is internal and used only by the inline `test` blocks
//! in the container modules; it is not part of the public API.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

/// A naive sorted, duplicate-free set model parameterised by element type and
/// the same three-way comparison function the container under test uses.
pub fn SetOracle(comptime T: type, comptime compare: fn (lhs: T, rhs: T) Order) type {
    return struct {
        const Self = @This();

        items: std.ArrayList(T) = .empty,

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.items.deinit(allocator);
        }

        pub fn contains(self: *const Self, value: T) bool {
            for (self.items.items) |v| {
                if (compare(v, value) == .eq) return true;
            }
            return false;
        }

        /// Inserts `value`, keeping the list sorted. A value that is already
        /// present leaves the set structurally unchanged.
        pub fn put(self: *Self, allocator: Allocator, value: T) !void {
            var i: usize = 0;
            while (i < self.items.items.len and compare(self.items.items[i], value) == .lt) : (i += 1) {}
            if (i < self.items.items.len and compare(self.items.items[i], value) == .eq) return;
            try self.items.insert(allocator, i, value);
        }

        /// Removes `value` if present, returning whether it existed.
        pub fn remove(self: *Self, value: T) bool {
            for (self.items.items, 0..) |v, i| {
                if (compare(v, value) == .eq) {
                    _ = self.items.orderedRemove(i);
                    return true;
                }
            }
            return false;
        }

        pub fn count(self: *const Self) usize {
            return self.items.items.len;
        }
    };
}

/// A naive sorted, duplicate-free key-value map model parameterised by key
/// type, value type, and the container's key-comparison function.
pub fn MapOracle(
    comptime K: type,
    comptime V: type,
    comptime compare: fn (lhs: K, rhs: K) Order,
) type {
    return struct {
        const Self = @This();

        pub const Entry = struct { key: K, value: V };

        entries: std.ArrayList(Entry) = .empty,

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.entries.deinit(allocator);
        }

        fn find(self: *const Self, key: K) ?usize {
            for (self.entries.items, 0..) |e, i| {
                if (compare(e.key, key) == .eq) return i;
            }
            return null;
        }

        pub fn contains(self: *const Self, key: K) bool {
            return self.find(key) != null;
        }

        pub fn get(self: *const Self, key: K) ?V {
            if (self.find(key)) |i| return self.entries.items[i].value;
            return null;
        }

        /// Inserts the pair, keeping keys sorted. An existing key has its value
        /// updated in place, mirroring the containers' upsert semantics.
        pub fn put(self: *Self, allocator: Allocator, key: K, value: V) !void {
            var i: usize = 0;
            while (i < self.entries.items.len and compare(self.entries.items[i].key, key) == .lt) : (i += 1) {}
            if (i < self.entries.items.len and compare(self.entries.items[i].key, key) == .eq) {
                self.entries.items[i].value = value;
                return;
            }
            try self.entries.insert(allocator, i, .{ .key = key, .value = value });
        }

        /// Removes `key` if present, returning its value.
        pub fn remove(self: *Self, key: K) ?V {
            for (self.entries.items, 0..) |e, i| {
                if (compare(e.key, key) == .eq) {
                    _ = self.entries.orderedRemove(i);
                    return e.value;
                }
            }
            return null;
        }

        pub fn count(self: *const Self) usize {
            return self.entries.items.len;
        }
    };
}
