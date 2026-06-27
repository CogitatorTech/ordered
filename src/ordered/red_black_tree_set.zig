//! Red-black tree - A self-balancing binary search tree.
//!
//! Red-black trees guarantee O(log n) time complexity for insert, delete, and search
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
//! WARNING: Modifying the tree (via put, remove, or clear) while iterating will
//! cause undefined behavior. Complete all iterations before modifying the structure.

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const assert = std.debug.assert;

/// Creates a Red-black tree type for the given data type and key-comparison function.
///
/// The `compare` function is the same three-way comparator used by every other
/// generic-key container in the library (`BTreeMap`, `SkipListMap`, `SortedSet`,
/// and `CartesianTreeMap`), so tree types compose uniformly.
///
/// ## Parameters
/// - `T`: The data type to store in the tree
/// - `compare`: Three-way comparison function returning `std.math.Order`
///
/// ## Example
/// ```zig
/// fn i32Order(a: i32, b: i32) std.math.Order { return std.math.order(a, b); }
/// var tree = RedBlackTreeSet(i32, i32Order).init(allocator);
/// ```
pub fn RedBlackTreeSet(
    comptime T: type,
    comptime compare: fn (lhs: T, rhs: T) std.math.Order,
) type {
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
        size: usize,

        /// Creates a new empty Red-black tree.
        ///
        /// ## Parameters
        /// - `allocator`: Memory allocator for node allocation
        pub fn init(allocator: Allocator) Self {
            return Self{
                .root = null,
                .allocator = allocator,
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
        /// If the value already exists (as determined by the `compare` function),
        /// it will be updated. Otherwise, a new node is created.
        ///
        /// Time complexity: O(log n)
        ///
        /// ## Errors
        /// Returns `error.OutOfMemory` if node allocation fails.
        pub fn put(self: *Self, data: T) !void {
            // Check if key already exists first to avoid unnecessary allocation
            if (self.getNode(data)) |existing| {
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
                if (compare(data, current.?.data) == .lt) {
                    current = current.?.left;
                } else {
                    current = current.?.right;
                }
            }

            new_node.parent = parent;
            if (compare(data, parent.?.data) == .lt) {
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
            const node = self.getNode(data) orelse return null;
            const value = node.data;
            self.removeNode(node);
            self.size -= 1;
            return value;
        }

        fn removeNode(self: *Self, node: *Node) void {
            // `replacement` is the node (possibly null) that moves into the
            // spliced-out position; `replacement_parent` records its parent
            // explicitly. The parent is needed because, without a NIL sentinel,
            // a null replacement carries no parent pointer of its own, and
            // `fixDelete` must still know where in the tree to start rebalancing.
            var deleted_color = node.color;
            var replacement: ?*Node = null;
            var replacement_parent: ?*Node = null;

            if (node.left == null) {
                replacement = node.right;
                replacement_parent = node.parent;
                self.transplant(node, node.right);
            } else if (node.right == null) {
                replacement = node.left;
                replacement_parent = node.parent;
                self.transplant(node, node.left);
            } else {
                const successor = self.findMinimum(node.right.?);
                deleted_color = successor.color;
                replacement = successor.right;

                if (successor.parent == node) {
                    // The successor moves into `node`'s slot, so it becomes the
                    // parent of its own right child (the replacement).
                    replacement_parent = successor;
                } else {
                    replacement_parent = successor.parent;
                    self.transplant(successor, successor.right);
                    successor.right = node.right;
                    if (successor.right) |right| right.parent = successor;
                }

                self.transplant(node, successor);
                successor.left = node.left;
                if (successor.left) |left| left.parent = successor;
                successor.color = node.color;
            }

            // Fix red-black properties before freeing the node.
            if (deleted_color == .black) {
                self.fixDelete(replacement, replacement_parent);
            }

            self.allocator.destroy(node);
        }

        fn fixDelete(self: *Self, node: ?*Node, node_parent: ?*Node) void {
            var current = node;
            // Tracked explicitly so the loop can advance even while `current`
            // is null (a doubly-black NIL position). In a valid red-black tree
            // a black, non-root node always has a sibling, so the sibling
            // lookups below never dereference null.
            var parent = node_parent;

            while (current != self.root and Node.isBlack(current)) {
                const p = parent.?;

                if (current == p.left) {
                    var sibling = p.right.?;

                    if (sibling.color == .red) {
                        sibling.color = .black;
                        p.color = .red;
                        self.rotateLeft(p);
                        sibling = p.right.?;
                    }

                    if (Node.isBlack(sibling.left) and Node.isBlack(sibling.right)) {
                        sibling.color = .red;
                        current = p;
                        parent = p.parent;
                    } else {
                        if (Node.isBlack(sibling.right)) {
                            if (sibling.left) |left| left.color = .black;
                            sibling.color = .red;
                            self.rotateRight(sibling);
                            sibling = p.right.?;
                        }

                        sibling.color = p.color;
                        p.color = .black;
                        if (sibling.right) |right| right.color = .black;
                        self.rotateLeft(p);
                        current = self.root;
                    }
                } else {
                    var sibling = p.left.?;

                    if (sibling.color == .red) {
                        sibling.color = .black;
                        p.color = .red;
                        self.rotateRight(p);
                        sibling = p.left.?;
                    }

                    if (Node.isBlack(sibling.right) and Node.isBlack(sibling.left)) {
                        sibling.color = .red;
                        current = p;
                        parent = p.parent;
                    } else {
                        if (Node.isBlack(sibling.left)) {
                            if (sibling.right) |right| right.color = .black;
                            sibling.color = .red;
                            self.rotateLeft(sibling);
                            sibling = p.left.?;
                        }

                        sibling.color = p.color;
                        p.color = .black;
                        if (sibling.left) |left| left.color = .black;
                        self.rotateRight(p);
                        current = self.root;
                    }
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
            // Left rotation requires the node to have a right child; callers
            // in `fixInsert` / `fixDelete` must preserve this precondition.
            // Previously this silently bailed out with `orelse return`, which
            // could mask a balancing bug by leaving the tree in a subtly
            // wrong shape.
            std.debug.assert(node.right != null);
            const right = node.right.?;
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
            // Right rotation requires the node to have a left child. See
            // note in `rotateLeft` for why this is an assertion rather than
            // a silent early return.
            std.debug.assert(node.left != null);
            const left = node.left.?;
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

        /// Returns an immutable pointer to the stored value that compares equal
        /// to `data`, or `null` if no such value exists.
        ///
        /// Time complexity: O(log n)
        pub fn get(self: *const Self, data: T) ?*const T {
            const node = self.getNode(data) orelse return null;
            return &node.data;
        }

        /// Checks whether the tree contains the given value.
        ///
        /// Time complexity: O(log n)
        pub fn contains(self: *const Self, data: T) bool {
            return self.getNode(data) != null;
        }

        /// Internal: returns the node pointer for mutation by `put` and `remove`.
        fn getNode(self: *const Self, data: T) ?*Node {
            var current = self.root;

            while (current) |node| {
                switch (compare(data, node.data)) {
                    .lt => current = node.left,
                    .gt => current = node.right,
                    .eq => return node,
                }
            }

            return null;
        }

        fn findMinimum(self: *const Self, node: *Node) *Node {
            _ = self; // Mark as intentionally unused
            var current = node;
            while (current.left) |left| {
                current = left;
            }
            return current;
        }

        /// Returns the smallest value in the tree, or `null` if the tree is empty.
        ///
        /// Time complexity: O(log n)
        pub fn minimum(self: *const Self) ?T {
            const start = self.root orelse return null;
            return self.findMinimum(start).data;
        }

        /// Returns the largest value in the tree, or `null` if the tree is empty.
        ///
        /// Time complexity: O(log n)
        pub fn maximum(self: *const Self) ?T {
            var current = self.root orelse return null;

            while (current.right) |right| {
                current = right;
            }

            return current.data;
        }

        /// Iterator for in-order traversal
        pub const Iterator = struct {
            stack: std.ArrayList(*Node),
            allocator: Allocator,

            pub fn init(allocator: Allocator, root: ?*Node) !Iterator {
                var it = Iterator{
                    .stack = .empty,
                    .allocator = allocator,
                };
                // Seeding the stack with the leftmost path issues a loop of
                // appends. Without this errdefer, an OOM on the second or
                // later append drops `it` without freeing its heap buffer.
                errdefer it.stack.deinit(allocator);

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

            pub fn next(self: *Iterator) !?T {
                if (self.stack.items.len == 0) return null;

                const node: *Node = self.stack.pop().?;

                // Add right subtree to stack
                var current = node.right;
                while (current) |n| {
                    try self.stack.append(self.allocator, n);
                    current = n.left;
                }

                return node.data;
            }
        };

        pub fn iterator(self: *const Self) !Iterator {
            return Iterator.init(self.allocator, self.root);
        }
    };
}

fn i32Compare(lhs: i32, rhs: i32) std.math.Order {
    return std.math.order(lhs, rhs);
}

const SetOracle = @import("oracle.zig").SetOracle;

test "RedBlackTreeSet: differential test against sorted-array oracle" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    var oracle: SetOracle(i32, i32Compare) = .{};
    defer oracle.deinit(allocator);

    // Fixed seed keeps the operation sequence deterministic across runs.
    var prng = std.Random.DefaultPrng.init(0x1234_5678_9abc_def0);
    const random = prng.random();

    const operations = 3000;
    // A small key space forces frequent duplicate puts and removals of present
    // values, exercising the rebalancing paths rather than only growth.
    const key_space: u32 = 200;

    var op: usize = 0;
    while (op < operations) : (op += 1) {
        const value: i32 = @intCast(random.uintLessThan(u32, key_space));

        // Roughly one removal for every two insertions, so the tree grows and
        // then churns instead of only filling up.
        if (random.uintLessThan(u32, 3) == 0) {
            const tree_removed = tree.remove(value);
            const oracle_removed = oracle.remove(value);
            try std.testing.expectEqual(oracle_removed, tree_removed != null);
            if (tree_removed) |v| try std.testing.expectEqual(value, v);
        } else {
            try tree.put(value);
            try oracle.put(allocator, value);
        }

        // Cheap invariants checked on every operation: the count must agree, the
        // touched value's membership must agree, and in-order iteration must
        // reproduce the oracle's sorted order exactly.
        try std.testing.expectEqual(oracle.count(), tree.count());
        try std.testing.expectEqual(oracle.contains(value), tree.contains(value));
        try expectIterationMatches(&tree, &oracle);

        // The full key-space membership sweep is O(key_space) per check, so run
        // it periodically rather than on every operation to keep the test fast.
        if (op % 100 == 0) {
            var k: i32 = 0;
            while (k < @as(i32, @intCast(key_space))) : (k += 1) {
                try std.testing.expectEqual(oracle.contains(k), tree.contains(k));
            }
        }
    }

    // Final full sweep after the last operation.
    var k: i32 = 0;
    while (k < @as(i32, @intCast(key_space))) : (k += 1) {
        try std.testing.expectEqual(oracle.contains(k), tree.contains(k));
    }
}

/// Asserts that a tree's in-order iteration reproduces the oracle's sorted
/// values exactly, in the same order and with the same length.
fn expectIterationMatches(
    tree: *const RedBlackTreeSet(i32, i32Compare),
    oracle: *const SetOracle(i32, i32Compare),
) !void {
    var iter = try tree.iterator();
    defer iter.deinit();
    var idx: usize = 0;
    while (try iter.next()) |item| : (idx += 1) {
        try std.testing.expect(idx < oracle.items.items.len);
        try std.testing.expectEqual(oracle.items.items[idx], item);
    }
    try std.testing.expectEqual(oracle.items.items.len, idx);
}

test "RedBlackTreeSet: basic operations" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try tree.put(10);
    try tree.put(20);
    try tree.put(5);

    try std.testing.expectEqual(@as(usize, 3), tree.count());
    try std.testing.expect(tree.contains(10));
    try std.testing.expect(tree.contains(5));
    try std.testing.expect(!tree.contains(99));
}

test "RedBlackTreeSet: empty tree operations" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try std.testing.expect(!tree.contains(42));
    try std.testing.expectEqual(@as(usize, 0), tree.count());
    try std.testing.expect(tree.remove(42) == null);
}

test "RedBlackTreeSet: single element" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
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

test "RedBlackTreeSet: duplicate insertions" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try tree.put(10);
    try tree.put(10);
    try tree.put(10);

    // Duplicates update existing nodes
    try std.testing.expectEqual(@as(usize, 1), tree.count());
}

test "RedBlackTreeSet: sequential insertion" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
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

test "RedBlackTreeSet: reverse insertion" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    var i: i32 = 50;
    while (i > 0) : (i -= 1) {
        try tree.put(i);
    }

    try std.testing.expectEqual(@as(usize, 50), tree.count());
    try std.testing.expect(tree.root.?.color == .black);
}

test "RedBlackTreeSet: remove from middle" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
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

test "RedBlackTreeSet: remove root" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try tree.put(10);
    try tree.put(5);
    try tree.put(15);

    const removed = tree.remove(10);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(@as(usize, 2), tree.count());
    try std.testing.expect(tree.root.?.color == .black);
}

