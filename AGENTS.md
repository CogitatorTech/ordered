# AGENTS.md

This file provides guidance to coding agents collaborating on this repository.

## Mission

Ordered is a sorted-collection library for Zig. It provides in-memory data structures that keep their elements sorted:
two set types (value-only) and four map types (key-value), all exposing a small, uniform API for insertion, lookup,
removal, and in-order iteration.
Priorities, in order:

1. Correctness of ordering, iteration, and memory management across insertions and removals.
2. Minimal public API that is consistent across every container type.
3. Zero non-Zig dependencies, maintainable, and well-tested code.
4. Cross-platform support (Linux, macOS, and Windows).

## Core Rules

- Use English for code, comments, docs, and tests.
- Prefer small, focused changes over large refactoring.
- Add comments only when they clarify non-obvious behavior.
- Do not add features, error handling, or abstractions beyond what is needed for the current task.
- Keep the project dependency-free: no external Zig packages or C libraries unless explicitly agreed.

## Writing Style

- Use Oxford commas in inline lists: "a, b, and c" not "a, b, c".
- Do not use em dashes. Restructure the sentence, or use a colon or semicolon instead.
- Avoid colorful adjectives and adverbs. Write "TCP proxy" not "lightweight TCP proxy", "scoring components" not "transparent scoring components".
- Use noun phrases for checklist items, not imperative verbs. Write "redundant index detection" not "detect redundant indexes".
- Headings in Markdown files must be in the title case: "Build from Source" not "Build from source". Minor words (a, an, the, and, but, or, for, in,
  on, at, to, by, of, is, are, was, were, be) stay lowercase unless they are the first word.

## Repository Layout

- `src/lib.zig`: Public API entry point. Re-exports `SortedSet`, `RedBlackTreeSet`, `BTreeMap`, `SkipListMap`, `TrieMap`, and `CartesianTreeMap`.
- `src/ordered/sorted_set.zig`: `SortedSet` (insertion-sorted `std.ArrayList` backed by a linear scan for insert and removal).
- `src/ordered/red_black_tree_set.zig`: `RedBlackTreeSet` (self-balancing BST).
- `src/ordered/btree_map.zig`: `BTreeMap` (cache-friendly B-tree with configurable branching factor).
- `src/ordered/skip_list_map.zig`: `SkipListMap` (probabilistic skip list with a per-instance PRNG).
- `src/ordered/trie_map.zig`: `TrieMap` (prefix tree, specialised for `[]const u8` keys).
- `src/ordered/cartesian_tree_map.zig`: `CartesianTreeMap` (treap combining BST ordering with max-heap priorities).
- `examples/`: Self-contained example programs (`e1_btree_map.zig` through `e6_cartesian_tree_map.zig`) built as executables via `build.zig`.
- `benches/`: Benchmark programs (`b1_btree_map.zig` through `b6_cartesian_tree_map.zig`) built in `ReleaseFast`.
- `benches/util/timer.zig`: Internal compatibility shim for the removed `std.time.Timer`, backed by `std.Io.Timestamp`.
- `.github/workflows/`: CI workflows (`tests.yml` for unit tests on Linux, macOS, and Windows, `docs.yml`, `lints.yml`, and `benches.yml`).
- `build.zig` / `build.zig.zon`: Zig build configuration and package metadata.
- `Makefile`: GNU Make wrapper around `zig build` targets.
- `docs/`: Generated API docs land in `docs/api/` (produced by `make docs`).

## Architecture

### Common API Across Containers

Every map exposes `init(allocator)`, `deinit()`, `count()`, `contains(key)`, `get(key)`, `getPtr(key)`, `put(key, value)`,
`remove(key)`, and `iterator()`. Every set exposes the same shape with value-only variants. New containers should
adopt this surface instead of inventing new method names.

### Iteration

Iterators return entries in the natural sort order of the underlying structure. Modifying a container during
iteration is undefined behaviour; each container's docstring states this explicitly. New iterators should follow
the same convention and document the contract.

### Randomised Containers

`SkipListMap` and `CartesianTreeMap` use randomness internally (levels and priorities, respectively). Each instance
owns its own `std.Random.DefaultPrng`, seeded at `init` from an ASLR-derived hash of a stack address, which is
sufficient randomness for skip-list level selection and treap priority generation. Callers do not need to provide
a seed. Tests that require deterministic behaviour should use the explicit `*WithPriority` / level-setting API
on the container rather than seeding the PRNG directly.

