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

    _ = try sorted_set.put(100);
    _ = try sorted_set.put(25);
    _ = try sorted_set.put(50);
    const duplicate = try sorted_set.put(50); // Try adding duplicate

    std.debug.print("SortedSet count: {d}\n", .{sorted_set.count()});
    std.debug.print("Added duplicate 50? {any}\n", .{duplicate});
    std.debug.print("SortedSet contents: {any}\n", .{sorted_set.items.items});
    std.debug.print("Contains 100? {any}\n\n", .{sorted_set.contains(100)});
}
