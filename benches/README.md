### Benchmarks

| # | File                                                   | Description                   |
|---|--------------------------------------------------------|-------------------------------|
| 1 | [b1_btree_map.zig](b1_btree_map.zig)                   | Benchmarks for the B-tree map |
| 2 | [b2_sorted_set.zig](b2_sorted_set.zig)                 | Benchmarks the sorted set     |
| 3 | [b3_red_black_tree_set.zig](b3_red_black_tree_set.zig) | Benchmarks the red-black tree |
| 4 | [b4_skip_list_map.zig](b4_skip_list_map.zig)           | Benchmarks the skip list      |
| 5 | [b5_trie_map.zig](b5_trie_map.zig)                     | Benchmarks the trie           |
| 6 | [b6_cartesian_tree_map.zig](b6_cartesian_tree_map.zig) | Benchmarks the cartesian tree |

#### Running Benchmarks

To execute a benchmark, run the following command from the root of the repository:

```sh
zig build bench-{FILE_NAME_WITHOUT_EXTENSION}
```

For example:

```sh
zig build bench-b1_btree_map
```
