const std = @import("std");
const ordered = @import("ordered");
const Timer = @import("util/timer.zig").Timer;

const BTree = ordered.BTreeMap(u32, u32, compare, 16);
const CartesianTree = ordered.CartesianTreeMap(u32, u32, compare);
const SkipList = ordered.SkipListMap(u32, u32, compare, 16);
const HashMap = std.AutoHashMap(u32, u32);
const MAPS = .{ BTree, CartesianTree, SkipList, TreapMap, HashMap };
const NAMES = .{ "BTreeMap", "CartesianTreeMap", "SkipListMap", "std.Treap", "std.AutoHashMap (unordered)" };
const REPEATS = 5;

fn compare(lhs: u32, rhs: u32) std.math.Order {
    return std.math.order(lhs, rhs);
}

// std.Treap is intrusive, so include node allocation and value storage in its cost.
const TreapMap = struct {
    const Tree = std.Treap(u32, std.math.order);
    const Node = struct { tree_node: Tree.Node, value: u32 };

    allocator: std.mem.Allocator,
    tree: Tree = .{},
    len: usize = 0,

    fn init(allocator: std.mem.Allocator) TreapMap {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *TreapMap) void {
        while (self.tree.getMin()) |node| _ = self.remove(node.key);
    }

    fn count(self: *const TreapMap) usize {
        return self.len;
    }

    fn put(self: *TreapMap, key: u32, value: u32) !void {
        var entry = self.tree.getEntryFor(key);
        if (entry.node) |node| {
            const parent: *Node = @fieldParentPtr("tree_node", node);
            parent.value = value;
        } else {
            const node = try self.allocator.create(Node);
            node.value = value;
            entry.set(&node.tree_node);
            self.len += 1;
        }
    }

    fn get(self: *TreapMap, key: u32) ?u32 {
        const node = self.tree.getEntryFor(key).node orelse return null;
        const parent: *Node = @fieldParentPtr("tree_node", node);
        return parent.value;
    }

    fn remove(self: *TreapMap, key: u32) ?u32 {
        var entry = self.tree.getEntryFor(key);
        const node = entry.node orelse return null;
        const parent: *Node = @fieldParentPtr("tree_node", node);
        const value = parent.value;
        entry.set(null);
        self.allocator.destroy(parent);
        self.len -= 1;
        return value;
    }
};

fn initMap(comptime Map: type, allocator: std.mem.Allocator) !Map {
    if (Map == SkipList) return try Map.init(allocator);
    return Map.init(allocator);
}

fn getValue(comptime Map: type, map: *Map, key: u32) ?u32 {
    if (Map == BTree or Map == SkipList) {
        return if (map.get(key)) |value| value.* else null;
    }
    return map.get(key);
}

fn iterationSum(comptime Map: type, map: *Map, allocator: std.mem.Allocator) !u64 {
    var sum: u64 = 0;
    if (Map == TreapMap) {
        var it = map.tree.inorderIterator();
        while (it.next()) |node| {
            const parent: *TreapMap.Node = @fieldParentPtr("tree_node", node);
            sum += parent.value;
        }
    } else if (Map == HashMap) {
        var it = map.iterator();
        while (it.next()) |entry| sum += entry.value_ptr.*;
    } else if (Map == SkipList) {
        var it = map.iterator();
        while (it.next()) |entry| sum += entry.value;
    } else {
        var it = if (Map == CartesianTree) try map.iterator(allocator) else try map.iterator();
        defer it.deinit();
        while (try it.next()) |entry| sum += entry.value;
    }
    return sum;
}

fn check(ok: bool) !void {
    if (!ok) return error.BenchmarkMismatch;
}

fn selfCheck(comptime Map: type, allocator: std.mem.Allocator) !void {
    var map = try initMap(Map, allocator);
    defer map.deinit();
    try check(map.count() == 0 and getValue(Map, &map, 7) == null);
    try map.put(7, 10);
    try map.put(7, 20);
    try check(map.count() == 1 and getValue(Map, &map, 7) == 20);
    try check(try iterationSum(Map, &map, allocator) == 20);
    if (Map == HashMap) {
        try check(map.remove(7));
        try check(!map.remove(7));
    } else {
        try check(map.remove(7) == 20);
        try check(map.remove(7) == null);
    }
    try check(map.count() == 0);
    try check(try iterationSum(Map, &map, allocator) == 0);
    // Leave a live node to exercise cleanup as well as removal.
    try map.put(9, 30);
}

fn measure(comptime Map: type, allocator: std.mem.Allocator, keys: []const u32) ![5]u64 {
    var map = try initMap(Map, allocator);
    defer map.deinit();
    var times: [5]u64 = undefined;
    var timer = try Timer.start();
    for (keys) |key| try map.put(key, key + 1);
    times[0] = timer.read();
    try check(map.count() == keys.len);

    const expected = @as(u64, keys.len) * (keys.len + 1) / 2;
    var sum: u64 = 0;
    _ = timer.lap();
    for (keys) |key| sum += getValue(Map, &map, key) orelse 0;
    times[1] = timer.read();
    try check(sum == expected);

    var found: usize = 0;
    _ = timer.lap();
    for (keys) |key| {
        if (getValue(Map, &map, key + @as(u32, @intCast(keys.len))) != null) found += 1;
    }
    times[2] = timer.read();
    try check(found == 0);

    _ = timer.lap();
    sum = try iterationSum(Map, &map, allocator);
    times[3] = timer.read();
    try check(sum == expected);

    var removed: usize = 0;
    _ = timer.lap();
    for (keys) |key| {
        if (Map == HashMap) {
            if (map.remove(key)) removed += 1;
        } else {
            if (map.remove(key) != null) removed += 1;
        }
    }
    times[4] = timer.read();
    try check(removed == keys.len and map.count() == 0);
    return times;
}

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    {
        defer if (debug_allocator.deinit() == .leak) @panic("benchmark self-check leaked");
        inline for (MAPS) |Map| try selfCheck(Map, debug_allocator.allocator());
    }
    const allocator = std.heap.smp_allocator;
    std.debug.print("ReleaseFast; u32 keys and values; smp_allocator; median of {d} runs after one warmup\n", .{REPEATS});
    std.debug.print("container,items,input,insert_ns/op,hit_ns/op,miss_ns/op,iterate_ns/item,remove_ns/op\n", .{});
    for ([_]usize{ 1_000, 10_000, 100_000 }) |size| {
        const keys = try allocator.alloc(u32, size);
        defer allocator.free(keys);
        for (keys, 0..) |*key, i| key.* = @intCast(i);
        for ([_][]const u8{ "sequential", "shuffled" }, 0..) |input, input_index| {
            if (input_index == 1) {
                var prng = std.Random.DefaultPrng.init(0x6f726465726564);
                prng.random().shuffle(u32, keys);
            }
            inline for (MAPS, NAMES) |Map, name| {
                _ = try measure(Map, allocator, keys);
                var samples: [5][REPEATS]u64 = undefined;
                for (0..REPEATS) |repeat| {
                    const times = try measure(Map, allocator, keys);
                    for (times, 0..) |time, operation| samples[operation][repeat] = time;
                }
                std.debug.print("{s},{d},{s}", .{ name, size, input });
                for (&samples) |*operation| {
                    std.mem.sort(u64, operation, {}, std.sort.asc(u64));
                    const ns_per_op = @as(f64, @floatFromInt(operation[REPEATS / 2])) / @as(f64, @floatFromInt(size));
                    std.debug.print(",{d:.2}", .{ns_per_op});
                }
                std.debug.print("\n", .{});
            }
        }
    }
}
