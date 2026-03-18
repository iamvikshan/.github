<div align="center">

[![wakatime](https://wakatime.com/badge/user/8535571c-1079-48d4-ac47-11a817f61249/project/7a0a8898-8a77-4841-aa00-56218eb74bb4.svg)](https://wakatime.com/badge/user/8535571c-1079-48d4-ac47-11a817f61249/project/7a0a8898-8a77-4841-aa00-56218eb74bb4)
[![CLA Assistant](https://github.com/iamvikshan/.github/actions/workflows/cla.yml/badge.svg)](https://github.com/iamvikshan/.github/actions/workflows/cla.yml)

</div>

# 🏥 Vikshan's `.github`

This repository contains the common community health files that i (vikshan), use for my projects.
These policies are adopted across my repos:

- [Code of Conduct](./.github/CODE_OF_CONDUCT.md)
- [Contributing Guidelines](./.github/CONTRIBUTING.md)
- [Security Policy](./.github/SECURITY.md)
- [Support](./.github/SUPPORT.md)
- [Contributor License Agreement](./.github/CLA.md)

Other files included in this repository are:

- [signatures.json](./signatures/signatures.json) contains the list of users who have signed my CLA

## Reusable actions

This repository also publishes reusable composite actions. Use the full action path in workflows so
the intended action is explicit:

- `iamvikshan/.github/.github/actions/bun-actions@main` supports `working-directory`,
  `install-paths`, and `install-args`.
- `iamvikshan/.github/.github/actions/setup-bun@main` supports `install-paths` and `install-args`.
- `iamvikshan/.github/.github/actions/setup-node-bun@main` supports `install-paths` and
  `install-args`. It forwards those inputs to `setup-bun` and does not expose `working-directory`.

Single-directory install:

```yaml
- uses: iamvikshan/.github/.github/actions/bun-actions@main
  with:
    working-directory: apps/web
```

Multi-path monorepo install:

```yaml
- uses: iamvikshan/.github/.github/actions/setup-node-bun@main
  with:
    install-paths: |
      apps/web
      packages/ui
```

`bun-actions` keeps its existing production install default when `install-args` is omitted, because
it defaults to `--production`. Set `install-args: ""` to clear that default and run plain
`bun install`:

```yaml
- uses: iamvikshan/.github/.github/actions/bun-actions@main
  with:
    working-directory: apps/web
    install-args: ""
```

Renovate now replaces Dependabot in this repository. Regular dependency update timing depends on the
execution cadence of the app or workflow that runs Renovate, while lock file maintenance is
explicitly scheduled weekly in `renovate.json` for before 5am on Monday.
