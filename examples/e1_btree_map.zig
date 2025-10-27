const std = @import("std");
const ordered = @import("ordered");

fn strCompare(lhs: []const u8, rhs: []const u8) std.math.Order {
    return std.mem.order(u8, lhs, rhs);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## BTreeMap Example ##\n", .{});
    const B = 4; // Branching Factor for B-tree
    var map = ordered.BTreeMap([]const u8, u32, strCompare, B).init(allocator);
    defer map.deinit();

    try map.put("banana", 150);
    try map.put("apple", 100);
    try map.put("cherry", 200);

    const key_to_find = "apple";
    if (map.get(key_to_find)) |value_ptr| {
        std.debug.print("Found key '{s}': value is {d}\n", .{ key_to_find, value_ptr.* });
    }

    const removed = map.remove("banana");
    std.debug.print("Removed 'banana' with value: {?d}\n", .{if (removed) |v| v else null});
    std.debug.print("Contains 'banana' after remove? {any}\n", .{map.contains("banana")});
    std.debug.print("Map count: {d}\n\n", .{map.count()});
}
