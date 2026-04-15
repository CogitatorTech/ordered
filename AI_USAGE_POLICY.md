# AI Usage Policy

> [!IMPORTANT]
> Ordered does not accept fully AI-generated pull requests.
> AI tools may be used only for assistance.
> You must understand and take responsibility for every change you submit.
>
> Read and follow [AGENTS.md](./AGENTS.md), [CONTRIBUTING.md](./CONTRIBUTING.md), and [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).

## Our Rule

All contributions must come from humans who understand and can take full responsibility for their code. LLMs make mistakes and cannot be held
accountable.
Ordered is a sorted-collection library, so its users trust every container to preserve ordering, return correct values, and clean up its memory.
Subtle issues in the balancing rotations, the iterator state machines, or the per-instance PRNG seeding silently corrupt every downstream project
that depends on Ordered, so human ownership matters.

> [!WARNING]
> Maintainers may close PRs that appear to be fully or largely AI-generated.

## Getting Help

Before asking an AI, please open or comment on an issue on the [Ordered issue tracker](https://github.com/CogitatorTech/ordered/issues). There are
no silly questions, and sorted-collection topics (red-black rotations, B-tree splits and merges, skip-list level distribution, trie memory
ownership, and allocator lifetimes across recursive structures) are an area where LLMs often give confident but incorrect answers.

If you do use AI tools, use them for assistance (like a reference or tutor), not generatively (to fully write code for you).

## Guidelines for Using AI Tools

1. Complete understanding of every line of code you submit.
2. Local review and testing before submission, including `make test` and `make lint`.
3. Personal responsibility for bugs, regressions, and cross-platform issues in your contribution.
4. Disclosure of which AI tools you used in your PR description.
5. Compliance with all rules in [AGENTS.md](./AGENTS.md) and [CONTRIBUTING.md](./CONTRIBUTING.md).

### Example Disclosure

> I used Claude to help understand a regression in `src/ordered/red_black_tree_set.zig`'s rebalancing.
> I reviewed the suggested fix, ran `make test` locally, ran `make bench BENCHMARK=b3_red_black_tree_set` for
> a before/after comparison, and verified iteration order is still monotonic.

## Allowed (Assistive Use)

- Explanations of existing code in `src/lib.zig`, `src/ordered/`, and `examples/`.
- Suggestions for debugging failing inline `test` blocks or benchmark regressions.
- Help understanding Zig compiler errors, allocator lifetimes, or prior-art algorithms (CLRS, Sedgewick, Pugh's skip-list paper).
- Review of your own code for correctness, clarity, and style.

## Not Allowed (Generative Use)

- Generation of entire PRs or large code blocks, including new containers under `src/ordered/`, new iterator state machines, or new example or
  benchmark programs.
- Delegation of implementation or API decisions to the tool, especially for the shape of the public API re-exported from `src/lib.zig` or for
  the ordering semantics of any container.
- Submission of code you do not understand.
- Generation of documentation, README content, or doc comments without your own review.
- Automated or bulk submission of changes produced by agents.

## About AGENTS.md

[AGENTS.md](./AGENTS.md) encodes project rules about architecture, testing, and conventions, and is structured so that LLMs can better comply with
them. Agents may still ignore or be talked out of it; it is a best effort, not a guarantee.
Its presence does not imply endorsement of any specific AI tool or service.

## Licensing Note

Ordered is licensed under the MIT License and has no external Zig or C dependencies, so all source in this repository is expected to be originally
authored by contributors. AI-generated code of unclear provenance would muddy that boundary, which is another reason to keep contributions
human-authored.

## AI Disclosure

This policy was adapted, with the assistance of AI tools, from a similar policy used by other open-source projects, and was reviewed and edited by
human contributors to fit Ordered.
