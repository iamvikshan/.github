# Reusable GitHub Actions & Workflows

This directory publishes reusable composite actions and reusable workflows. Use
the references below to call them from other workflows/repositories.

---

## Reusable GitHub Actions

When calling reusable actions, use the full repository reference path:
`iamvikshan/.github/.github/actions/{action-name}@main`

### 1. Deploy Astro Site to GitHub Pages (`astro`)

Builds and deploys an Astro static site to GitHub Pages using Bun.

#### Inputs

| Input             | Description                                   | Required | Default        |
| :---------------- | :-------------------------------------------- | :------: | :------------- |
| `node-version`    | Node.js version to use                        |    No    | `"24"`         |
| `package-manager` | Package manager to use (bun, npm, pnpm, yarn) |    No    | `"bun@latest"` |
| `path`            | Root location of your Astro project           |    No    | `"."`          |

#### Usage Example

```yaml
- name: Deploy Astro Site
  uses: iamvikshan/.github/.github/actions/astro@main
  with:
    path: './docs'
    node-version: '20'
```

---

### 2. Setup Bun & Install (`bun`)

Sets up the latest version of Bun and installs package dependencies. It supports
workspace escaping validation, relative path resolution, and
single-directory/monorepo paths.

#### Inputs

| Input               | Description                                                                         | Required | Default |
| :------------------ | :---------------------------------------------------------------------------------- | :------: | :------ |
| `working-directory` | The directory to install dependencies in (if `install-paths` is empty)              |    No    | `"."`   |
| `install-paths`     | Newline-separated paths to install dependencies in (relative to the workspace root) |    No    | `""`    |
| `install-args`      | Newline-separated Bun install arguments                                             |    No    | `""`    |

#### Usage Examples

##### Single-directory install (current directory)

```yaml
- name: Install dependencies
  uses: iamvikshan/.github/.github/actions/bun@main
```

##### Single-directory install (custom folder)

```yaml
- name: Install dependencies
  uses: iamvikshan/.github/.github/actions/bun@main
  with:
    working-directory: apps/web
```

##### Monorepo multi-path install with custom arguments

```yaml
- name: Install all workspaces
  uses: iamvikshan/.github/.github/actions/bun@main
  with:
    install-paths: |
      apps/web
      packages/ui
    install-args: '--frozen-lockfile'
```

---

### 3. Setup Node.js, Bun & Install (`bun-node`)

Sets up both Node.js and Bun environments, and then triggers package
installation using the consolidated `bun` action internally.

#### Inputs

| Input               | Description                                                                         | Required | Default    |
| :------------------ | :---------------------------------------------------------------------------------- | :------: | :--------- |
| `node-version`      | Node.js version to set up                                                           |    No    | `"latest"` |
| `working-directory` | The directory to install dependencies in (if `install-paths` is empty)              |    No    | `"."`      |
| `install-paths`     | Newline-separated paths to install dependencies in (relative to the workspace root) |    No    | `""`       |
| `install-args`      | Newline-separated Bun install arguments                                             |    No    | `""`       |

#### Usage Example

```yaml
- name: Setup full JS/TS Environment
  uses: iamvikshan/.github/.github/actions/bun-node@main
  with:
    node-version: '22'
    working-directory: 'apps/api'
```

---

## Reusable GitHub Workflows

This repository also publishes reusable workflows under `.github/workflows/`.
These can be called directly by other workflows/repositories using the full
reference path: `iamvikshan/.github/.github/workflows/{workflow-file}.yml@main`

### 1. CLA Assistant (`cla.yml`)

Integrates the Contributor License Agreement assistant to check and sign CLAs
via PR comments.

#### Secrets

| Secret  | Description                                                                                          |                  Required                  |
| :------ | :--------------------------------------------------------------------------------------------------- | :----------------------------------------: |
| `token` | Optional GitHub PAT used to write signatures when signatures destination is outside the caller repo. | No (defaults to caller GITHUB_TOKEN scope) |

#### Caller Workflow Example

```yaml
name: CLA Check

on:
  issue_comment:
    types: [created]
  pull_request_target:
    types: [opened, closed, synchronize]

jobs:
  run-cla:
    uses: iamvikshan/.github/.github/workflows/cla.yml@main
    secrets: inherit
    permissions:
      contents: write
      pull-requests: write
      statuses: write
```

---

### 2. PR Agent (`pr-agent.yml`)

Runs PR-Agent reviews, suggestions, and chat interfaces on Pull Requests using
Google Gemini.

#### Secrets

| Secret         | Description                                               | Required |
| :------------- | :-------------------------------------------------------- | :------: |
| `GEMINI_TOKEN` | Gemini API Key used to communicate with Google AI Studio. | **Yes**  |

#### Caller Workflow Example

##### Explicit Secrets Mapping (Recommended for custom secret names)

```yaml
name: Code Review

on:
  pull_request:
    types: [opened, reopened, ready_for_review, synchronize]
  issue_comment:
    types: [created]

jobs:
  review:
    # Gating the job ensures Gemini API and secrets aren't exposed on non-PR comments
    if:
      ${{ github.event_name == 'pull_request' || github.event.issue.pull_request
      }}
    uses: iamvikshan/.github/.github/workflows/pr-agent.yml@main
    permissions:
      contents: write
      pull-requests: write
      issues: write
    secrets:
      GEMINI_TOKEN: ${{ secrets.GEMINI }}
```

##### Seamless Inheritance

```yaml
    secrets: inherit
```
