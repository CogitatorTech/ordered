//! Red-Black Tree - A self-balancing binary search tree.
//!
//! Red-Black Trees guarantee O(log n) time complexity for insert, delete, and search
//! operations by maintaining balance through color properties and rotations. They are
//! widely used in standard libraries (e.g., C++ std::map, Java TreeMap).
//!
//! ## Complexity
//! - Insert: O(log n)
//! - Remove: O(log n)
//! - Search: O(log n)
//! - Space: O(n)
//!
//! ## Properties
//! 1. Every node is either red or black
//! 2. The root is always black
//! 3. All leaves (NIL) are black
//! 4. Red nodes have black children (no two red nodes in a row)
//! 5. All paths from root to leaves contain the same number of black nodes
//!
//! ## Use Cases
//! - Ordered set/map with guaranteed O(log n) operations
//! - When worst-case performance matters more than average case
//! - Standard library implementations of associative containers
//!
//! ## Thread Safety
//! This data structure is not thread-safe. External synchronization is required
//! for concurrent access.
//!
//! ## Iterator Invalidation
//! WARNING: Modifying the tree (via put/remove/clear) while iterating will
//! cause undefined behavior. Complete all iterations before modifying the structure.

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const assert = std.debug.assert;

/// Creates a Red-Black Tree type for the given data type and comparison context.
///
/// ## Parameters
/// - `T`: The data type to store in the tree
/// - `Context`: A type providing a `lessThan(ctx, a, b) bool` method for comparison
///
/// ## Example
/// ```zig
/// const Context = struct {
///     pub fn lessThan(_: @This(), a: i32, b: i32) bool {
///         return a < b;
///     }
/// };
/// var tree = RedBlackTree(i32, Context).init(allocator, .{});
/// ```
pub fn RedBlackTree(comptime T: type, comptime Context: type) type {
    return struct {
        const Self = @This();

        pub const Color = enum { red, black };

        pub const Node = struct {
            data: T,
            color: Color,
            left: ?*Node,
            right: ?*Node,
            parent: ?*Node,

            fn isRed(node: ?*Node) bool {
                return if (node) |n| n.color == .red else false;
            }

            fn isBlack(node: ?*Node) bool {
                return if (node) |n| n.color == .black else true; // NIL nodes are black
            }
        };

        root: ?*Node,
        allocator: Allocator,
        context: Context,
        size: usize,

        /// Creates a new empty Red-Black Tree.
        ///
        /// ## Parameters
        /// - `allocator`: Memory allocator for node allocation
        /// - `context`: Comparison context instance
        pub fn init(allocator: Allocator, context: Context) Self {
            return Self{
                .root = null,
                .allocator = allocator,
                .context = context,
                .size = 0,
            };
        }

        /// Frees all memory used by the tree.
        ///
        /// After calling this, the tree is no longer usable.
        pub fn deinit(self: *Self) void {
            self.clear();
        }

        /// Removes all elements from the tree.
        ///
        /// Time complexity: O(n)
        pub fn clear(self: *Self) void {
            self.clearNode(self.root);
            self.root = null;
            self.size = 0;
        }

        fn clearNode(self: *Self, node: ?*Node) void {
            if (node) |n| {
                self.clearNode(n.left);
                self.clearNode(n.right);
                self.allocator.destroy(n);
            }
        }

        /// Returns the number of elements in the tree.
        ///
        /// Time complexity: O(1)
        pub fn count(self: *const Self) usize {
            return self.size;
        }

        /// Inserts or updates a value in the tree.
        ///
        /// If the value already exists (as determined by the context's lessThan method),
        /// it will be updated. Otherwise, a new node is created.
        ///
        /// Time complexity: O(log n)
        ///
        /// ## Errors
        /// Returns `error.OutOfMemory` if node allocation fails.
        pub fn put(self: *Self, data: T) !void {
            // Check if key already exists first to avoid unnecessary allocation
            if (self.get(data)) |existing| {
                existing.data = data;
                return;
            }

            const new_node = try self.allocator.create(Node);
            new_node.* = Node{
                .data = data,
                .color = .red, // New nodes are always red
                .left = null,
                .right = null,
                .parent = null,
            };

            if (self.root == null) {
                self.root = new_node;
                new_node.color = .black; // Root is always black
                self.size = 1;
                return;
            }

            // Standard BST insertion
            var current = self.root;
            var parent: ?*Node = null;

            while (current != null) {
                parent = current;
                if (self.context.lessThan(data, current.?.data)) {
                    current = current.?.left;
                } else {
                    current = current.?.right;
                }
            }

            new_node.parent = parent;
            if (self.context.lessThan(data, parent.?.data)) {
                parent.?.left = new_node;
            } else {
                parent.?.right = new_node;
            }

            self.size += 1;
            self.fixInsert(new_node);
        }

        fn fixInsert(self: *Self, node: *Node) void {
            var current = node;

            while (current.parent != null and Node.isRed(current.parent)) {
                const parent = current.parent.?;
                const grandparent = parent.parent orelse break;

                if (parent == grandparent.left) {
                    const uncle = grandparent.right;

                    if (Node.isRed(uncle)) {
                        // Case 1: Uncle is red
                        parent.color = .black;
                        uncle.?.color = .black;
                        grandparent.color = .red;
                        current = grandparent;
                    } else {
                        if (current == parent.right) {
                            // Case 2: Uncle is black, current is right child
                            current = parent;
                            self.rotateLeft(current);
                        }
                        // Case 3: Uncle is black, current is left child
                        const new_parent = current.parent orelse break;
                        const new_grandparent = new_parent.parent orelse break;
                        new_parent.color = .black;
                        new_grandparent.color = .red;
                        self.rotateRight(new_grandparent);
                    }
                } else {
                    const uncle = grandparent.left;

                    if (Node.isRed(uncle)) {
                        // Case 1: Uncle is red
                        parent.color = .black;
                        uncle.?.color = .black;
                        grandparent.color = .red;
                        current = grandparent;
                    } else {
                        if (current == parent.left) {
                            // Case 2: Uncle is black, current is left child
                            current = parent;
                            self.rotateRight(current);
                        }
                        // Case 3: Uncle is black, current is right child
                        const new_parent = current.parent orelse break;
                        const new_grandparent = new_parent.parent orelse break;
                        new_parent.color = .black;
                        new_grandparent.color = .red;
                        self.rotateLeft(new_grandparent);
                    }
                }
            }

            if (self.root) |root| root.color = .black; // Root is always black
        }

        /// Removes a value from the tree and returns it if it existed.
        ///
        /// Returns `null` if the value is not found.
        ///
        /// Time complexity: O(log n)
        pub fn remove(self: *Self, data: T) ?T {
            const node = self.get(data) orelse return null;
            const value = node.data;
            self.removeNode(node);
            self.size -= 1;
            return value;
        }

        fn removeNode(self: *Self, node: *Node) void {
            var deleted_node = node;
            var deleted_color = deleted_node.color;
            var replacement: ?*Node = null;

            if (node.left == null) {
                replacement = node.right;
                self.transplant(node, node.right);
            } else if (node.right == null) {
                replacement = node.left;
                self.transplant(node, node.left);
            } else {
                deleted_node = self.findMinimum(node.right.?);
                deleted_color = deleted_node.color;
                replacement = deleted_node.right;

                if (deleted_node.parent == node) {
                    if (replacement) |r| r.parent = deleted_node;
                } else {
                    self.transplant(deleted_node, deleted_node.right);
                    deleted_node.right = node.right;
                    if (deleted_node.right) |right| right.parent = deleted_node;
                }

                self.transplant(node, deleted_node);
                deleted_node.left = node.left;
                if (deleted_node.left) |left| left.parent = deleted_node;
                deleted_node.color = node.color;
            }

            // Fix red-black properties before freeing the node
            if (deleted_color == .black) {
                self.fixDelete(replacement);
            }

            self.allocator.destroy(node);
        }

        fn fixDelete(self: *Self, node: ?*Node) void {
            var current = node;

            while (current != self.root and Node.isBlack(current)) {
                if (current) |curr| {
                    const parent = curr.parent orelse break;

                    if (curr == parent.left) {
                        var sibling = parent.right;

                        if (Node.isRed(sibling)) {
                            if (sibling) |s| s.color = .black;
                            parent.color = .red;
                            self.rotateLeft(parent);
                            sibling = parent.right;
                        }

                        if (sibling) |s| {
                            if (Node.isBlack(s.left) and Node.isBlack(s.right)) {
                                s.color = .red;
                                current = parent;
                            } else {
                                if (Node.isBlack(s.right)) {
                                    if (s.left) |left| left.color = .black;
                                    s.color = .red;
                                    self.rotateRight(s);
                                    sibling = parent.right;
                                }

                                if (sibling) |new_s| {
                                    new_s.color = parent.color;
                                    parent.color = .black;
                                    if (new_s.right) |right| right.color = .black;
                                    self.rotateLeft(parent);
                                }
                                current = self.root;
                            }
                        }
                    } else {
                        var sibling = parent.left;

                        if (Node.isRed(sibling)) {
                            if (sibling) |s| s.color = .black;
                            parent.color = .red;
                            self.rotateRight(parent);
                            sibling = parent.left;
                        }

                        if (sibling) |s| {
                            if (Node.isBlack(s.right) and Node.isBlack(s.left)) {
                                s.color = .red;
                                current = parent;
                            } else {
                                if (Node.isBlack(s.left)) {
                                    if (s.right) |right| right.color = .black;
                                    s.color = .red;
                                    self.rotateLeft(s);
                                    sibling = parent.left;
                                }

                                if (sibling) |new_s| {
                                    new_s.color = parent.color;
                                    parent.color = .black;
                                    if (new_s.left) |left| left.color = .black;
                                    self.rotateRight(parent);
                                }
                                current = self.root;
                            }
                        }
                    }
                } else {
                    break;
                }
            }

            if (current) |c| c.color = .black;
        }

        fn transplant(self: *Self, old: *Node, new: ?*Node) void {
            if (old.parent == null) {
                self.root = new;
            } else if (old.parent) |parent| {
                if (old == parent.left) {
                    parent.left = new;
                } else {
                    parent.right = new;
                }
            }

            if (new) |n| n.parent = old.parent;
        }

        fn rotateLeft(self: *Self, node: *Node) void {
            const right = node.right orelse return;
            node.right = right.left;

            if (right.left) |left| left.parent = node;

            right.parent = node.parent;

            if (node.parent == null) {
                self.root = right;
            } else if (node.parent) |parent| {
                if (node == parent.left) {
                    parent.left = right;
                } else {
                    parent.right = right;
                }
            }

            right.left = node;
            node.parent = right;
        }

        fn rotateRight(self: *Self, node: *Node) void {
            const left = node.left orelse return;
            node.left = left.right;

            if (left.right) |right| right.parent = node;

            left.parent = node.parent;

            if (node.parent == null) {
                self.root = left;
            } else if (node.parent) |parent| {
                if (node == parent.right) {
                    parent.right = left;
                } else {
                    parent.left = left;
                }
            }

            left.right = node;
            node.parent = left;
        }

        /// Returns a pointer to the node containing the data.
        ///
        /// Returns `null` if the data is not found. The returned node pointer can be used
        /// to access or modify the data directly.
        ///
        /// Time complexity: O(log n)
        pub fn get(self: *const Self, data: T) ?*Node {
            var current = self.root;

            while (current) |node| {
                if (self.context.lessThan(data, node.data)) {
                    current = node.left;
                } else if (self.context.lessThan(node.data, data)) {
                    current = node.right;
                } else {
                    return node;
                }
            }

            return null;
        }

        /// Checks whether the tree contains the given value.
        ///
        /// Time complexity: O(log n)
        pub fn contains(self: *const Self, data: T) bool {
            return self.get(data) != null;
        }

        fn findMinimum(self: *const Self, node: *Node) *Node {
            _ = self; // Mark as intentionally unused
            var current = node;
            while (current.left) |left| {
                current = left;
            }
            return current;
        }

        pub fn minimum(self: Self, node: ?*Node) ?*Node {
            const start = node orelse self.root orelse return null;
            return self.findMinimum(start);
        }

        pub fn maximum(self: Self, node: ?*Node) ?*Node {
            var current = node orelse self.root orelse return null;

            while (current.right) |right| {
                current = right;
            }

            return current;
        }

        /// Iterator for in-order traversal
        pub const Iterator = struct {
            stack: std.ArrayList(*Node),
            allocator: Allocator,

            pub fn init(allocator: Allocator, root: ?*Node) !Iterator {
                var it = Iterator{
                    .stack = .{},
                    .allocator = allocator,
                };

                // Initialize stack with leftmost path
                var node = root;
                while (node) |n| {
                    try it.stack.append(allocator, n);
                    node = n.left;
                }

                return it;
            }

            pub fn deinit(self: *Iterator) void {
                self.stack.deinit(self.allocator);
            }

            pub fn next(self: *Iterator) !?*Node {
                if (self.stack.items.len == 0) return null;

                const node: *Node = self.stack.pop().?;

                // Add right subtree to stack
                var current = node.right;
                while (current) |n| {
                    try self.stack.append(self.allocator, n);
                    current = n.left;
                }

                return node;
            }
        };

        pub fn iterator(self: *const Self) !Iterator {
            return Iterator.init(self.allocator, self.root);
        }
    };
}

