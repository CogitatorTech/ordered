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
| 7 | [b7_std_comparison.zig](b7_std_comparison.zig)       | Integer maps compared with Zig standard-library containers |

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
> The individual container benchmarks measure core operations across multiple data sizes:
> 1. **Insert and Put**: measures the time to insert elements sequentially into an empty data structure
> 2. **Lookup**: measures the time to search for all elements in a pre-populated structure
> 3. **Delete**: measures the time to remove all elements from a pre-populated structure
>
> **Test Sizes**: benchmarks run with 1,000, 10,000, 100,000, and 1,000,000 elements to show performance scaling.
>
> **Timing Method**: uses the local timer backed by `std.Io.Timestamp` on the monotonic `.real` clock. Each operation is timed in bulk,
> then divided by the number of operations to get per-operation timing.
>
> **Compilation**: benchmarks are compiled with `ReleaseFast` optimization (see [build.zig](../build.zig)).

#### Standard-Library Comparison

```sh
make bench BENCHMARK=b7_std_comparison
```

This benchmark compares `BTreeMap` (branching factor 16), `CartesianTreeMap`, and `SkipListMap` (maximum level 16)
with `std.Treap` and `std.AutoHashMap`. The hash map does not provide sorted iteration, so its results are a baseline
for workloads that do not need ordering. The intrusive `std.Treap` has a local adapter that allocates a node and
stores a value for each key, including allocation and freeing in the measured insertion and removal times.

All containers use `u32` keys and values, `std.heap.smp_allocator`, and ReleaseFast optimization for both the runner
and the imported library. Each case reports the median of five runs after one warmup, at 1,000, 10,000, and 100,000
elements. Keys are unique integers from zero to the size minus one. Insertion, lookup, and removal use either
ascending keys or the same shuffled permutation, generated with a fixed seed. Container priorities and skip-list
levels use their normal initialization and can differ between runs.

Successful lookups and iteration consume the stored values and check their sums after timing. Unsuccessful lookups
use keys above the maximum stored key, which favors trees that quickly reject that range. Removal counts and final
container sizes are also checked. Duplicate updates, missing removals, empty iteration, and cleanup are checked with
the debug allocator before timing. Iteration includes iterator creation and cleanup; container initialization and
final cleanup are excluded from the operation timings. CSV rows are written to standard error.

##### Sample Results

The following results were measured on Linux x86_64 with an AMD Ryzen 9 9950X and Zig 0.17.0 on October 25, 2026,
using the native target. Values are nanoseconds per operation for 100,000 shuffled keys, except iteration, which is
nanoseconds per item.

| Container | Insert | Lookup Hit | Lookup Miss | Iteration | Remove |
|-----------|-------:|-----------:|------------:|----------:|-------:|
| `BTreeMap` | 66.63 | 105.15 | 29.90 | 2.11 | 108.39 |
| `CartesianTreeMap` | 191.65 | 122.15 | 7.08 | 8.11 | 123.50 |
| `SkipListMap` | 172.16 | 177.46 | 10.74 | 16.48 | 168.18 |
| `std.Treap` | 117.01 | 80.66 | 12.44 | 14.25 | 99.12 |
| `std.AutoHashMap` (unordered) | 20.28 | 8.06 | 13.56 | 2.01 | 6.86 |

These are local measurements, with no CPU pinning or frequency control. The phases run consecutively on the same
container, so lookup and iteration measure a populated container with recently accessed data. This suite does not
measure memory usage, string keys, interleaved mutations, or prefix and range queries. It adds no external
dependencies; C and third-party Zig libraries are not included.
