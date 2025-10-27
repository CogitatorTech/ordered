const std = @import("std");
const ordered = @import("ordered");

fn strCompare(lhs: []const u8, rhs: []const u8) std.math.Order {
    return std.mem.order(u8, lhs, rhs);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## SkipListMap Example ##\n", .{});
    var skip_list = try ordered.SkipListMap([]const u8, u32, strCompare, 16).init(allocator);
    defer skip_list.deinit();

    try skip_list.put("zebra", 300);
    try skip_list.put("apple", 100);
    try skip_list.put("mango", 250);
    try skip_list.put("banana", 150);

    std.debug.print("SkipListMap count: {d}\n", .{skip_list.count()});

    if (skip_list.get("mango")) |value_ptr| {
        std.debug.print("Found 'mango': value is {d}\n", .{value_ptr.*});
    }

    std.debug.print("Iterating in sorted order:\n", .{});
    var iter = skip_list.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s}: {d}\n", .{ entry.key, entry.value });
    }

    const removed = skip_list.remove("apple");
    std.debug.print("Removed 'apple' with value: {?d}\n", .{removed});
    std.debug.print("Contains 'apple' after remove? {any}\n\n", .{skip_list.contains("apple")});
}
