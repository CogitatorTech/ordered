const std = @import("std");
const ordered = @import("ordered");
const Timer = @import("timer.zig").Timer;
const CountingAllocator = @import("counting_allocator.zig").CountingAllocator;

const PROBE_LIMIT = 100_000;
const NAMES = .{ "BTreeMap", "CartesianTreeMap", "SkipListMap", "std.Treap", "std.HashMap (unordered)" };

fn check(ok: bool) !void {
    if (!ok) return error.BenchmarkMismatch;
}

fn shuffle(items: []u32, seed: u64) void {
    var prng = std.Random.DefaultPrng.init(seed);
    prng.random().shuffle(u32, items);
}

fn Suite(comptime K: type, comptime V: type) type {
    return struct {
        const BTree = ordered.BTreeMap(K, V, compare, 16);
        const CartesianTree = ordered.CartesianTreeMap(K, V, compare);
        const SkipList = ordered.SkipListMap(K, V, compare, 16);
        const HashMap = if (K == u64) std.AutoHashMap(K, V) else std.StringHashMap(V);
        const MAPS = .{ BTree, CartesianTree, SkipList, TreapMap, HashMap };

        fn compare(a: K, b: K) std.math.Order {
            return if (K == u64) std.math.order(a, b) else std.mem.order(u8, a, b);
        }

        fn value(id: u64) V {
            return if (V == u64) id else .{ id, id * 3, id * 5, id * 7 };
        }

        fn fingerprint(v: V) u64 {
            return if (V == u64) v else v[0] + v[1] + v[2] + v[3];
        }

        fn expectedSum(size: usize) u64 {
            return @as(u64, size) * (size + 1) / 2 * (if (V == u64) @as(u64, 1) else 16);
        }

        // std.Treap is intrusive; include allocation and value storage in its cost.
        const TreapMap = struct {
            const Tree = std.Treap(K, compare);
            const Node = struct { tree_node: Tree.Node, value: V };
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

            fn put(self: *TreapMap, key: K, v: V) !void {
                var entry = self.tree.getEntryFor(key);
                if (entry.node) |node| {
                    const parent: *Node = @fieldParentPtr("tree_node", node);
                    parent.value = v;
                } else {
                    const node = try self.allocator.create(Node);
                    node.value = v;
                    entry.set(&node.tree_node);
                    self.len += 1;
                }
            }

            fn getPtr(self: *TreapMap, key: K) ?*V {
                const node = self.tree.getEntryFor(key).node orelse return null;
                const parent: *Node = @fieldParentPtr("tree_node", node);
                return &parent.value;
            }

            fn remove(self: *TreapMap, key: K) ?V {
                var entry = self.tree.getEntryFor(key);
                const node = entry.node orelse return null;
                const parent: *Node = @fieldParentPtr("tree_node", node);
                const v = parent.value;
                entry.set(null);
                self.allocator.destroy(parent);
                self.len -= 1;
                return v;
            }
        };

        const Dataset = struct {
            present: []K,
            absent: []K,
            queries: []K,
            bytes: []u8,
            insertion: []u32,
            lookup: []u32,
            removal: []u32,

            fn init(allocator: std.mem.Allocator, size: usize, key_len: usize) !Dataset {
                const present = try allocator.alloc(K, size);
                errdefer allocator.free(present);
                const absent = try allocator.alloc(K, size);
                errdefer allocator.free(absent);
                const queries = try allocator.alloc(K, size);
                errdefer allocator.free(queries);
                const bytes = try allocator.alloc(u8, if (K == u64) 0 else size * 3 * key_len);
                errdefer allocator.free(bytes);
                for (0..size) |i| {
                    if (K == u64) {
                        present[i] = 2 * i;
                        absent[i] = 2 * i + 1;
                        queries[i] = present[i];
                    } else {
                        for (0..3) |which| {
                            const key = bytes[(3 * i + which) * key_len ..][0..key_len];
                            @memset(key, 'a');
                            _ = try std.fmt.bufPrint(key[key_len - 16 ..], "{x:0>16}", .{2 * i + which % 2});
                            switch (which) {
                                0 => present[i] = key,
                                1 => absent[i] = key,
                                2 => queries[i] = key,
                                else => unreachable,
                            }
                        }
                    }
                }
                const insertion = try allocator.alloc(u32, size);
                errdefer allocator.free(insertion);
                const lookup = try allocator.alloc(u32, size);
                errdefer allocator.free(lookup);
                const removal = try allocator.alloc(u32, size);
                errdefer allocator.free(removal);
                for (0..size) |i| {
                    insertion[i] = @intCast(i);
                    lookup[i] = @intCast(i);
                    removal[i] = @intCast(i);
                }
                shuffle(lookup, 0x10_0c);
                shuffle(removal, 0xde_1e);
                return .{ .present = present, .absent = absent, .queries = queries, .bytes = bytes, .insertion = insertion, .lookup = lookup, .removal = removal };
            }

            fn deinit(self: Dataset, allocator: std.mem.Allocator) void {
                allocator.free(self.removal);
                allocator.free(self.lookup);
                allocator.free(self.insertion);
                allocator.free(self.bytes);
                allocator.free(self.queries);
                allocator.free(self.absent);
                allocator.free(self.present);
            }
        };

        fn initMap(comptime Map: type, allocator: std.mem.Allocator) !Map {
            return if (Map == SkipList) try Map.init(allocator) else Map.init(allocator);
        }

        fn remove(comptime Map: type, map: *Map, key: K) bool {
            return if (Map == HashMap) map.remove(key) else map.remove(key) != null;
        }

        fn iterationSum(comptime Map: type, map: *Map, allocator: std.mem.Allocator) !u64 {
            var sum: u64 = 0;
            if (Map == TreapMap) {
                var it = map.tree.inorderIterator();
                while (it.next()) |node| {
                    const parent: *TreapMap.Node = @fieldParentPtr("tree_node", node);
                    sum += fingerprint(parent.value);
                }
            } else if (Map == HashMap) {
                var it = map.iterator();
                while (it.next()) |entry| sum += fingerprint(entry.value_ptr.*);
            } else if (Map == SkipList) {
                var it = map.iterator();
                while (it.next()) |entry| sum += fingerprint(entry.value);
            } else {
                var it = if (Map == CartesianTree) try map.iterator(allocator) else try map.iterator();
                defer it.deinit();
                while (try it.next()) |entry| sum += fingerprint(entry.value);
            }
            return sum;
        }

        fn measure(comptime Map: type, allocator: std.mem.Allocator, data: Dataset) ![5]u64 {
            var map = try initMap(Map, allocator);
            defer map.deinit();
            var times: [5]u64 = undefined;
            var timer = try Timer.start();
            for (data.insertion) |i| try map.put(data.present[i], value(@as(u64, i) + 1));
            times[0] = timer.read();
            try check(map.count() == data.present.len);
            const probes = data.lookup[0..@min(data.lookup.len, PROBE_LIMIT)];
            var expected_hits: u64 = 0;
            for (probes) |i| expected_hits += fingerprint(value(@as(u64, i) + 1));
            var sum: u64 = 0;
            var hits: usize = 0;
            _ = timer.lap();
            for (probes) |i| {
                if (map.getPtr(data.queries[i])) |v| {
                    sum += fingerprint(v.*);
                    hits += 1;
                }
            }
            times[1] = timer.read();
            try check(hits == probes.len and sum == expected_hits);
            hits = 0;
            _ = timer.lap();
            for (probes) |i| {
                if (map.getPtr(data.absent[i]) != null) hits += 1;
            }
            times[2] = timer.read();
            try check(hits == 0);
            _ = timer.lap();
            sum = try iterationSum(Map, &map, allocator);
            times[3] = timer.read();
            try check(sum == expectedSum(data.present.len));
            var removed: usize = 0;
            _ = timer.lap();
            for (data.removal[0..probes.len]) |i| {
                if (remove(Map, &map, data.queries[i])) removed += 1;
            }
            times[4] = timer.read();
            try check(removed == probes.len and map.count() == data.present.len - probes.len);
            return times;
        }

        fn buildMany(comptime Map: type, allocator: std.mem.Allocator, data: Dataset, count: usize) ![]Map {
            const maps = try allocator.alloc(Map, count);
            errdefer allocator.free(maps);
            var initialized: usize = 0;
            errdefer for (maps[0..initialized]) |*map| map.deinit();
            for (maps) |*map| {
                map.* = try initMap(Map, allocator);
                initialized += 1;
                for (data.insertion) |i| try map.put(data.present[i], value(@as(u64, i) + 1));
            }
            return maps;
        }

        fn destroyMany(comptime Map: type, allocator: std.mem.Allocator, maps: []Map) void {
            for (maps) |*map| map.deinit();
            allocator.free(maps);
        }

        fn measureTiny(comptime Map: type, allocator: std.mem.Allocator, data: Dataset, count: usize) ![3]u64 {
            var timer = try Timer.start();
            const maps = try buildMany(Map, allocator, data, count);
            const build_ns = timer.read();
            errdefer destroyMany(Map, allocator, maps);
            var sum: u64 = 0;
            _ = timer.lap();
            for (maps) |*map| sum += try iterationSum(Map, map, allocator);
            const iteration_ns = timer.read();
            try check(sum == expectedSum(data.present.len) * count);
            _ = timer.lap();
            destroyMany(Map, allocator, maps);
            const destroy_ns = timer.read();
            return .{ build_ns, iteration_ns, destroy_ns };
        }

        fn selfCheck(allocator: std.mem.Allocator, key_len: usize) !void {
            const data = try Dataset.init(allocator, 17, key_len);
            defer data.deinit(allocator);
            inline for (MAPS) |Map| {
                var map = try initMap(Map, allocator);
                defer map.deinit();
                try check(map.count() == 0 and map.getPtr(data.present[0]) == null);
                try check(try iterationSum(Map, &map, allocator) == 0);
                try check(!remove(Map, &map, data.present[0]));
                try map.put(data.present[0], value(1));
                try map.put(data.queries[0], value(2));
                try check(map.count() == 1 and fingerprint(map.getPtr(data.queries[0]).?.*) == fingerprint(value(2)));
                try check(remove(Map, &map, data.queries[0]) and map.count() == 0);
                // Leave a live node to exercise cleanup as well as removal.
                try map.put(data.present[1], value(3));
                _ = try measure(Map, allocator, data);
                _ = try measureTiny(Map, allocator, data, 3);
            }
        }

        fn report(allocator: std.mem.Allocator, size: usize, key_len: usize, repeats: usize, comptime memory: bool, comptime tiny: bool, tiny_count: usize) !void {
            const data = try Dataset.init(allocator, size, key_len);
            defer data.deinit(allocator);
            for (0..if (tiny) @as(usize, 1) else 2) |input_index| {
                if (input_index == 1 or tiny) shuffle(data.insertion, 0x1a_5e);
                inline for (MAPS, NAMES) |Map, name| {
                    const input = if (input_index == 1 or tiny) "shuffled" else "sequential";
                    const key_kind = if (K == u64) "u64" else if (key_len == 16) "string16" else "string100";
                    std.debug.print("{s},{s},{d},{d},{s},{d}", .{ name, key_kind, @sizeOf(V), size, input, @max(tiny_count, 1) });
                    if (memory) {
                        var counting: CountingAllocator = .{ .child = allocator };
                        var live: usize = 0;
                        var peak: usize = 0;
                        {
                            const maps = try buildMany(Map, counting.allocator(), data, @max(tiny_count, 1));
                            defer destroyMany(Map, counting.allocator(), maps);
                            live = counting.live_bytes;
                            peak = counting.peak_bytes;
                            for (maps) |map| try check(map.count() == size);
                        }
                        try check(counting.live_bytes == 0);
                        const per_entry = @as(f64, @floatFromInt(live)) / @as(f64, @floatFromInt(size * @max(tiny_count, 1)));
                        std.debug.print(",{d},{d},{d:.2}\n", .{ live, peak, per_entry });
                    } else {
                        const operation_count = if (tiny) 3 else 5;
                        var samples: [operation_count][5]u64 = undefined;
                        for (0..repeats + 1) |repeat| {
                            const times = if (tiny) try measureTiny(Map, allocator, data, tiny_count) else try measure(Map, allocator, data);
                            if (repeat > 0) for (times, 0..) |time, operation| {
                                samples[operation][repeat - 1] = time;
                            };
                        }
                        for (&samples, 0..) |*operation, i| {
                            std.mem.sort(u64, operation[0..repeats], {}, std.sort.asc(u64));
                            const divisor = if (!tiny)
                                (if (i == 1 or i == 2 or i == 4) @min(size, PROBE_LIMIT) else size)
                            else if (i == 1) size * tiny_count else tiny_count;
                            const per_op = @as(f64, @floatFromInt(operation[repeats / 2])) / @as(f64, @floatFromInt(divisor));
                            std.debug.print(",{d:.2}", .{per_op});
                        }
                        std.debug.print("\n", .{});
                    }
                }
            }
        }
    };
}

