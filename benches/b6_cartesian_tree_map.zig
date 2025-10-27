const std = @import("std");
const ordered = @import("ordered");
const Timer = std.time.Timer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== CartesianTree Benchmark ===\n\n", .{});

    const sizes = [_]usize{ 1000, 10_000, 100_000, 1_000_000 };

    inline for (sizes) |size| {
        try benchmarkPut(allocator, size);
        try benchmarkGet(allocator, size);
        try benchmarkRemove(allocator, size);
        try benchmarkIterator(allocator, size);
        std.debug.print("\n", .{});
    }
}

fn benchmarkPut(allocator: std.mem.Allocator, size: usize) !void {
    var tree = ordered.CartesianTreeMap(i32, i32).init(allocator);
    defer tree.deinit();

    var timer = try Timer.start();
    const start = timer.lap();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.put(i, i * 2);
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Put {} items: {d:.2} ms ({d} ns/op)\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
    });
}

fn benchmarkGet(allocator: std.mem.Allocator, size: usize) !void {
    var tree = ordered.CartesianTreeMap(i32, i32).init(allocator);
    defer tree.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.put(i, i * 2);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    var found: usize = 0;
    while (i < size) : (i += 1) {
        if (tree.get(i)) |_| found += 1;
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Get {} items: {d:.2} ms ({d} ns/op, found: {})\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
        found,
    });
}

fn benchmarkRemove(allocator: std.mem.Allocator, size: usize) !void {
    var tree = ordered.CartesianTreeMap(i32, i32).init(allocator);
    defer tree.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.put(i, i * 2);
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
    var tree = ordered.CartesianTreeMap(i32, i32).init(allocator);
    defer tree.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try tree.put(i, i * 2);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    var iter = try tree.iterator(allocator);
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