/// Default context for comparable types
pub fn DefaultContext(comptime T: type) type {
    return struct {
        pub fn lessThan(self: @This(), a: T, b: T) bool {
            _ = self;
            return a < b;
        }
    };
}

// Convenience type aliases
pub fn RedBlackTreeManaged(comptime T: type) type {
    return RedBlackTree(T, DefaultContext(T));
}

test "RedBlackTree: basic operations" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(10);
    try tree.put(20);
    try tree.put(5);

    try std.testing.expectEqual(@as(usize, 3), tree.count());
    try std.testing.expect(tree.contains(10));
    try std.testing.expect(tree.contains(5));
    try std.testing.expect(!tree.contains(99));
}

test "RedBlackTree: empty tree operations" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try std.testing.expect(!tree.contains(42));
    try std.testing.expectEqual(@as(usize, 0), tree.count());
    try std.testing.expect(tree.remove(42) == null);
}

test "RedBlackTree: single element" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(42);
    try std.testing.expectEqual(@as(usize, 1), tree.count());
    try std.testing.expect(tree.contains(42));
    try std.testing.expect(tree.root.?.color == .black);

    const removed = tree.remove(42);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(@as(usize, 0), tree.count());
    try std.testing.expect(tree.root == null);
}

test "RedBlackTree: duplicate insertions" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(10);
    try tree.put(10);
    try tree.put(10);

    // Duplicates update existing nodes
    try std.testing.expectEqual(@as(usize, 1), tree.count());
}

