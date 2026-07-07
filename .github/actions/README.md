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

#### Inputs

| Input                      | Description                                            | Required | Default                                                       |
| :------------------------- | :----------------------------------------------------- | :------: | :------------------------------------------------------------ |
| `path-to-document`         | Path or full URL to the CLA document.                  |    No    | `https://github.com/{owner}/.github/blob/main/.github/CLA.md` |
| `remote-organization-name` | Remote organization/owner where signatures are stored. |    No    | `"iamvikshan"`                                                |
| `remote-repository-name`   | Remote repository name where signatures are stored.    |    No    | `".github"`                                                   |

#### Secrets

| Secret  | Description                                                                        |        Required        |
| :------ | :--------------------------------------------------------------------------------- | :--------------------: |
| `token` | GitHub Personal Access Token (PAT) with write access to the signatures repository. | Yes (to save remotely) |

#### Caller Workflow Example

##### 1. Saving Signatures to the Central Repository (Default)

By default, signatures will be written to
`iamvikshan/.github/signatures/cla.json` (requires a valid `GH_TOKEN` secret
with write permissions to `.github` passed in the `token` parameter):

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
    secrets:
      token: ${{ secrets.GH_TOKEN }}
```

##### 2. Saving Signatures Locally to the Caller Repository

To store signatures inside the caller repository itself (no remote writes),
override the inputs with empty strings:

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
    with:
      remote-organization-name: ''
      remote-repository-name: ''
    secrets:
      token: ${{ secrets.GITHUB_TOKEN }}
```

---

### 2. PR Agent (`pr-agent.yml`)

Runs PR-Agent reviews, suggestions, and chat interfaces on Pull Requests using
Google Cloud Vertex AI (Gemini 3.5 Flash).

#### Inputs

| Input             | Description                            | Required | Default          |
| :---------------- | :------------------------------------- | :------: | :--------------- |
| `vertex_project`  | Google Cloud Project ID for Vertex AI. |    No    | `"amina-440220"` |
| `vertex_location` | Vertex AI region/location endpoint.    |    No    | `"global"`       |

#### Secrets

| Secret            | Description                                                           | Required |
| :---------------- | :-------------------------------------------------------------------- | :------: |
| `GCP_CREDENTIALS` | Google Cloud Service Account JSON Key with the `Vertex AI User` role. |   Yes    |

#### Caller Workflow Example

##### 1. Using Defaults (Recommended)

```yaml
name: Code Review

on:
  pull_request:
    types: [opened, reopened, ready_for_review, review_requested, synchronize]
  issue_comment:
    types: [created]

jobs:
  review:
    uses: iamvikshan/.github/.github/workflows/pr-agent.yml@main
    permissions:
      contents: write
      pull-requests: write
      issues: write
    secrets:
      GCP_CREDENTIALS: ${{ secrets.GCP_SA_JSON_KEY }}
```

##### 2. Overriding GCP Project and Region

```yaml
name: Code Review

on:
  pull_request:
    types: [opened, reopened, ready_for_review, review_requested, synchronize]
  issue_comment:
    types: [created]

jobs:
  review:
    uses: iamvikshan/.github/.github/workflows/pr-agent.yml@main
    with:
      vertex_project: 'my-custom-gcp-project'
      vertex_location: 'us-central1'
    permissions:
      contents: write
      pull-requests: write
      issues: write
    secrets:
      GCP_CREDENTIALS: ${{ secrets.GCP_SA_JSON_KEY }}
```