pub fn run(init: std.process.Init, comptime memory: bool) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var quick = false;
    var large = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--quick")) {
            quick = true;
        } else if (std.mem.eql(u8, arg, "--large")) {
            large = true;
        } else {
            std.debug.print("Usage: {s} [--quick] [--large]\n", .{args[0]});
            return error.InvalidArguments;
        }
    }
    const allocator = std.heap.smp_allocator;
    const repeats: usize = if (quick) 1 else 5;
    const sizes: []const usize = if (large) &.{ 1_000_000, 10_000_000 } else if (quick) &.{1_000} else &.{ 1_000, 10_000, 100_000 };
    if (memory) {
        std.debug.print("ReleaseFast; smp_allocator; requested live and peak bytes; shared key buffers excluded\n", .{});
    } else {
        std.debug.print("ReleaseFast; smp_allocator; median timings; samples={d}; warmups=1; query_limit={d}\n", .{ repeats, PROBE_LIMIT });
    }
    std.debug.print("container,keys,value_bytes,items,input,maps,{s}\n", .{if (memory) "live_bytes,peak_bytes,bytes/item" else "insert_ns/op,hit_ns/op,miss_ns/op,iterate_ns/item,remove_ns/op"});
    for (sizes) |size| {
        try Suite(u64, u64).report(allocator, size, 0, repeats, memory, false, 0);
        if (!large) {
            try Suite(u64, [4]u64).report(allocator, size, 0, repeats, memory, false, 0);
            inline for (.{ u64, [4]u64 }) |V| {
                for ([_]usize{ 16, 100 }) |key_len| try Suite([]const u8, V).report(allocator, size, key_len, repeats, memory, false, 0);
            }
        }
    }
    if (!large) {
        std.debug.print("container,keys,value_bytes,items,input,maps,{s}\n", .{if (memory) "live_bytes,peak_bytes,bytes/item" else "build_ns/map,iterate_ns/item,destroy_ns/map"});
        for ([_]usize{ 4, 32 }) |size| try Suite([]const u8, [4]u64).report(allocator, size, 16, repeats, memory, true, if (quick) 128 else 10_000);
    }
}