test "RedBlackTree: sequential insertion" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    var i: i32 = 0;
    while (i < 50) : (i += 1) {
        try tree.put(i);
    }

    try std.testing.expectEqual(@as(usize, 50), tree.count());
    try std.testing.expect(tree.root.?.color == .black);

    i = 0;
    while (i < 50) : (i += 1) {
        try std.testing.expect(tree.contains(i));
    }
}

test "RedBlackTree: reverse insertion" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    var i: i32 = 50;
    while (i > 0) : (i -= 1) {
        try tree.put(i);
    }

    try std.testing.expectEqual(@as(usize, 50), tree.count());
    try std.testing.expect(tree.root.?.color == .black);
}

test "RedBlackTree: remove from middle" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(10);
    try tree.put(5);
    try tree.put(15);
    try tree.put(3);
    try tree.put(7);

    const removed = tree.remove(5);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(@as(usize, 4), tree.count());
    try std.testing.expect(!tree.contains(5));
    try std.testing.expect(tree.contains(3));
    try std.testing.expect(tree.contains(7));
}

test "RedBlackTree: remove root" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(10);
    try tree.put(5);
    try tree.put(15);

    const removed = tree.remove(10);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(@as(usize, 2), tree.count());
    try std.testing.expect(tree.root.?.color == .black);
}

