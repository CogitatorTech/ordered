//! A Trie (prefix tree) data structure for efficient string storage and retrieval.
//! Tries excel at prefix-based operations like autocomplete, word validation,
//! and prefix matching. They provide O(m) complexity where m is the key length.

const std = @import("std");

pub fn Trie(comptime V: type) type {
    return struct {
        const Self = @This();

        const TrieNode = struct {
            value: ?V = null,
            is_end: bool = false,
            children: std.HashMap(u8, *TrieNode, std.hash_map.AutoContext(u8), std.hash_map.default_max_load_percentage),

            fn init(allocator: std.mem.Allocator) !*TrieNode {
                const node = try allocator.create(TrieNode);
                node.* = TrieNode{
                    .children = std.HashMap(u8, *TrieNode, std.hash_map.AutoContext(u8), std.hash_map.default_max_load_percentage).init(allocator),
                };
                return node;
            }

            fn deinit(self: *TrieNode, allocator: std.mem.Allocator) void {
                var iter = self.children.iterator();
                while (iter.next()) |entry| {
                    entry.value_ptr.*.deinit(allocator);
                }
                self.children.deinit();
                allocator.destroy(self);
            }
        };

        root: *TrieNode,
        len: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const root = try TrieNode.init(allocator);
            return Self{
                .root = root,
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn put(self: *Self, key: []const u8, value: V) !void {
            var current = self.root;

            for (key) |char| {
                if (!current.children.contains(char)) {
                    const new_node = try TrieNode.init(self.allocator);
                    try current.children.put(char, new_node);
                }
                current = current.children.get(char).?;
            }

            if (!current.is_end) {
                self.len += 1;
            }
            current.value = value;
            current.is_end = true;
        }

        pub fn get(self: *const Self, key: []const u8) ?*const V {
            const node = self.findNode(key) orelse return null;
            if (!node.is_end) return null;
            return &node.value.?;
        }

        pub fn getPtr(self: *Self, key: []const u8) ?*V {
            const node = self.findNodeMut(key) orelse return null;
            if (!node.is_end) return null;
            return &node.value.?;
        }

        pub fn contains(self: *const Self, key: []const u8) bool {
            const node = self.findNode(key) orelse return false;
            return node.is_end;
        }

        pub fn hasPrefix(self: *const Self, prefix: []const u8) bool {
            return self.findNode(prefix) != null;
        }

        pub fn delete(self: *Self, key: []const u8) ?V {
            const result = self.deleteRecursive(self.root, key, 0);
            if (result.deleted) {
                self.len -= 1;
                return result.value;
            }
            return null;
        }

        const DeleteResult = struct {
            deleted: bool,
            value: ?V,
            should_delete_node: bool,
        };

        fn deleteRecursive(self: *Self, node: *TrieNode, key: []const u8, depth: usize) DeleteResult {
            if (depth == key.len) {
                if (!node.is_end) {
                    return DeleteResult{ .deleted = false, .value = null, .should_delete_node = false };
                }

                const value = node.value;
                node.is_end = false;
                node.value = null;

                const should_delete = node.children.count() == 0;
                return DeleteResult{ .deleted = true, .value = value, .should_delete_node = should_delete };
            }

            const char = key[depth];
            const child = node.children.get(char) orelse {
                return DeleteResult{ .deleted = false, .value = null, .should_delete_node = false };
            };

            const result = self.deleteRecursive(child, key, depth + 1);

            if (result.should_delete_node) {
                child.deinit(self.allocator);
                _ = node.children.remove(char);
            }

            if (result.deleted) {
                const should_delete = !node.is_end and node.children.count() == 0;
                return DeleteResult{ .deleted = true, .value = result.value, .should_delete_node = should_delete };
            }

            return result;
        }

        fn findNode(self: *const Self, key: []const u8) ?*const TrieNode {
            var current = self.root;
            for (key) |char| {
                current = current.children.get(char) orelse return null;
            }
            return current;
        }

        fn findNodeMut(self: *Self, key: []const u8) ?*TrieNode {
            var current = self.root;
            for (key) |char| {
                current = current.children.get(char) orelse return null;
            }
            return current;
        }

        pub fn keysWithPrefix(self: *const Self, allocator: std.mem.Allocator, prefix: []const u8) !std.ArrayList([]u8) {
            var results: std.ArrayList([]u8) = .{};

            const prefix_node = self.findNode(prefix) orelse return results;
            try self.collectKeys(allocator, prefix_node, &results, prefix);

            return results;
        }

        fn collectKeys(self: *const Self, allocator: std.mem.Allocator, node: *const TrieNode, results: *std.ArrayList([]u8), current_key: []const u8) !void {
            if (node.is_end) {
                const key_copy = try allocator.dupe(u8, current_key);
                try results.append(allocator, key_copy);
            }

            var iter = node.children.iterator();
            while (iter.next()) |entry| {
                const char = entry.key_ptr.*;
                const child = entry.value_ptr.*;

                var new_key = try allocator.alloc(u8, current_key.len + 1);
                defer allocator.free(new_key);
                @memcpy(new_key[0..current_key.len], current_key);
                new_key[current_key.len] = char;

                try self.collectKeys(allocator, child, results, new_key);
            }
        }

        pub const Iterator = struct {
            stack: std.ArrayList(IteratorFrame),
            allocator: std.mem.Allocator,
            current_key: std.ArrayList(u8),

            const IteratorFrame = struct {
                node: *const TrieNode,
                child_iter: std.HashMap(u8, *TrieNode, std.hash_map.AutoContext(u8), std.hash_map.default_max_load_percentage).Iterator,
                visited_self: bool,
            };

            fn init(allocator: std.mem.Allocator, root: *const TrieNode) !Iterator {
                var stack: std.ArrayList(IteratorFrame) = .{};
                try stack.append(allocator, IteratorFrame{
                    .node = root,
                    .child_iter = root.children.iterator(),
                    .visited_self = false,
                });

                return Iterator{
                    .stack = stack,
                    .allocator = allocator,
                    .current_key = .{},
                };
            }

            fn deinit(self: *Iterator) void {
                self.stack.deinit(self.allocator);
                self.current_key.deinit(self.allocator);
            }

            pub fn next(self: *Iterator) ?struct { key: []const u8, value: V } {
                while (self.stack.items.len > 0) {
                    var frame = &self.stack.items[self.stack.items.len - 1];

                    if (!frame.visited_self and frame.node.is_end) {
                        frame.visited_self = true;
                        return .{ .key = self.current_key.items, .value = frame.node.value.? };
                    }

                    if (frame.child_iter.next()) |entry| {
                        const char = entry.key_ptr.*;
                        const child = entry.value_ptr.*;

                        self.current_key.append(self.allocator, char) catch return null;

                        self.stack.append(self.allocator, IteratorFrame{
                            .node = child,
                            .child_iter = child.children.iterator(),
                            .visited_self = false,
                        }) catch return null;
                    } else {
                        _ = self.stack.pop();
                        if (self.current_key.items.len > 0) {
                            _ = self.current_key.pop();
                        }
                    }
                }
                return null;
            }
        };

        pub fn iterator(self: *const Self) !Iterator {
            return Iterator.init(self.allocator, self.root);
        }
    };
}

test "Trie: basic operations" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("hello", 1);
    try trie.put("world", 2);
    try trie.put("help", 3);

    try std.testing.expectEqual(@as(usize, 3), trie.len);
    try std.testing.expectEqual(@as(i32, 1), trie.get("hello").?.*);
    try std.testing.expectEqual(@as(i32, 3), trie.get("help").?.*);
    try std.testing.expect(trie.get("bye") == null);
}

