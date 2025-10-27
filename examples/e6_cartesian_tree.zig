const std = @import("std");
const ordered = @import("ordered");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## Cartesian Tree Example ##\n", .{});
    var cartesian_tree = ordered.CartesianTree(i32, []const u8).init(allocator);
    defer cartesian_tree.deinit();

    try cartesian_tree.put(50, "fifty");
    try cartesian_tree.put(30, "thirty");
    try cartesian_tree.put(70, "seventy");

    std.debug.print("Cartesian tree size: {d}\n", .{cartesian_tree.count()});

    const search_key = 30;
    if (cartesian_tree.get(search_key)) |value| {
        std.debug.print("Found key {d}: value is '{s}'\n", .{ search_key, value });
    }

    const removed = cartesian_tree.remove(30);
    if (removed) |value| {
        std.debug.print("Removed key {d} with value: '{s}'\n", .{ search_key, value });
    }

    std.debug.print("Size after deletion: {d}\n", .{cartesian_tree.count()});
    std.debug.print("Contains {d}? {any}\n\n", .{ search_key, cartesian_tree.contains(search_key) });
}
