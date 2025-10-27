### Ordered Benchmarks

#### Available Benchmarks

| # | File                                                   | Description                                      |
|---|--------------------------------------------------------|--------------------------------------------------|
| 1 | [b1_btree_map.zig](b1_btree_map.zig)                   | Benchmarks for B-tree map implementation         |
| 2 | [b2_sorted_set.zig](b2_sorted_set.zig)                 | Benchmarks for Sorted set implementation         |
| 3 | [b3_red_black_tree_set.zig](b3_red_black_tree_set.zig) | Benchmarks for Red-black tree set implementation |
| 4 | [b4_skip_list_map.zig](b4_skip_list_map.zig)           | Benchmarks for Skip list map implementation      |
| 5 | [b5_trie_map.zig](b5_trie_map.zig)                     | Benchmarks for Trie map implementation           |
| 6 | [b6_cartesian_tree_map.zig](b6_cartesian_tree_map.zig) | Benchmarks for Cartesian tree map implementation |

#### Running Benchmarks

To execute a specific benchmark, run:

```sh
zig build bench-{FILE_NAME_WITHOUT_EXTENSION}
```

For example:

```sh
zig build bench-b1_btree_map
```

> [!NOTE]
> Each benchmark measures three core operations across multiple data sizes:
> 1. **Insert and Put**: measures the time to insert elements sequentially into an empty data structure
> 2. **Lookup**: measures the time to search for all elements in a pre-populated structure
> 3. **Delete**: measures the time to remove all elements from a pre-populated structure
>
> **Test Sizes**: benchmarks run with 1,000, 10,000, 100,000, and 1,000,000 elements to show performance scaling.
>
> **Timing Method**: uses `std.time.Timer` for high-precision nanosecond-level timing. Each operation is timed in bulk,
> then divided by the number of operations to get per-operation timing.
>
> **Compilation**: benchmarks are compiled with `ReleaseFast` optimization (see [build.zig](../build.zig)).
