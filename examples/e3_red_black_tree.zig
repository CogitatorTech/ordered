const std = @import("std");
const ordered = @import("ordered");

// Context object for comparison, required by RedBlackTree
const I32Context = struct {
    // This function must be public to be visible from the library code.
    pub fn lessThan(_: @This(), a: i32, b: i32) bool {
        return a < b;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## RedBlackTree Example (as a Set) ##\n", .{});
    var rbt = ordered.RedBlackTree(i32, I32Context).init(allocator, .{});
    defer rbt.deinit();

    try rbt.insert(40);
    try rbt.insert(20);
    try rbt.insert(60);
    try rbt.insert(10);
    try rbt.insert(30);

    // Update is handled by insert
    try rbt.insert(30);

    std.debug.print("RBT count: {d}\n", .{rbt.count()});
    std.debug.print("RBT contains 20? {any}\n", .{rbt.contains(20)});
    std.debug.print("RBT contains 99? {any}\n", .{rbt.contains(99)});

    if (rbt.remove(60)) {
        std.debug.print("Removed 60\n", .{});
    }

    std.debug.print("RBT count after remove: {d}\n\n", .{rbt.count()});
}
