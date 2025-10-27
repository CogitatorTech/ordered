//! The `ordered` library provides a collection of data structures that maintain
//! their elements in sorted order.
//!
//! ## Sets (store values only)
//! - `SortedSet`: An ArrayList that maintains sort order on insertion.
//! - `RedBlackTreeSet`: A self-balancing binary search tree for ordered sets.
//!
//! ## Maps (store key-value pairs)
//! - `BTreeMap`: A cache-efficient B-tree for mapping sorted keys to values.
//! - `SkipListMap`: A probabilistic data structure for ordered key-value storage.
//! - `TrieMap`: A prefix tree for efficient string key operations and prefix matching.
//! - `CartesianTreeMap`: A randomized treap combining BST and heap properties.
//!
//! ## Common API
//! All map structures provide similar methods:
//! - `init(allocator)` - Create new instance
//! - `deinit()` - Free all memory
//! - `count()` - Get number of elements
//! - `contains(key)` - Check if key exists
//! - `get(key)` - Get immutable value
//! - `getPtr(key)` - Get mutable value pointer
//! - `put(key, value)` - Insert or update
//! - `remove(key)` - Remove and return value
//! - `iterator()` - Iterate in order
//!
//! Set structures use similar API but store only values (no separate key):
//! - `put(value)` - Insert value (returns bool for duplicate detection)
//! - `contains(value)` - Check if value exists
//! - `remove(index)` or `removeValue(value)` - Remove value
//! - `iterator()` - Iterate in sorted order

pub const SortedSet = @import("ordered/sorted_set.zig").SortedSet;
pub const RedBlackTreeSet = @import("ordered/red_black_tree_set.zig").RedBlackTreeSet;

pub const BTreeMap = @import("ordered/btree_map.zig").BTreeMap;
pub const SkipListMap = @import("ordered/skip_list_map.zig").SkipListMap;
pub const TrieMap = @import("ordered/trie_map.zig").TrieMap;
pub const CartesianTreeMap = @import("ordered/cartesian_tree_map.zig").CartesianTreeMap;

test {
    @import("std").testing.refAllDecls(@This());
}
