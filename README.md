<div align="center">
  <picture>
    <img alt="Ordered Logo" src="logo.svg" height="20%" width="20%">
  </picture>
<br>

<h2>Ordered</h2>

[![Tests](https://img.shields.io/github/actions/workflow/status/CogitatorTech/ordered/tests.yml?label=tests&style=flat&labelColor=282c34&logo=github)](https://github.com/CogitatorTech/ordered/actions/workflows/tests.yml)
[![Benchmarks](https://img.shields.io/github/actions/workflow/status/CogitatorTech/ordered/benches.yml?label=benches&style=flat&labelColor=282c34&logo=github)](https://github.com/CogitatorTech/ordered/actions/workflows/benches.yml)
[![CodeFactor](https://img.shields.io/codefactor/grade/github/CogitatorTech/ordered?label=quality&style=flat&labelColor=282c34&logo=codefactor)](https://www.codefactor.io/repository/github/CogitatorTech/ordered)
[![Docs](https://img.shields.io/badge/docs-view-blue?style=flat&labelColor=282c34&logo=read-the-docs)](https://CogitatorTech.github.io/ordered/)
[![Examples](https://img.shields.io/badge/examples-view-green?style=flat&labelColor=282c34&logo=zig)](https://github.com/CogitatorTech/ordered/tree/main/examples)
[![Zig Version](https://img.shields.io/badge/Zig-0.15.1-orange?logo=zig&labelColor=282c34)](https://ziglang.org/download/)
[![Release](https://img.shields.io/github/release/CogitatorTech/ordered.svg?label=release&style=flat&labelColor=282c34&logo=github)](https://github.com/CogitatorTech/ordered/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-007ec6?label=license&style=flat&labelColor=282c34&logo=open-source-initiative)](https://github.com/CogitatorTech/ordered/blob/main/LICENSE)

A collection of data structures that keep data in order in pure Zig

</div>

---

Ordered is a Zig library that provides fast and efficient implementations of various popular data structures including
B-tree, skip list, trie, and red-black tree for Zig programming language.

### Supported Data Structures

Currently supported data structures include:

- [B-tree](src/ordered/btree_map.zig): A self-balancing search tree where nodes can have many children.
- [Sorted Set](src/ordered/sorted_set.zig): A data structure that stores a collection of unique elements in a consistently sorted order.
- [Skip List](src/ordered/skip_list.zig): A probabilistic data structure that uses multiple linked lists to create "express lanes" for fast, tree-like search.
- [Trie](src/ordered/trie.zig): A tree where paths from the root represent prefixes which makes it extremely fast for tasks like text autocomplete.
- [Red-black Tree](src/ordered/red_black_tree.zig): A self-balancing binary search tree that uses node colors to guarantee efficient operations.
- [Cartesian Tree](src/ordered/cartesian_tree.zig): A binary tree that uniquely combines a binary search tree property for its keys with a heap** property for its values.

| # | Data Structure | Build Complexity | Memory Complexity | Search Complexity    |  
|---|----------------|------------------|-------------------|----------------------|
| 1 | B-tree         | $O(\log n)$      | $O(n)$            | $O(\log n)$          |  
| 2 | Cartesian tree | $O(\log n)$\*    | $O(n)$            | $O(\log n)$\* |  
| 3 | Red-black tree | $O(\log n)$      | $O(n)$            | $O(\log n)$          |  
| 4 | Skip list      | $O(\log n)$\*    | $O(n)$            | $O(\log n)$\* |  
| 5 | Sorted set     | $O(n)$           | $O(n)$            | $O(\log n)$          |
| 6 | Trie           | $O(m)$           | $O(n \cdot m)$    | $O(m)$               |  

- $n$: number of stored elements
- $m$: maximum length of a key
- \*: average case complexity

> [!IMPORTANT]
> Ordered is in early development, so bugs and breaking API changes are expected.
> Please use the [issues page](https://github.com/CogitatorTech/ordered/issues) to report bugs or request features.

---

### Getting Started

To be added.

---

### Documentation

You can find the API documentation for the latest release of Ordered [here](https://CogitatorTech.github.io/ordered/).

Alternatively, you can use the `make docs` command to generate the documentation for the current version of Ordered.
This will generate HTML documentation in the `docs/api` directory, which you can serve locally with `make serve-docs`
and view in a web browser.

### Examples

Check out the [examples](examples) directory for example usages of Ordered.

---

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to make a contribution.

### License

Ordered is licensed under the MIT License (see [LICENSE](LICENSE)).

### Acknowledgements

* The logo is from [SVG Repo](https://www.svgrepo.com/svg/469537/zig-zag-left-right-arrow) with some modifications.
