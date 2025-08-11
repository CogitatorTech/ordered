const std = @import("std");
const ordered = @import("ordered");
const Timer = std.time.Timer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== RedBlackTree Benchmark ===\n\n", .{});

    const sizes = [_]usize{ 1000, 10_000, 100_000 };

    inline for (sizes) |size| {
        try benchmarkInsert(allocator, size);
        try benchmarkFind(allocator, size);
        try benchmarkRemove(allocator, size);
        try benchmarkIterator(allocator, size);
        std.debug.print("\n", .{});
    }
}

const Context = struct {
    pub fn lessThan(self: @This(), a: i32, b: i32) bool {
        _ = self;
        return a < b;
    }
};

fn benchmarkInsert(allocator: std.mem.Allocator, size: usize) !void {
    var tree = ordered.RedBlackTree(i32, Context).init(allocator, Context{});
    defer tree.deinit();

    var timer = try Timer.start();
    const start = timer.lap();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.insert(i);
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Insert {} items: {d:.2} ms ({d} ns/op)\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
    });
}

fn benchmarkFind(allocator: std.mem.Allocator, size: usize) !void {
    var tree = ordered.RedBlackTree(i32, Context).init(allocator, Context{});
    defer tree.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.insert(i);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    var found: usize = 0;
    while (i < size) : (i += 1) {
        if (tree.find(i) != null) found += 1;
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Find {} items: {d:.2} ms ({d} ns/op, found: {})\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
        found,
    });
}

fn benchmarkRemove(allocator: std.mem.Allocator, size: usize) !void {
    var tree = ordered.RedBlackTree(i32, Context).init(allocator, Context{});
    defer tree.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.insert(i);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    while (i < size) : (i += 1) {
        _ = tree.remove(i);
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Remove {} items: {d:.2} ms ({d} ns/op)\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
    });
}

fn benchmarkIterator(allocator: std.mem.Allocator, size: usize) !void {
    var tree = ordered.RedBlackTree(i32, Context).init(allocator, Context{});
    defer tree.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.insert(i);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    var iter = try tree.iterator();
    defer iter.deinit();

    var count: usize = 0;
    while (try iter.next()) |_| {
        count += 1;
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Iterator {} items: {d:.2} ms ({d} ns/op, count: {})\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
        count,
    });
}

