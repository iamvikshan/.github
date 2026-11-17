<!-- coderabbit-ai-generated:v1 -->

# Shell setup scripts

Run `sh scripts/bootstrap.sh` from the checkout to install the shell tools,
plugins, Zsh configuration, Starship prompt, and Git setup. The script uses the
local files when available. It updates shell startup files and configures Git
when run inside a repository. `--default` selects headless defaults. Review the
root README for credential selection and storage.

## Prompt

The active prompt has context on the first line and input on the second. After a
command is accepted, the previous prompt collapses to its character; the arrow
reflects the status of the preceding command. A failed command also shows its
exit code in the next active prompt. Directory, OS, and repository information
appear when applicable; runtimes, remote context, background jobs, read-only
directories, and commands taking at least two seconds appear conditionally.

The prompt uses Nerd Font symbols. The font must be installed and selected on
the machine displaying the terminal, including when the shell runs in a remote
container or over SSH. For VS Code, select the installed family in
`terminal.integrated.fontFamily`, or let it inherit `editor.fontFamily`.

## Argon Nerd Font

Desktop bootstrap checks for an existing Argon Nerd Font and otherwise installs
the Regular, Italic, Bold, and Bold Italic faces of `MonaspiceAr Nerd Font Mono`
from Nerd Fonts 3.5.1 after verifying the release archive checksum. On Linux it
refreshes the fontconfig cache when available. It uses a system font directory
when writable or passwordless sudo is available, otherwise the current user's
font directory. Select the family in the terminal or editor; installation does
not change application settings.

Headless and SSH sessions skip automatic installation because the terminal font
is normally on the client. Set `ATLAS_INSTALL_FONTS=true` to opt in or
`ATLAS_INSTALL_FONTS=false` to skip on a desktop. Run `sh scripts/fonts.sh`
directly to install on a local host. Set `ATLAS_FONT_DIR` to choose an
installation directory. The installer requires curl, tar with xz support, and
sha256sum or shasum. Windows users can install the Argon faces from the Nerd
Fonts release on the machine running VS Code.

## Zsh shortcuts

- `Ctrl+R`, `Ctrl+T`, and `Alt+C`: fzf history, file, and directory selection
  when fzf is installed.
- `Ctrl+X Ctrl+E`: edit the current command in `$EDITOR`, then inspect it before
  executing.
- `Space`: expand history references; `Ctrl+_`: undo; `Ctrl+X Ctrl+C`: copy the
  command buffer.
- `zmv -n` previews batch renames; remove `-n` to perform the rename.
- `cat`, `find`, and `grep` keep their usual meanings; use `bat`, `fd`, and `rg`
  explicitly. `catp` is available when bat is installed.

## Git filesystem mode

Git normally detects whether the current filesystem supports executable bits.
For a repository on an affected shared mount or NTFS checkout, run
`ATLAS_GIT_FILEMODE=false sh scripts/git.sh` to ignore executable-bit changes.
Set it to `true` to honor those changes. Leaving it unset preserves the
repository's existing setting.

## Validation

Run `python3 tests/test_git_credentials.py` and
`python3 tests/test_shell_customization.py` for isolated Git and shell
regression checks. `python3 tests/test_starship.py` requires Starship; set
`STARSHIP_BIN` if it is outside PATH. `python3 tests/test_fonts.py` checks
existing-font detection and checksum rejection. Set `ATLAS_TEST_FONT_ARCHIVE` to
a downloaded Nerd Fonts 3.5.1 `Monaspace.tar.xz` to also test installation
without a network connection. These tests use temporary directories and
synthetic data.
