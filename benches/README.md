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
| 7 | [b7_std_comparison.zig](b7_std_comparison.zig)       | Timing comparisons with Zig standard-library containers |
| 8 | [b8_memory_comparison.zig](b8_memory_comparison.zig) | Memory comparisons with Zig standard-library containers |

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

#### Standard-Library Comparisons

The timing and memory runners compare `BTreeMap` (branching factor 16), `CartesianTreeMap`, and `SkipListMap`
(maximum level 16) with Zig's `std.Treap` and hash maps. Integer keys use `std.AutoHashMap`; string keys use
`std.StringHashMap`. Hash maps have unordered iteration and serve as baselines for workloads that do not require
ordering. The intrusive `std.Treap` uses a local adapter that allocates a node and stores a value for each key.
Allocation and freeing are included in insertion and removal timings.

```sh
# The complete default workloads, including batches of tiny maps.
make bench BENCHMARK=b7_std_comparison
make bench BENCHMARK=b8_memory_comparison

# A short validation run of every key and value combination.
make bench BENCHMARK=b7_std_comparison BENCH_ARGS=--quick
make bench BENCHMARK=b8_memory_comparison BENCH_ARGS=--quick

# Separate runs with 1M and 10M integer entries.
make bench BENCHMARK=b7_std_comparison BENCH_ARGS=--large
make bench BENCHMARK=b8_memory_comparison BENCH_ARGS=--large

# Every large timing case with one sample after one warmup.
make bench BENCHMARK=b7_std_comparison BENCH_ARGS='--large --quick'

# Equivalent direct Zig invocation.
zig build bench-b7_std_comparison -- --large
```

##### Workloads

| Mode | Entries per Map | Keys | Values | Tiny Maps |
|------|-----------------|------|--------|-----------|
| Default | 1,000, 10,000, and 100,000 | `u64`, 16-byte strings, and 100-byte strings | `u64` and 32-byte records | 10,000 maps each of 4 and 32 entries |
| `--quick` | 1,000 | Same as default | Same as default | 128 maps each of 4 and 32 entries |
| `--large` | 1,000,000 and 10,000,000 | `u64` | `u64` | None |
| `--large --quick` | Same as large | `u64` | `u64` | None |

All containers use `std.heap.smp_allocator` and ReleaseFast optimization for both the runner and imported library.
The large mode runs separately so routine benchmarks do not construct 10M-entry maps. String and larger-value
cases remain in the default workload. Tiny maps use 16-byte string keys and 32-byte records.

Present integer keys are even numbers, and absent keys are odd numbers interleaved among them; the final absent
key is just above the maximum present key. String keys encode those same numbers as fixed-width hexadecimal text.
The 100-byte case pads that text with a shared prefix, exercising comparisons of long common prefixes. These are
synthetic keys, rather than samples from real applications.

Each single-map workload runs with ascending and shuffled insertion orders. Lookup and removal each use a separate
permutation generated with a different fixed seed, regardless of insertion order. Every container receives the
same workload. Container priorities and skip-list levels use normal initialization and may vary between runs.
Key buffers and operation permutations are generated before measurement and kept alive until all containers finish.
Strings are borrowed from shared buffers; string payload allocation and copying are excluded.
Successful lookup and removal use separately stored, byte-identical string keys, so pointer equality cannot bypass
content comparison.

##### Timing Measurements

The timing runner measures insertion, successful lookup, unsuccessful lookup, full iteration, and removal. Lookups
use `getPtr` consistently, and successful lookups and iteration consume every word of the stored value. Result sums,
hit counts, removal counts, and container sizes are checked outside timed regions. Each phase runs once per map;
lookup, iteration, and removal follow insertion on the same populated container. Iterator creation and cleanup are
included in iteration time. Container initialization and final cleanup are excluded for single-map workloads.
Insertion and iteration visit every entry. Lookup and removal each visit at most 100,000 keys from their independent
permutations. Their timings are divided by the number of sampled keys, and the remaining entries are freed outside
the removal timer. This keeps large-map queries bounded while preserving the full working set. Default and quick
workloads visit every key because their maps fit within that limit.

Tiny-map workloads measure construction and destruction in nanoseconds per map, and iteration in nanoseconds per
item, while all maps coexist. Construction includes the map array allocation, initialization, and insertion;
destruction includes freeing all containers and the array. Maps share the same key buffers and insertion order.

Default and large timing runs report the median of five samples after one warmup. Adding `--quick`, including with
`--large`, uses one sample after one warmup for validation. CSV output goes to standard error, preceded by a metadata line. Tiny
results form a second section with their own header and timing columns.

##### Memory Measurements

The memory runner performs no timing. A counting allocator wraps `smp_allocator` during construction and records
live requested bytes after construction, peak requested bytes during construction, and live bytes per entry.
It includes each container's inline storage by allocating an array of containers, including for a single map.
Each workload is built once, and every measured allocation must be released after destruction.

Shared string buffers, operation permutations, allocator metadata, size-class rounding, reserved pages, and process
RSS are excluded. The string payload cost is shared equally by all containers, so string length alone does not
change reported container memory. Peak bytes describe allocations visible through Zig's allocator interface, not
internal temporary allocations made by the underlying allocator. Memory instrumentation is never used by the timing
runner. Repeated runs may differ for randomized containers.

##### Sample Results

The following results were measured on Linux x86_64 with an AMD Ryzen 9 9950X and Zig 0.17.0 on October 25, 2026,
using the native target. Each map held 100,000 shuffled `u64` keys and `u64` values. Timings are nanoseconds per
operation, except iteration, which is nanoseconds per item. Memory is live requested bytes per item from a separate
construction run, including inline container storage and excluding shared workload buffers.

| Container | Insert | Lookup Hit | Lookup Miss | Iteration | Remove | Bytes per Item |
|-----------|-------:|-----------:|------------:|----------:|-------:|---------------:|
| `BTreeMap` | 86.30 | 123.21 | 134.28 | 2.52 | 130.85 | 36.83 |
| `CartesianTreeMap` | 222.54 | 141.05 | 154.62 | 9.08 | 159.50 | 40.00 |
| `SkipListMap` | 195.68 | 202.16 | 197.31 | 18.43 | 194.13 | 47.99 |
| `std.Treap` | 137.92 | 102.40 | 102.92 | 15.26 | 129.29 | 48.00 |
| `std.AutoHashMap` (unordered) | 29.11 | 10.61 | 19.91 | 2.43 | 11.60 | 22.28 |

##### Validation and Limits

`make test` includes benchmark tests for adapters, both value sizes, both string lengths, independent permutations,
interleaved misses, duplicate updates, missing removals, empty iteration, allocator accounting, and cleanup after
allocation failures. A workload above the query limit checks sampled lookups and partial removal. `make lint`
includes benchmark sources and `build.zig`.

Measurements are single-threaded, with no CPU pinning or frequency control. This suite does not measure concurrent
access, interleaved mutations, prefix queries, or range scans. It adds no external dependencies and includes no Rust
or C libraries. Results from the earlier `u32` comparison are not comparable with these workloads and have been
removed from this document.
