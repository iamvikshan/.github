# Shell and Git setup scripts

Scripts that set up a new machine, container, or Codespace: shell tools, Zsh,
the Starship prompt, a Nerd Font, and a Git configuration with verified
credentials and SSH commit signing.

> These scripts are personal configuration. GitHub authentication is pinned to
> the account `iamvikshan` and GitLab defaults to `vikshan`. To use them for
> yourself, fork the repository and change those account names.

## Quick start

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:21e2461651ae7dccfcdabe1c16eae45b773ce4d8cf08124bd1b10d082b3643ef -->

Run the full setup in an interactive terminal (stdin stays attached for
prompts):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/bootstrap.sh)"
```

Run it without prompts (headless defaults, including when stdin is a terminal):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/bootstrap.sh)" sh --default
```

Set environment variables on the `sh` command:

```sh
ATLAS_INSTALL_FONTS=true sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/bootstrap.sh)"
```

Piping `curl` into `sh` makes stdin non-terminal, so setup uses headless
defaults.

<!-- /coderabbit-ai-generated:v1 -->

## What is in this folder

| Script         | Purpose                                                                                                                                                                          |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bootstrap.sh` | Entry point. Installs shell tools, plugins, Zsh configuration, the Starship prompt, and the font, then runs the Git setup when inside a repository. Updates shell startup files. |
| `git.sh`       | Git identity, credentials, SSH commit signing, remotes, and hooks. Can be run on its own.                                                                                        |
| `fonts.sh`     | Installs the Argon Nerd Font. Can be run on its own.                                                                                                                             |

## Run a single part

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0229aad41c4ca4e03cec1a82eacf57264be6cba80c70e6f0e36496c23017d3ec -->

Git setup only:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/git.sh)"
```

