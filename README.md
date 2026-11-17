<div align="center">

[![wakatime](https://wakatime.com/badge/user/8535571c-1079-48d4-ac47-11a817f61249/project/7a0a8898-8a77-4841-aa00-56218eb74bb4.svg)](https://wakatime.com/badge/user/8535571c-1079-48d4-ac47-11a817f61249/project/7a0a8898-8a77-4841-aa00-56218eb74bb4)
[![CLA Assistant](https://github.com/iamvikshan/.github/actions/workflows/cla.yml/badge.svg)](https://github.com/iamvikshan/.github/actions/workflows/cla.yml)

</div>

# 🏥 Vikshan's `.github`

This repository contains the common community health files that I (vikshan), use
for my projects. These policies are adopted across my repos:

- [Code of Conduct](./.github/CODE_OF_CONDUCT.md)
- [Contributing Guidelines](./.github/CONTRIBUTING.md)
- [Security Policy](./.github/SECURITY.md)
- [Support](./.github/SUPPORT.md)
- [Contributor License Agreement](./.github/CLA.md)

Other files included in this repository are:

- [cla.json](./signatures/cla.json) contains the list of users who have signed
  my CLA

<!-- coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated-section:v1:0b80c628d888cc86f2aa20d76d3c05259689b325251229592db50ad8525b5bab -->

## Git authentication setup

Run `sh scripts/git.sh` in an interactive terminal. For GitHub and GitLab,
choose to keep the saved token, use the environment token, enter a new token
without echo, or remove/disable the saved credential. Both selected tokens are
verified before authentication settings or stored credentials are changed.
GitHub must authenticate as `iamvikshan`; GitLab defaults to `vikshan` and can
be selected with `GL_USERNAME`. These account names are independent of the
repository owner or namespace. Tokens must permit the current-user API lookup as
well as the repository and signing-key operations you use.

Credentials persist in `~/.local/share/atlas/credentials.json` (mode `0600`,
directory `0700`). This is an unencrypted local store protected by filesystem
permissions. It is read as JSON, never executed. Tokens are absent from remote
URLs and curl arguments. Anyone controlling the host can still read this file.

The installed Git helper reads only this store for GitHub and GitLab, including
when Git is invoked by VS Code. It ignores inherited tokens and blocks fallback
when credentials are missing. Setup resets helper chains and HTTP headers for
both hosts in global and current-repository configuration. It retains the clean
GitHub origin and optional GitLab push destination. Re-run setup to replace an
expired token. Removing a saved token disables that host through this helper.

In headless mode, an existing store is retained and verified; inherited tokens
cannot replace it. On first setup only, `GH_TOKEN` and `GL_TOKEN` provide the
initial values. `GITHUB_TOKEN` is never imported. No token is required for a
forge you leave disabled. No CLI is required; this configures Git
authentication, not `gh` or GitLab CLI authentication. Other repositories with
their own local authentication overrides need setup run once inside them too.

Run credential regression checks with `python3 tests/test_git_credentials.py`.
These use temporary repositories, synthetic credentials, and a mock API.

<!-- /coderabbit-ai-generated:v1 -->