test "comparison workloads cover map adapters, value sizes, and cleanup" {
    inline for (.{ u64, [4]u64 }) |V| {
        try Suite(u64, V).selfCheck(std.testing.allocator, 0);
        try Suite([]const u8, V).selfCheck(std.testing.allocator, 16);
        try Suite([]const u8, V).selfCheck(std.testing.allocator, 100);
    }
}

test "missing keys are interleaved and operation orders are independent permutations" {
    const S = Suite(u64, u64);
    const data = try S.Dataset.init(std.testing.allocator, 100, 0);
    defer data.deinit(std.testing.allocator);
    var seen: [100]bool = @splat(false);
    for (data.present, data.absent, 0..) |present, absent, i| {
        try std.testing.expectEqual(2 * i, present);
        try std.testing.expectEqual(present + 1, absent);
    }
    for (data.lookup) |i| {
        try std.testing.expect(!seen[i]);
        seen[i] = true;
    }
    @memset(&seen, false);
    for (data.removal) |i| {
        try std.testing.expect(!seen[i]);
        seen[i] = true;
    }
    try std.testing.expect(!std.mem.eql(u32, data.insertion, data.lookup));
    shuffle(data.insertion, 0x1a_5e);
    try std.testing.expect(!std.mem.eql(u32, data.insertion, data.lookup));
    try std.testing.expect(!std.mem.eql(u32, data.insertion, data.removal));
    try std.testing.expect(!std.mem.eql(u32, data.lookup, data.removal));
}

