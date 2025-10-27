//! A Trie (prefix tree) data structure for efficient string storage and retrieval.
//!
//! Tries are tree structures where each node represents a character in a string. They
//! excel at prefix-based operations like autocomplete, spell checking, and IP routing.
//! Unlike hash tables, tries support ordered iteration and prefix queries.
//!
//! ## Complexity
//! - Insert: O(m) where m is key length
//! - Remove: O(m) where m is key length
//! - Search: O(m) where m is key length
//! - Prefix search: O(m + k) where k is number of results
//! - Space: O(ALPHABET_SIZE * m * n) worst case, much better in practice with shared prefixes
//!
//! ## Use Cases
//! - Autocomplete and typeahead search
//! - Spell checkers and dictionaries
//! - IP routing tables (prefix matching)
//! - String matching and pattern search
//! - When you need both exact and prefix matching
//!
//! ## Thread Safety
//! This data structure is not thread-safe. External synchronization is required
//! for concurrent access.
//!
//! ## Iterator Invalidation
//! WARNING: Modifying the trie (via put/remove/clear) while iterating will cause
//! undefined behavior. Complete all iterations before modifying the structure.

const std = @import("std");

/// Creates a Trie type that maps string keys to values of type V.
///
/// ## Example
/// ```zig
/// var trie = try Trie([]const u8).init(allocator);
/// try trie.put("hello", "world");
/// if (trie.get("hello")) |value| {
///     std.debug.print("{s}\n", .{value.*});
/// }
/// ```
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

        /// Returns the number of elements in the trie.
        ///
        /// Time complexity: O(1)
        pub fn count(self: *const Self) usize {
            return self.len;
        }

        /// Creates a new empty trie.
        ///
        /// ## Errors
        /// Returns `error.OutOfMemory` if allocation fails.
        pub fn init(allocator: std.mem.Allocator) !Self {
            const root = try TrieNode.init(allocator);
            return Self{
                .root = root,
                .len = 0,
                .allocator = allocator,
            };
        }

        /// Frees all memory used by the trie.
        ///
        /// After calling this, the trie is no longer usable.
        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
            self.* = undefined;
        }

        /// Removes all elements from the trie while keeping the root allocated.
        ///
        /// Time complexity: O(n) where n is total number of nodes
        ///
        /// ## Errors
        /// Returns `error.OutOfMemory` if root node reallocation fails.
        pub fn clear(self: *Self) !void {
            self.root.deinit(self.allocator);
            self.root = try TrieNode.init(self.allocator);
            self.len = 0;
        }

        /// Inserts a key-value pair into the trie.
        ///
        /// If the key already exists, updates its value. Creates nodes as needed
        /// for each character in the key.
        ///
        /// Time complexity: O(m) where m is the key length
        ///
        /// ## Errors
        /// Returns `error.OutOfMemory` if node allocation fails.
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

        /// Retrieves an immutable pointer to the value associated with the given key.
        ///
        /// Returns `null` if the key doesn't exist.
        ///
        /// Time complexity: O(m) where m is the key length
        pub fn get(self: *const Self, key: []const u8) ?*const V {
            const node = self.findNode(key) orelse return null;
            if (!node.is_end) return null;
            return &node.value.?;
        }

        /// Retrieves a mutable pointer to the value associated with the given key.
        ///
        /// Returns `null` if the key doesn't exist. Allows in-place modification.
        ///
        /// Time complexity: O(m) where m is the key length
        pub fn getPtr(self: *Self, key: []const u8) ?*V {
            const node = self.findNodeMut(key) orelse return null;
            if (!node.is_end) return null;
            return &node.value.?;
        }

        /// Checks whether the trie contains an exact match for the given key.
        ///
        /// Time complexity: O(m) where m is the key length
        pub fn contains(self: *const Self, key: []const u8) bool {
            const node = self.findNode(key) orelse return false;
            return node.is_end;
        }

        /// Checks whether any keys in the trie start with the given prefix.
        ///
        /// Returns true even if the prefix itself is not a complete key.
        ///
        /// Time complexity: O(m) where m is the prefix length
        pub fn hasPrefix(self: *const Self, prefix: []const u8) bool {
            return self.findNode(prefix) != null;
        }

        /// Removes a key and returns its value if it existed.
        ///
        /// Returns `null` if the key doesn't exist. Prunes nodes that become unnecessary.
        ///
        /// Time complexity: O(m) where m is the key length
        pub fn remove(self: *Self, key: []const u8) ?V {
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

        /// Returns an iterator that yields all keys with the given prefix.
        /// The iterator manages its own memory and will be automatically cleaned up on deinit.
        pub fn keysWithPrefix(self: *const Self, allocator: std.mem.Allocator, prefix: []const u8) !PrefixIterator {
            const prefix_node = self.findNode(prefix);
            if (prefix_node == null) {
                return PrefixIterator{
                    .stack = std.ArrayList(PrefixIteratorFrame){},
                    .allocator = allocator,
                    .current_key = std.ArrayList(u8){},
                    .prefix_len = 0,
                };
            }

            var stack = std.ArrayList(PrefixIteratorFrame){};
            try stack.append(allocator, PrefixIteratorFrame{
                .node = prefix_node.?,
                .child_iter = prefix_node.?.children.iterator(),
                .visited_self = false,
            });

            var current_key = std.ArrayList(u8){};
            try current_key.appendSlice(allocator, prefix);

            return PrefixIterator{
                .stack = stack,
                .allocator = allocator,
                .current_key = current_key,
                .prefix_len = prefix.len,
            };
        }

        pub const PrefixIteratorFrame = struct {
            node: *const TrieNode,
            child_iter: std.HashMap(u8, *TrieNode, std.hash_map.AutoContext(u8), std.hash_map.default_max_load_percentage).Iterator,
            visited_self: bool,
        };

        pub const PrefixIterator = struct {
            stack: std.ArrayList(PrefixIteratorFrame),
            allocator: std.mem.Allocator,
            current_key: std.ArrayList(u8),
            prefix_len: usize,

            pub fn deinit(self: *PrefixIterator) void {
                self.stack.deinit(self.allocator);
                self.current_key.deinit(self.allocator);
            }

            pub fn next(self: *PrefixIterator) !?[]const u8 {
                while (self.stack.items.len > 0) {
                    var frame = &self.stack.items[self.stack.items.len - 1];

                    if (!frame.visited_self and frame.node.is_end) {
                        frame.visited_self = true;
                        return self.current_key.items;
                    }

                    if (frame.child_iter.next()) |entry| {
                        const char = entry.key_ptr.*;
                        const child = entry.value_ptr.*;

                        try self.current_key.append(self.allocator, char);

                        try self.stack.append(self.allocator, PrefixIteratorFrame{
                            .node = child,
                            .child_iter = child.children.iterator(),
                            .visited_self = false,
                        });
                    } else {
                        _ = self.stack.pop();
                        // Don't pop below prefix length
                        if (self.current_key.items.len > self.prefix_len) {
                            _ = self.current_key.pop();
                        }
                    }
                }
                return null;
            }
        };

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

            pub fn next(self: *Iterator) !?struct { key: []const u8, value: V } {
                while (self.stack.items.len > 0) {
                    var frame = &self.stack.items[self.stack.items.len - 1];

                    if (!frame.visited_self and frame.node.is_end) {
                        frame.visited_self = true;
                        return .{ .key = self.current_key.items, .value = frame.node.value.? };
                    }

                    if (frame.child_iter.next()) |entry| {
                        const char = entry.key_ptr.*;
                        const child = entry.value_ptr.*;

                        try self.current_key.append(self.allocator, char);

                        try self.stack.append(self.allocator, IteratorFrame{
                            .node = child,
                            .child_iter = child.children.iterator(),
                            .visited_self = false,
                        });
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

    const deleted = trie.remove("");
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

    const deleted = trie.remove("card");
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

    const deleted = trie.remove("world");
    try std.testing.expect(deleted == null);
    try std.testing.expectEqual(@as(usize, 1), trie.len);
}

test "Trie: delete prefix that is not a key" {
    const allocator = std.testing.allocator;
    var trie = try Trie(i32).init(allocator);
    defer trie.deinit();

    try trie.put("testing", 1);

    const deleted = trie.remove("test");
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

    _ = trie.remove("a");
    _ = trie.remove("b");
    _ = trie.remove("c");

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
