"""Exercise shell setup with temporary homes, fake executables, and synthetic repositories."""
import os
import pathlib
import shutil
import subprocess
import tempfile

REPO = pathlib.Path(__file__).resolve().parents[1]

def run(args, env, cwd, data=None):
    return subprocess.run(args, env=env, cwd=cwd, input=data, capture_output=True, text=True)

with tempfile.TemporaryDirectory(prefix='atlas-shell-test-') as td:
    root = pathlib.Path(td)
    home = root / 'home'
    home.mkdir()
    binary = root / 'bin'
    binary.mkdir()
    env = {'HOME': str(home), 'PATH': str(binary) + ':/usr/bin:/bin', 'TERM': 'xterm-256color',
           'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': str(root / 'global')}
    # Validation must fail before any global or local Git configuration writes.
    for in_repo in (False, True):
        directory = root / ('repo' if in_repo else 'outside')
        directory.mkdir()
        if in_repo:
            subprocess.run(['git', 'init', '-q', str(directory)], env=env, check=True)
        result = run(['sh', str(REPO / 'scripts/git.sh'), '--trust-only'], env | {'ATLAS_GIT_FILEMODE': 'typo'}, directory)
        assert result.returncode != 0 and 'ATLAS_GIT_FILEMODE' in result.stderr, result.stderr
        assert not (root / 'global').exists()
        if in_repo:
            config = (directory / '.git/config').read_text()
            assert 'safe.directory' not in config and 'atlas' not in config
    print('PASS invalid filemode rejected before Git writes inside and outside a repository')

    # Invoke Zsh after sourcing aliases, so global expansion occurs on the next line.
    aliases = str(REPO / 'scripts/aliases.sh')
    result = run(['zsh', '-f', '-c', f'source "{aliases}"\neval "print -r -- J NE NO"'], env, root)
    assert result.returncode == 0 and result.stdout.strip() == 'J NE NO', result.stderr
    print('PASS short global aliases do not change ordinary arguments')

    # Reuse just the actual pager initialization as an isolated shell configuration.
    source = (REPO / 'scripts/universal.zshrc').read_text()
    start = source.index('if [[ ! -v MANPAGER ]]')
    end = source.index('\nfi', start) + 3
    for cmd in ('bat', 'col'):
        target = binary / cmd
        target.write_text('#!/bin/sh\nexit 0\n')
        target.chmod(0o755)
    for existing in (None, '', 'custom-pager'):
        current = env.copy()
        if existing is not None:
            current['MANPAGER'] = existing
        result = run(['zsh', '-f', '-c', source[start:end] + '\nprint -r -- "$MANPAGER"'], current, root)
        assert result.returncode == 0, result.stderr
        assert result.stdout.strip() == ("sh -c 'col -bx | bat --language=man --style=plain'" if existing is None else existing)
    print('PASS unset MANPAGER gets default; empty and custom values are preserved')

    # Bootstrap decides on the rendering host; headless sessions can explicitly opt in.
    scripts_dir = root / 'scripts'
    scripts_dir.mkdir()
    (scripts_dir / 'fonts.sh').write_text('#!/bin/sh\nprintf called > "$TEST_FONT_MARKER"\n')
    marker = root / 'font-called'
    bootstrap = (REPO / 'scripts/bootstrap.sh').read_text()
    start = bootstrap.index('# Fonts are rendered by the client.')
    end = bootstrap.index('# 6. install standalone zsh plugins', start)
    block = bootstrap[start:end]
    shell_setup = 'log_exec() { :; }; log_warn() { :; }; log_fail() { exit 1; }; SCRIPT_DIR="$TEST_SCRIPT_DIR"\n'
    common = env | {'TEST_FONT_MARKER': str(marker), 'TEST_SCRIPT_DIR': str(scripts_dir)}
    for extra, should_install in [({'DISPLAY': ':1'}, True), ({'CODESPACES': 'true', 'DISPLAY': ':1'}, False),
                                  ({'SSH_CONNECTION': 'remote', 'DISPLAY': ':1'}, False),
                                  ({'CODESPACES': 'true', 'ATLAS_INSTALL_FONTS': 'true'}, True),
                                  ({'DISPLAY': ':1', 'ATLAS_INSTALL_FONTS': 'false'}, False)]:
        marker.unlink(missing_ok=True)
        result = run(['sh', '-c', shell_setup + block], common | extra, root)
        assert result.returncode == 0 and marker.exists() == should_install, (extra, result.stderr)
    print('PASS bootstrap installs fonts on desktops and respects headless and explicit preferences')
