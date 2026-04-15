const std = @import("std");
const ordered = @import("ordered");

// Comparison function for the keys. Returns a `std.math.Order` — the same
// three-way shape used by every other generic-key container in the library.
fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## RedBlackTreeSet Example (as a Set) ##\n", .{});
    var rbt = ordered.RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer rbt.deinit();

    try rbt.put(40);
    try rbt.put(20);
    try rbt.put(60);
    try rbt.put(10);
    try rbt.put(30);

    // Update is handled by put
    try rbt.put(30);

    std.debug.print("RBT count: {d}\n", .{rbt.count()});
    std.debug.print("RBT contains 20? {any}\n", .{rbt.contains(20)});
    std.debug.print("RBT contains 99? {any}\n", .{rbt.contains(99)});

    const removed = rbt.remove(60);
    if (removed) |val| {
        std.debug.print("Removed value: {d}\n", .{val});
    }

    std.debug.print("RBT count after remove: {d}\n\n", .{rbt.count()});
}