Font only:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/fonts.sh)"
```

<!-- /coderabbit-ai-generated:v1 -->

## Options and environment variables

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:2cb439d44f76038c2310c0e00f4aaeaca9abd11660f239c839d4419fb1e6abca -->

| Name                   | Applies to     | Effect                                                                                                    |
| ---------------------- | -------------- | --------------------------------------------------------------------------------------------------------- |
| `--default`            | `bootstrap.sh` | Headless defaults, no prompts. With `sh -c`, pass `sh --default` after the script string.                 |
| `ATLAS_INSTALL_FONTS`  | `bootstrap.sh` | `true` installs the font on headless or SSH sessions. `false` skips it on a desktop.                      |
| `ATLAS_FONT_DIR`       | `fonts.sh`     | Install the font into this directory instead of the default.                                              |
| `ATLAS_GIT_FILEMODE`   | `git.sh`       | `false` ignores executable-bit changes, `true` honors them. Unset keeps the repository's current setting. |
| `GL_USERNAME`          | `git.sh`       | GitLab account name. Defaults to `vikshan`.                                                               |
| `GH_TOKEN`, `GL_TOKEN` | `git.sh`       | Initial tokens on the first setup only. See [Credentials](#credentials).                                  |

<!-- /coderabbit-ai-generated:v1 -->

## Git setup

### Credentials

In an interactive terminal, `git.sh` asks what to do for GitHub and for GitLab
separately:

- keep the saved token
- use the token from the environment
- enter a new token (input is not echoed)
- remove or disable the saved credential

Both selected tokens are verified against the forge before any authentication
setting or stored credential changes. GitHub must authenticate as `iamvikshan`.
GitLab authenticates as `GL_USERNAME`. These names are independent of the
repository owner or namespace. Tokens must allow the current-user API lookup
plus whichever repository and signing-key operations you use.

**Where tokens live.** Credentials are saved in
`~/.local/share/atlas/credentials.json` (file mode `0600`, directory `0700`). It
is an unencrypted store protected only by filesystem permissions, so anyone who
controls the host can read it. It is parsed as JSON and never executed. Tokens
never appear in remote URLs or curl arguments.

**How Git uses them.** The installed credential helper reads only this store for
GitHub and GitLab, including when VS Code invokes Git. It ignores inherited
tokens and blocks fallback to other helpers when credentials are missing. Setup
resets helper chains and HTTP headers for both hosts in the global configuration
and in the current repository. It keeps a clean GitHub `origin` and an optional
GitLab push destination. Repositories with their own local authentication
overrides need setup run once inside them.

**Headless mode.** An existing store is kept and re-verified, and inherited
tokens cannot replace it. On the very first setup only, `GH_TOKEN` and
`GL_TOKEN` provide the initial values. `GITHUB_TOKEN` is never imported. A forge
you leave disabled needs no token.

**Other notes.** To replace an expired token, run setup again. Removing a saved
token disables that host through this helper. This configures Git authentication
only, not `gh` or the GitLab CLI, and no CLI is required.

### Filesystem mode

Git normally detects whether the filesystem supports executable bits. On an
affected shared mount or an NTFS checkout, run:

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0edc150fbf7beb37a1da6aae17e529f4803c7d85d61f0f678920959609ea8c54 -->

```sh
ATLAS_GIT_FILEMODE=false sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/git.sh)"
```

<!-- /coderabbit-ai-generated:v1 -->

Set the variable to `true` to honor executable-bit changes again.

## Shell experience

### Prompt

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a60fe905690686b905e06d93486ce15511f3dc66c2472fb65b4750f2dcee94d0 -->

The active prompt has context on the first line and input on the second. After a
command is accepted, the previous prompt collapses to a single character, and
the arrow shows the status of the preceding command. A failed command also shows
its exit code in the next active prompt.

<!-- /coderabbit-ai-generated:v1 -->

Directory, OS, and repository information appear when applicable. Runtimes,
remote context, background jobs, read-only directories, and commands that took
at least two seconds appear only when relevant.

The prompt uses Nerd Font symbols, so the font must be installed and selected on
the machine that displays the terminal, even when the shell runs in a remote
container or over SSH. In VS Code, select the installed family in
`terminal.integrated.fontFamily`, or let it inherit `editor.fontFamily`.

### Argon Nerd Font

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0a97f1fcabde6937e08921ae4fb17ad3e36e026b4506fbcd65066032f201ee85 -->

Interactive desktop bootstrap checks that all four Argon Nerd Font faces are
registered. If any face is missing, it installs the Regular, Italic, Bold, and
Bold Italic faces of `MonaspiceAr Nerd Font Mono` from Nerd Fonts 3.5.1, after
verifying the release archive checksum. On Linux it refreshes the fontconfig
cache when available.

- **Install location:** a system font directory if writable or authorized by
  sudo. Cached authorization works without a prompt. An interactive run can ask
  for your sudo password after verifying the download; if authorization fails,
  it uses the current user's font directory. `ATLAS_FONT_DIR` overrides this.
- **Headless and SSH sessions** skip automatic installation, because the
  terminal font normally lives on the client. Set `ATLAS_INSTALL_FONTS=true` to
  opt in. Headless font installation never asks for a sudo password; it uses
  existing authorization or the user directory.
- **Requirements:** `curl`, `tar` with xz support, and `sha256sum` or `shasum`.
- **After installing:** select `MonaspiceAr Nerd Font Mono` in your terminal or
  editor. Installation does not change application settings or remove other
  fonts.
- **Windows:** install the Argon faces from the Nerd Fonts release on the
  machine that runs VS Code.

<!-- /coderabbit-ai-generated:v1 -->

### Zsh shortcuts

| Key or command              | Action                                                                  |
| --------------------------- | ----------------------------------------------------------------------- |
| `Ctrl+R`, `Ctrl+T`, `Alt+C` | fzf history, file, and directory selection (requires fzf)               |
| `Ctrl+X Ctrl+E`             | Edit the current command in `$EDITOR`, then inspect it before executing |
| `Space`                     | Expand history references                                               |
| `Ctrl+_`                    | Undo                                                                    |
| `Ctrl+X Ctrl+C`             | Copy the command buffer                                                 |
| `zmv -n`                    | Preview a batch rename. Remove `-n` to perform it.                      |
| `catp`                      | Available when bat is installed                                         |

`cat`, `find`, and `grep` keep their usual meanings. Use `bat`, `fd`, and `rg`
explicitly.