test "Trie: empty trie operations" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try std.testing.expect(trie.get("key") == null);
    try std.testing.expectEqual(@as(usize, 0), trie.len);
    try std.testing.expect(!trie.contains("key"));
    try std.testing.expect(!trie.hasPrefix("pre"));
}

test "Trie: single character keys" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("a", 1);
    try trie.put("b", 2);
    try trie.put("c", 3);

    try std.testing.expectEqual(@as(i32, 2), trie.get("b").?.*);
    try std.testing.expect(trie.contains("a"));
    try std.testing.expect(!trie.contains("d"));
}

test "Trie: empty string key" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("", 42);
    try std.testing.expectEqual(@as(usize, 1), trie.len);
    try std.testing.expectEqual(@as(i32, 42), trie.get("").?.*);

    const deleted = trie.delete("");
    try std.testing.expectEqual(@as(i32, 42), deleted.?);
    try std.testing.expectEqual(@as(usize, 0), trie.len);
}

test "Trie: overlapping prefixes" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("test", 1);
    try trie.put("testing", 2);
    try trie.put("tester", 3);
    try trie.put("tested", 4);

    try std.testing.expectEqual(@as(usize, 4), trie.len);
    try std.testing.expectEqual(@as(i32, 1), trie.get("test").?.*);
    try std.testing.expectEqual(@as(i32, 2), trie.get("testing").?.*);
    try std.testing.expect(trie.hasPrefix("tes"));
    try std.testing.expect(trie.hasPrefix("test"));
}

