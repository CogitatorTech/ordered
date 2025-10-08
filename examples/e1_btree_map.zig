const std = @import("std");
const ordered = @import("ordered");

fn strCompare(lhs: []const u8, rhs: []const u8) std.math.Order {
    return std.mem.order(u8, lhs, rhs);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## BTreeMap Example ##\n", .{});
    const B = 4; // Branching Factor
    var map = ordered.BTreeMap([]const u8, u32, strCompare, B).init(allocator);
    defer map.deinit();

    try map.put("banana", 150);
    try map.put("apple", 100);
    try map.put("cherry", 200);

    const key_to_find = "apple";
    if (map.get(key_to_find)) |value_ptr| {
        std.debug.print("Found key '{s}': value is {d}\n", .{ key_to_find, value_ptr.* });
    }

    _ = map.remove("banana");
    std.debug.print("Contains 'banana' after delete? {any}\n\n", .{map.get("banana") != null});
}