### Public API Surface

Everything re-exported from `src/lib.zig` is part of the public API. Changes to names, signatures, or semantics
there are breaking. The rest of `src/ordered/` is internal and may be refactored freely as long as the public
surface and its behavior are preserved.

### Dependencies

Ordered has **no external Zig or C dependencies**.
The only `build.zig.zon` entries should be Ordered itself.
Please do not add dependencies without prior discussion.

## Zig Conventions

- Zig version: 0.16.0 (as declared in `build.zig.zon` and the Makefile's `ZIG_LOCAL` path).
- Formatting is enforced by `zig fmt`. Run `make format` before committing.
- Naming follows Zig standard-library conventions: `camelCase` for functions (e.g. `getPtr`, `keysWithPrefix`), `snake_case` for local variables and struct fields, `PascalCase` for types and structs, and `SCREAMING_SNAKE_CASE` for top-level compile-time constants.

## Required Validation

Run the relevant targets for any change:

| Target          | Command                              | What It Runs                                                     |
|-----------------|--------------------------------------|------------------------------------------------------------------|
| Unit tests      | `make test`                          | Inline `test` blocks across `src/lib.zig` and `src/ordered/*.zig` |
| Lint            | `make lint`                          | Checks Zig formatting with `zig fmt --check src examples`        |
| Single example  | `make run EXAMPLE=e1_btree_map`      | Builds and runs one example program                              |
| All examples    | `make run`                           | Builds and runs every example under `examples/`                  |
| Single benchmark| `make bench BENCHMARK=b1_btree_map`  | Builds (ReleaseFast) and runs one benchmark program              |
| All benchmarks  | `make bench`                         | Builds and runs every benchmark under `benches/`                 |
| Docs            | `make docs`                          | Generates API docs into `docs/api`                               |
| Everything      | `make all`                           | Runs `build`, `test`, `lint`, and `docs`                         |

## First Contribution Flow

1. Read the relevant module under `src/ordered/` (often one container file per change).
2. Implement the smallest change that covers the requirement.
3. Add or update inline `test` blocks in the changed Zig module to cover the new behavior.
4. Run `make test` and `make lint`.
5. If the change could affect performance, also run the corresponding benchmark with `make bench BENCHMARK=bN_*`.

Good first tasks:

- New example under `examples/` demonstrating a container method, listed in `examples/README.md`.
- Additional inline `test` block covering a boundary case (empty container, single element, duplicate key, unicode key).
- Performance improvement in an existing container, paired with benchmark output before/after.
- Documentation refinement in a container module's top-level docstring.

## Testing Expectations

- Unit and regression tests live as inline `test` blocks in the module they cover (`src/lib.zig` and `src/ordered/*.zig`). There is no separate `tests/` directory.
- Tests are discovered automatically via `std.testing.refAllDecls(@This())` in `src/lib.zig`, so new `test` blocks only need to live in a module that is reachable from `lib.zig`.
- Every new public function or container branch must ship with at least one `test` block that exercises it, including the error paths where applicable.
- Memory tests should use `std.testing.allocator` so leaks are caught automatically.
- No public API change is complete without a test covering the new or changed behavior.

## Change Design Checklist

Before coding:

1. Modules affected by the change (which container file, or `lib.zig` if the public surface moves).
2. Whether the change alters ordering, iteration, or removal semantics, and therefore needs explicit test coverage.
3. Public API impact, i.e. whether the change adds to or alters anything re-exported from `src/lib.zig`, and is therefore additive or breaking.
4. Cross-platform implications, especially for anything that touches timing, the filesystem, or non-deterministic ordering.

Before submitting:

1. `make test` passes.
2. `make lint` passes.
3. `make bench` still succeeds for any benchmark whose container was touched, with a note on whether performance moved.
4. Docs updated (`make docs`) if the public API surface changed, and `README.md` ticked or updated if a container was added or removed.

## Commit and PR Hygiene

- Keep commits scoped to one logical change.
- PR descriptions should include:
    1. Behavioral change summary.
    2. Tests added or updated.
    3. Whether benchmarks were run locally (yes/no), and on which OS, with before/after numbers when relevant.
