# Benchmarks

This directory contains performance benchmarks for all data structures in the `ordered` library.

## Running Benchmarks

Each benchmark can be run using the following command pattern:

```bash
zig build bench-<benchmark_name>
```

### Available Benchmarks

- **BTreeMap**: `zig build bench-btree_map_bench`
- **SortedSet**: `zig build bench-sorted_set_bench`
- **RedBlackTree**: `zig build bench-red_black_tree_bench`
- **SkipList**: `zig build bench-skip_list_bench`
- **Trie**: `zig build bench-trie_bench`
- **CartesianTree**: `zig build bench-cartesian_tree_bench`

## What Each Benchmark Tests

### BTreeMap Benchmark
- **Insert**: Sequential insertion of integers
- **Lookup**: Finding all inserted keys
- **Delete**: Removing all keys

### SortedSet Benchmark
- **Add**: Adding elements while maintaining sorted order
- **Contains**: Checking if elements exist
- **Remove**: Removing elements from the set

### RedBlackTree Benchmark
- **Insert**: Inserting nodes with self-balancing
- **Find**: Searching for nodes
- **Remove**: Deleting nodes while maintaining balance
- **Iterator**: In-order traversal performance

### SkipList Benchmark
- **Put**: Inserting key-value pairs with probabilistic levels
- **Get**: Retrieving values by key
- **Delete**: Removing key-value pairs

### Trie Benchmark
- **Put**: Inserting strings with associated values
- **Get**: Retrieving values by string key
- **Contains**: Checking if strings exist
- **Prefix Search**: Finding all keys with a common prefix

### CartesianTree Benchmark
- **Put**: Inserting key-value pairs with random priorities
- **Get**: Retrieving values by key
- **Remove**: Deleting nodes
- **Iterator**: In-order traversal performance

## Benchmark Sizes

Each benchmark tests with multiple dataset sizes:
- Small: 1,000 items
- Medium: 10,000 items
- Large: 50,000 - 100,000 items (varies by data structure)

## Build Configuration

Benchmarks are compiled with `ReleaseFast` optimization mode for accurate performance measurements.

## Example Output

```
=== BTreeMap Benchmark ===

Insert 1000 items: 0.42 ms (420 ns/op)
Lookup 1000 items: 0.18 ms (180 ns/op, found: 1000)
Delete 1000 items: 0.35 ms (350 ns/op)

Insert 10000 items: 5.23 ms (523 ns/op)
Lookup 10000 items: 2.10 ms (210 ns/op, found: 10000)
Delete 10000 items: 4.15 ms (415 ns/op)
```

## Notes

- All benchmarks use a simple integer or string key type for consistency
- Times are reported in both total milliseconds and nanoseconds per operation
- Memory allocations use `GeneralPurposeAllocator` for production-like behavior