test "RedBlackTreeSet: minimum and maximum" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try tree.put(10);
    try tree.put(5);
    try tree.put(15);
    try tree.put(3);
    try tree.put(20);

    const min = tree.minimum();
    const max = tree.maximum();

    try std.testing.expect(min != null);
    try std.testing.expect(max != null);
    try std.testing.expectEqual(@as(i32, 3), min.?);
    try std.testing.expectEqual(@as(i32, 20), max.?);
}

test "RedBlackTreeSet: iterator empty tree" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    var iter = try tree.iterator();
    defer iter.deinit();

    const node = try iter.next();
    try std.testing.expect(node == null);
}

test "RedBlackTreeSet: clear" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try tree.put(1);
    try tree.put(2);
    try tree.put(3);

    tree.clear();
    try std.testing.expectEqual(@as(usize, 0), tree.count());
    try std.testing.expect(tree.root == null);
}

test "RedBlackTreeSet: negative numbers" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try tree.put(-10);
    try tree.put(-5);
    try tree.put(0);
    try tree.put(5);

    try std.testing.expectEqual(@as(usize, 4), tree.count());
    try std.testing.expect(tree.contains(-10));
    try std.testing.expect(tree.contains(0));
}

test "RedBlackTreeSet: get returns correct value" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTreeSet(i32, i32Compare).init(allocator);
    defer tree.deinit();

    try tree.put(10);
    try tree.put(20);

    const ptr = tree.get(10);
    try std.testing.expect(ptr != null);
    try std.testing.expectEqual(@as(i32, 10), ptr.?.*);

    try std.testing.expect(tree.get(99) == null);
}

