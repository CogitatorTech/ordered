//! The `ordered` library provides a collection of data structures that maintain
//! their elements in sorted order.
//!
//! Available Structures:
//! - `SortedSet`: An ArrayList that maintains sort order on insertion.
//! - `BTreeMap`: A cache-efficient B-Tree for mapping sorted keys to values.
//! - `SkipList`: A probabilistic data structure that maintains sorted order
//!   using multiple linked lists.
//! - `Trie`: A prefix tree for efficient string operations and prefix matching.
//! - `Red-Black Tree`: A self-balancing binary search tree.
//! - `Cartesian Tree`: A binary tree that maintains heap order based on a
//!   secondary key, useful for priority queues.

pub const SortedSet = @import("ordered/sorted_set.zig").SortedSet;
pub const BTreeMap = @import("ordered/btree_map.zig").BTreeMap;
pub const SkipList = @import("ordered/skip_list.zig").SkipList;
pub const Trie = @import("ordered/trie.zig").Trie;
pub const RedBlackTree = @import("ordered/red_black_tree.zig").RedBlackTree;
pub const CartesianTree = @import("ordered/cartesian_tree.zig").CartesianTree;

test {
    @import("std").testing.refAllDecls(@This());
}