test "Trie: delete with shared prefixes" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("car", 1);
    try trie.put("card", 2);
    try trie.put("care", 3);

    const deleted = trie.delete("card");
    try std.testing.expectEqual(@as(i32, 2), deleted.?);
    try std.testing.expectEqual(@as(usize, 2), trie.len);
    try std.testing.expect(!trie.contains("card"));
    try std.testing.expect(trie.contains("car"));
    try std.testing.expect(trie.contains("care"));
}

test "Trie: delete non-existent key" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("hello", 1);

    const deleted = trie.delete("world");
    try std.testing.expect(deleted == null);
    try std.testing.expectEqual(@as(usize, 1), trie.len);
}

test "Trie: delete prefix that is not a key" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("testing", 1);

    const deleted = trie.delete("test");
    try std.testing.expect(deleted == null);
    try std.testing.expectEqual(@as(usize, 1), trie.len);
    try std.testing.expect(trie.contains("testing"));
}

test "Trie: update existing key" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("key", 100);
    try std.testing.expectEqual(@as(usize, 1), trie.len);

    try trie.put("key", 200);
    try std.testing.expectEqual(@as(usize, 1), trie.len);
    try std.testing.expectEqual(@as(i32, 200), trie.get("key").?.*);
}

test "Trie: hasPrefix with exact match" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("hello", 1);

    try std.testing.expect(trie.hasPrefix("hello"));
    try std.testing.expect(trie.hasPrefix("hel"));
    try std.testing.expect(trie.hasPrefix("h"));
    try std.testing.expect(!trie.hasPrefix("helloo"));
}

test "Trie: getPtr mutation" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("key", 100);

    const ptr = trie.getPtr("key");
    try std.testing.expect(ptr != null);
    ptr.?.* = 999;

    try std.testing.expectEqual(@as(i32, 999), trie.get("key").?.*);
}

test "Trie: many keys" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    const keys = [_][]const u8{
        "apple", "application", "apply", "banana", "band",
        "can",   "cancel",      "cat",   "dog",    "door",
    };

    for (keys, 0..) |key, i| {
        try trie.put(key, @intCast(i));
    }

    try std.testing.expectEqual(@as(usize, 10), trie.len);

    for (keys, 0..) |key, i| {
        try std.testing.expectEqual(@as(i32, @intCast(i)), trie.get(key).?.*);
    }
}

test "Trie: delete all keys" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("a", 1);
    try trie.put("b", 2);
    try trie.put("c", 3);

    _ = trie.delete("a");
    _ = trie.delete("b");
    _ = trie.delete("c");

    try std.testing.expectEqual(@as(usize, 0), trie.len);
    try std.testing.expect(!trie.hasPrefix("a"));
}

test "Trie: special characters" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("hello-world", 1);
    try trie.put("test_case", 2);
    try trie.put("foo.bar", 3);

    try std.testing.expectEqual(@as(i32, 1), trie.get("hello-world").?.*);
    try std.testing.expectEqual(@as(i32, 2), trie.get("test_case").?.*);
    try std.testing.expectEqual(@as(i32, 3), trie.get("foo.bar").?.*);
}
