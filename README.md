<div align="center">
  <picture>
    <img alt="Ordered Logo" src="logo.svg" height="20%" width="20%">
  </picture>
<br>

<h2>Ordered</h2>

[![Tests](https://img.shields.io/github/actions/workflow/status/CogitatorTech/ordered/tests.yml?label=tests&style=flat&labelColor=282c34&logo=github)](https://github.com/CogitatorTech/ordered/actions/workflows/tests.yml)
[![Benchmarks](https://img.shields.io/github/actions/workflow/status/CogitatorTech/ordered/benches.yml?label=benchmarks&style=flat&labelColor=282c34&logo=github)](https://github.com/CogitatorTech/ordered/actions/workflows/benches.yml)
[![CodeFactor](https://img.shields.io/codefactor/grade/github/CogitatorTech/ordered?label=quality&style=flat&labelColor=282c34&logo=codefactor)](https://www.codefactor.io/repository/github/CogitatorTech/ordered)
[![Zig Version](https://img.shields.io/badge/Zig-0.15.2-orange?logo=zig&labelColor=282c34)](https://ziglang.org/download/)
<br>
[![Docs](https://img.shields.io/badge/docs-view-blue?style=flat&labelColor=282c34&logo=read-the-docs)](https://CogitatorTech.github.io/ordered/)
[![Examples](https://img.shields.io/badge/examples-view-green?style=flat&labelColor=282c34&logo=zig)](https://github.com/CogitatorTech/ordered/tree/main/examples)
[![Release](https://img.shields.io/github/release/CogitatorTech/ordered.svg?label=release&style=flat&labelColor=282c34&logo=github)](https://github.com/CogitatorTech/ordered/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-007ec6?label=license&style=flat&labelColor=282c34&logo=open-source-initiative)](https://github.com/CogitatorTech/ordered/blob/main/LICENSE)

A sorted collection library (sorted sets and sorted maps) for Zig

</div>

---

Ordered is a Zig library that provides fast and efficient implementations of various data structures that keep elements
sorted (AKA sorted collections).
It is written in pure Zig and has no external dependencies.
Ordered is inspired by [Java collections](https://en.wikipedia.org/wiki/Java_collections_framework) and sorted
containers in the [C++ standard library](https://en.cppreference.com/w/cpp/container), and aims to provide a similar
experience in Zig.

### Features

- Simple and uniform API for all data structures
- Pure Zig implementations with no external dependencies
- Fast, cache-friendly, and memory-efficient implementations (see [benches](benches))

### Data Structures

Ordered provides two main interfaces for working with sorted collections: *sorted maps* and *sorted sets*.
At the moment, Ordered supports the following implementations of these interfaces:

#### Maps (key-value)

| Type               | Data Structure                                       | Insert       | Search       | Delete       | Space          |
|--------------------|------------------------------------------------------|--------------|--------------|--------------|----------------|
| `BTreeMap`         | [B-tree](https://en.wikipedia.org/wiki/B-tree)       | $O(\log n)$  | $O(\log n)$  | $O(\log n)$  | $O(n)$         |
| `SkipListMap`      | [Skip list](https://en.wikipedia.org/wiki/Skip_list) | $O(\log n)$† | $O(\log n)$† | $O(\log n)$† | $O(n)$         |
| `TrieMap`          | [Trie](https://en.wikipedia.org/wiki/Trie)           | $O(m)$       | $O(m)$       | $O(m)$       | $O(n \cdot m)$ |
| `CartesianTreeMap` | [Treap](https://en.wikipedia.org/wiki/Treap)         | $O(\log n)$† | $O(\log n)$† | $O(\log n)$† | $O(n)$         |

#### Sets (value-only)

| Type              | Data Structure                                                 | Insert      | Search      | Delete      | Space  |
|-------------------|----------------------------------------------------------------|-------------|-------------|-------------|--------|
| `SortedSet`       | [Sorted array](https://en.wikipedia.org/wiki/Sorted_array)     | $O(n)$      | $O(\log n)$ | $O(n)$      | $O(n)$ |
| `RedBlackTreeSet` | [Red-black tree](https://en.wikipedia.org/wiki/Red-black_tree) | $O(\log n)$ | $O(\log n)$ | $O(\log n)$ | $O(n)$ |

- $n$ = number of elements stored
- $m$ = length of the key (for string-based keys)
- † = average case complexity (the worst case is $O(n)$)

See the [ROADMAP.md](ROADMAP.md) for the list of implemented and planned features.

> [!IMPORTANT]
> Ordered is in early development, so bugs and breaking API changes are expected.
> Please use the [issues page](https://github.com/CogitatorTech/ordered/issues) to report bugs or request features.

---

### Getting Started

You can add Ordered to your project and start using it by following the steps below.

#### Installation

Run the following command in the root directory of your project to download Ordered:

```sh
zig fetch --save=ordered "https://github.com/CogitatorTech/ordered/archive/<branch_or_tag>.tar.gz"
```

Replace `<branch_or_tag>` with the desired branch or release tag, like `main` (for the development version) or `v0.1.0`.
This command will download Ordered and add it to Zig's global cache and update your project's `build.zig.zon` file.

#### Adding to Build Script

Next, modify your `build.zig` file to make Ordered available to your build target as a module.

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Get the dependency object from the builder
    const ordered_dep = b.dependency("ordered", .{});

    // 2. Create a module for the dependency
    const ordered_module = ordered_dep.module("ordered");

    // 3. Create your executable module and add ordered as import
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_module.addImport("ordered", ordered_module);

    // 4. Create executable with the module
    const exe = b.addExecutable(.{
        .name = "your-application",
        .root_module = exe_module,
    });

    b.installArtifact(exe);
}
```

#### Using Ordered in Your Project

Finally, you can `@import("ordered")` and start using it in your Zig code.

```zig
const std = @import("std");
const ordered = @import("ordered");

// Define a comparison function for the keys.
// The function must return a `std.math.Order` value based on the comparison of the two keys
fn strCompare(lhs: []const u8, rhs: []const u8) std.math.Order {
    return std.mem.order(u8, lhs, rhs);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("## BTreeMap Example ##\n", .{});
    const B = 4; // Branching Factor for B-tree
    var map = ordered.BTreeMap([]const u8, u32, strCompare, B).init(allocator);
    defer map.deinit();

    try map.put("banana", 150);
    try map.put("apple", 100);
    try map.put("cherry", 200);

    const key_to_find = "apple";
    if (map.get(key_to_find)) |value_ptr| {
        std.debug.print("Found key '{s}': value is {d}\n", .{ key_to_find, value_ptr.* });
    }

    const removed = map.remove("banana");
    std.debug.print("Removed 'banana' with value: {?d}\n", .{if (removed) |v| v else null});
    std.debug.print("Contains 'banana' after remove? {any}\n", .{map.contains("banana")});
    std.debug.print("Map count: {d}\n\n", .{map.count()});
}
```

---

### Documentation

You can find the API documentation for the latest release of Ordered [here](https://CogitatorTech.github.io/ordered/).

Alternatively, you can use the `make docs` command to generate the documentation for the current version of Ordered.
This will generate HTML documentation in the `docs/api` directory, which you can serve locally with `make serve-docs`
and view in a web browser.

### Examples

Check out the [examples](examples) directory for example usages of Ordered.

### Benchmarks

Check out the [benchmarks](benches) directory for local benchmarks.

---

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to make a contribution.

### License

Ordered is licensed under the MIT License (see [LICENSE](LICENSE)).

### Acknowledgements

* The logo is from [SVG Repo](https://www.svgrepo.com/svg/469537/zig-zag-left-right-arrow) with some modifications.
