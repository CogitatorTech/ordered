const std = @import("std");
const ordered = @import("ordered");

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## SortedSet Example ##\n", .{});
    var sorted_set = ordered.SortedSet(i32, i32Compare).init(allocator);
    defer sorted_set.deinit();

    try sorted_set.add(100);
    try sorted_set.add(25);
    try sorted_set.add(50);

    std.debug.print("SortedSet contents: {any}\n\n", .{sorted_set.items.items});
}