test "RedBlackTree: minimum and maximum" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(10);
    try tree.put(5);
    try tree.put(15);
    try tree.put(3);
    try tree.put(20);

    const min = tree.minimum(null);
    const max = tree.maximum(null);

    try std.testing.expect(min != null);
    try std.testing.expect(max != null);
    try std.testing.expectEqual(@as(i32, 3), min.?.data);
    try std.testing.expectEqual(@as(i32, 20), max.?.data);
}

test "RedBlackTree: iterator empty tree" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    var iter = try tree.iterator();
    defer iter.deinit();

    const node = try iter.next();
    try std.testing.expect(node == null);
}

test "RedBlackTree: clear" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(1);
    try tree.put(2);
    try tree.put(3);

    tree.clear();
    try std.testing.expectEqual(@as(usize, 0), tree.count());
    try std.testing.expect(tree.root == null);
}

test "RedBlackTree: negative numbers" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(-10);
    try tree.put(-5);
    try tree.put(0);
    try tree.put(5);

    try std.testing.expectEqual(@as(usize, 4), tree.count());
    try std.testing.expect(tree.contains(-10));
    try std.testing.expect(tree.contains(0));
}

test "RedBlackTree: get returns correct node" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree(i32, DefaultContext(i32)).init(allocator, .{});
    defer tree.deinit();

    try tree.put(10);
    try tree.put(20);

    const node = tree.get(10);
    try std.testing.expect(node != null);
    try std.testing.expectEqual(@as(i32, 10), node.?.data);
}
