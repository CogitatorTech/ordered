const std = @import("std");
const ordered = @import("ordered");
const Timer = std.time.Timer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== SkipList Benchmark ===\n\n", .{});

    const sizes = [_]usize{ 1000, 10_000, 100_000, 1_000_000 };

    inline for (sizes) |size| {
        try benchmarkPut(allocator, size);
        try benchmarkGet(allocator, size);
        try benchmarkDelete(allocator, size);
        std.debug.print("\n", .{});
    }
}

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

fn benchmarkPut(allocator: std.mem.Allocator, size: usize) !void {
    var list = try ordered.SkipListMap(i32, i32, i32Compare, 16).init(allocator);
    defer list.deinit();

    var timer = try Timer.start();
    const start = timer.lap();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try list.put(i, i * 2);
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
    var list = try ordered.SkipListMap(i32, i32, i32Compare, 16).init(allocator);
    defer list.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try list.put(i, i * 2);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    var found: usize = 0;
    while (i < size) : (i += 1) {
        if (list.get(i) != null) found += 1;
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

fn benchmarkDelete(allocator: std.mem.Allocator, size: usize) !void {
    var list = try ordered.SkipListMap(i32, i32, i32Compare, 16).init(allocator);
    defer list.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        try list.put(i, i * 2);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    while (i < size) : (i += 1) {
        _ = list.remove(i);
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Delete {} items: {d:.2} ms ({d} ns/op)\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
    });
}