fn allocationCheck(allocator: std.mem.Allocator) !void {
    const S = Suite([]const u8, [4]u64);
    const data = try S.Dataset.init(allocator, 4, 16);
    defer data.deinit(allocator);
    inline for (S.MAPS) |Map| {
        const maps = try S.buildMany(Map, allocator, data, 3);
        S.destroyMany(Map, allocator, maps);
    }
}

test "dataset and partially built maps release allocations on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCheck, .{});
}

test "large workloads check sampled lookups and partial removal" {
    const S = Suite(u64, u64);
    const data = try S.Dataset.init(std.testing.allocator, PROBE_LIMIT + 3, 0);
    defer data.deinit(std.testing.allocator);
    _ = try S.measure(S.BTree, std.testing.allocator, data);
    _ = try S.measure(S.HashMap, std.testing.allocator, data);
}

test "memory workload releases all measured allocations" {
    const S = Suite([]const u8, [4]u64);
    const data = try S.Dataset.init(std.testing.allocator, 32, 16);
    defer data.deinit(std.testing.allocator);
    inline for (S.MAPS) |Map| {
        var counting: CountingAllocator = .{ .child = std.testing.allocator };
        const maps = try S.buildMany(Map, counting.allocator(), data, 4);
        try std.testing.expect(counting.live_bytes >= @sizeOf(Map) * 4);
        try std.testing.expect(counting.peak_bytes >= counting.live_bytes);
        S.destroyMany(Map, counting.allocator(), maps);
        try std.testing.expectEqual(0, counting.live_bytes);
    }
}

test "string probes have equal contents at different addresses and misses sort between present keys" {
    const S = Suite([]const u8, u64);
    for ([_]usize{ 16, 100 }) |key_len| {
        const data = try S.Dataset.init(std.testing.allocator, 17, key_len);
        defer data.deinit(std.testing.allocator);
        for (data.present, data.queries, data.absent, 0..) |present, query, absent, i| {
            try std.testing.expectEqual(key_len, present.len);
            try std.testing.expect(present.ptr != query.ptr);
            try std.testing.expectEqualStrings(present, query);
            try std.testing.expect(std.mem.order(u8, present, absent) == .lt);
            if (i + 1 < data.present.len) try std.testing.expect(std.mem.order(u8, absent, data.present[i + 1]) == .lt);
        }
    }
}