const RbTreeI32 = RedBlackTreeSet(i32, i32Compare);

/// Returns the black height of a subtree while asserting the structural
/// red-black invariants: no red node has a red child, and every root-to-leaf
/// path through the subtree passes through the same number of black nodes. A
/// missing rebalance on deletion shows up here as unequal child black heights.
fn rbBlackHeight(node: ?*const RbTreeI32.Node) !usize {
    const n = node orelse return 1; // NIL nodes are black.
    if (n.color == .red) {
        if (n.left) |l| try std.testing.expect(l.color == .black);
        if (n.right) |r| try std.testing.expect(r.color == .black);
    }
    const left_height = try rbBlackHeight(n.left);
    const right_height = try rbBlackHeight(n.right);
    try std.testing.expectEqual(left_height, right_height);
    return left_height + @as(usize, if (n.color == .black) 1 else 0);
}

fn expectRbInvariants(tree: *const RbTreeI32) !void {
    if (tree.root) |r| try std.testing.expect(r.color == .black); // The root is black.
    _ = try rbBlackHeight(tree.root);
}

test "regression: RedBlackTreeSet deletion preserves red-black invariants" {
    // Bug found by the differential oracle: deleting a black node passed a null
    // replacement to `fixDelete`, which (with no NIL sentinel) could not find its
    // parent and skipped rebalancing. The tree stayed a valid BST, so ordering
    // and count looked fine, but its black heights drifted out of balance and a
    // later deletion drove `fixDelete` into an infinite loop. Checking the
    // red-black invariants after each deletion catches the missing rebalance
    // directly, at the first offending black-node removal.
    const allocator = std.testing.allocator;
    var tree = RbTreeI32.init(allocator);
    defer tree.deinit();

    const n: i32 = 64;
    // Insert and delete in fixed permutations (multipliers coprime to 64), so the
    // schedule is fully deterministic and reproducible.
    var i: i32 = 0;
    while (i < n) : (i += 1) try tree.put(@mod(i * 37, n));
    try std.testing.expectEqual(@as(usize, @intCast(n)), tree.count());
    try expectRbInvariants(&tree);

    i = 0;
    while (i < n) : (i += 1) {
        const key = @mod(i * 29, n);
        try std.testing.expect(tree.remove(key) != null);
        try std.testing.expect(!tree.contains(key));
        try std.testing.expectEqual(@as(usize, @intCast(n - 1 - i)), tree.count());
        try expectRbInvariants(&tree);
    }
    try std.testing.expectEqual(@as(usize, 0), tree.count());
}
