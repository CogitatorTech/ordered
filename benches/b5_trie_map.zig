const std = @import("std");
const ordered = @import("ordered");
const Timer = std.time.Timer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Trie Benchmark ===\n\n", .{});

    const sizes = [_]usize{ 1000, 10_000, 100_000, 1_000_000 };

    inline for (sizes) |size| {
        try benchmarkPut(allocator, size);
        try benchmarkGet(allocator, size);
        try benchmarkContains(allocator, size);
        try benchmarkPrefixSearch(allocator, size);
        std.debug.print("\n", .{});
    }
}

fn generateKey(allocator: std.mem.Allocator, i: usize) ![]u8 {
    return std.fmt.allocPrint(allocator, "key_{d:0>8}", .{i});
}

fn benchmarkPut(allocator: std.mem.Allocator, size: usize) !void {
    var trie = try ordered.TrieMap(i32).init(allocator);
    defer trie.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var timer = try Timer.start();
    const start = timer.lap();

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const key = try generateKey(arena_alloc, i);
        try trie.put(key, @intCast(i));
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
    var trie = try ordered.TrieMap(i32).init(allocator);
    defer trie.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const key = try generateKey(arena_alloc, i);
        try trie.put(key, @intCast(i));
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    var found: usize = 0;
    while (i < size) : (i += 1) {
        const key = try generateKey(arena_alloc, i);
        if (trie.get(key) != null) found += 1;
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

fn benchmarkContains(allocator: std.mem.Allocator, size: usize) !void {
    var trie = try ordered.TrieMap(i32).init(allocator);
    defer trie.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const key = try generateKey(arena_alloc, i);
        try trie.put(key, @intCast(i));
    }

    var timer = try Timer.start();
    const start = timer.lap();

    i = 0;
    var found: usize = 0;
    while (i < size) : (i += 1) {
        const key = try generateKey(arena_alloc, i);
        if (trie.contains(key)) found += 1;
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

fn benchmarkPrefixSearch(allocator: std.mem.Allocator, size: usize) !void {
    var trie = try ordered.TrieMap(i32).init(allocator);
    defer trie.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const key = try generateKey(arena_alloc, i);
        try trie.put(key, @intCast(i));
    }

    var timer = try Timer.start();
    const start = timer.lap();

    // Search for common prefixes
    const num_searches = @min(100, size / 10);
    var total_found: usize = 0;

    i = 0;
    while (i < num_searches) : (i += 1) {
        var iter = try trie.keysWithPrefix(allocator, "key_");
        defer iter.deinit();

        var count: usize = 0;
        while (try iter.next()) |_| {
            count += 1;
        }
        total_found += count;
    }

    const elapsed = timer.read() - start;
    const ns_per_op = elapsed / num_searches;

    std.debug.print("Prefix search {d} times (avg {d} matches): {d:.2} ms ({d} ns/op)\n", .{
        num_searches,
        total_found / num_searches,
        @as(f64, @floatFromInt(elapsed)) / 1_000_000.0,
        ns_per_op,
    });
}
