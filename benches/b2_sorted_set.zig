const std = @import("std");
const ordered = @import("ordered");
const Timer = std.time.Timer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== SortedSet Benchmark ===\n\n", .{});

    const sizes = [_]usize{ 1000, 10_000, 100_000, 1_000_000 };

    inline for (sizes) |size| {
        try benchmarkAdd(allocator, size);
        try benchmarkContains(allocator, size);
        try benchmarkRemove(allocator, size);
        std.debug.print("\n", .{});
    }
}

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

fn benchmarkAdd(allocator: std.mem.Allocator, size: usize) !void {
    var set = ordered.SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    var timer = try Timer.start();
    const start = timer.lap();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        _ = try set.put(i);
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Add {} items: {d:.2} ms ({d} ns/op)\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
    });
}

fn benchmarkContains(allocator: std.mem.Allocator, size: usize) !void {
    var set = ordered.SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        _ = try set.put(i);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    var found: usize = 0;
    while (i < size) : (i += 1) {
        if (set.contains(i)) found += 1;
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Contains {} items: {d:.2} ms ({d} ns/op, found: {})\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
        found,
    });
}

fn benchmarkRemove(allocator: std.mem.Allocator, size: usize) !void {
    var set = ordered.SortedSet(i32, i32Compare).init(allocator);
    defer set.deinit();

    var i: i32 = 0;
    while (i < size) : (i += 1) {
        _ = try set.put(i);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    while (set.items.items.len > 0) {
        _ = set.remove(0);
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / size;

    std.debug.print("Remove {} items: {d:.2} ms ({d} ns/op)\n", .{
        size,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
    });
}
