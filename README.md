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

### Features

- Fast and efficient implementations

### Data Structures

| Data Structure                                                         | Build Complexity | Memory Complexity | Search Complexity |  
|------------------------------------------------------------------------|------------------|-------------------|-------------------|
| [B-tree](https://en.wikipedia.org/wiki/B-tree)                         | $O(\log n)$      | $O(n)$            | $O(\log n)$       |  
| [Cartesian tree](https://en.wikipedia.org/wiki/Cartesian_tree)         | $O(\log n)$\*    | $O(n)$            | $O(\log n)$\*     |  
| [Red-black tree](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree) | $O(\log n)$      | $O(n)$            | $O(\log n)$       |  
| [Skip list](https://en.wikipedia.org/wiki/Skip_list)                   | $O(\log n)$\*    | $O(n)$            | $O(\log n)$\*     |  
| Sorted set                                                             | $O(n)$           | $O(n)$            | $O(\log n)$       |
| [Trie](https://en.wikipedia.org/wiki/Trie)                             | $O(m)$           | $O(n \cdot m)$    | $O(m)$            |  

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
