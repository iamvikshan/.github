"""Starship prompt behavior using temporary projects and synthetic runtime binaries."""
import os
import pathlib
import platform
import re
import subprocess
import tempfile

repo = pathlib.Path(__file__).resolve().parents[1]
starship = os.environ.get('STARSHIP_BIN', 'starship')
ansi = re.compile(r'\x1b\[[0-9;]*m')
with tempfile.TemporaryDirectory(prefix='atlas-prompt-test-') as td:
    root = pathlib.Path(td)
    bin_dir = root / 'bin'
    bin_dir.mkdir()
    for name, version in (('bun', '1.2.3'), ('node', 'v22.0.0')):
        p = bin_dir / name
        p.write_text('#!/bin/sh\nprintf "%s\\n" ' + version + '\n')
        p.chmod(0o755)
    project = root / 'project'
    project.mkdir()
    env = {'HOME': str(root), 'PATH': str(bin_dir) + ':/usr/bin:/bin', 'TERM': 'xterm-256color',
           'STARSHIP_CONFIG': str(repo / 'scripts/starship.toml'), 'STARSHIP_SHELL': 'zsh'}
    def prompt(*args, extra=None):
        result = subprocess.run([starship, 'prompt', *args], cwd=project, env=env | (extra or {}), text=True, capture_output=True, check=True)
        assert not result.stderr, result.stderr
        return ansi.sub('', result.stdout).replace('%{', '').replace('%}', '')
    clean = prompt('--status', '0', '--jobs', '0', '--cmd-duration', '10')
    expected_os = None
    if platform.system() == 'Darwin':
        expected_os = ''
    elif platform.system() == 'Linux':
        try:
            distro = platform.freedesktop_os_release().get('ID', '')
        except OSError:
            distro = ''
        expected_os = {'ubuntu': '', 'debian': '', 'alpine': ''}.get(distro)
    if expected_os:
        assert expected_os in clean, repr(clean)
    assert 'exit ' not in clean and '' not in clean and '' not in clean and '' not in clean, repr(clean)
    assert clean.startswith('\n') and clean.rstrip().endswith('❯'), repr(clean)
    failed = prompt('--status', '9', '--jobs', '2', '--cmd-duration', '2500', extra={'CODESPACES': 'true'})
    assert 'exit 9' in failed and 'codespace' in failed and '2s' in failed and '✦2' in failed, repr(failed)
    (project / 'package.json').write_text('{}')
    (project / 'bun.lock').write_text('')
    bun = prompt('--status', '0')
    assert '' in bun and '1.2.3' in bun and '' not in bun, repr(bun)
    (project / 'bun.lock').unlink()
    node = prompt('--status', '0')
    assert '' in node and '22.0.0' in node and '' not in node, repr(node)
    subprocess.run(['git', 'init', '-q', str(project)], env=env, check=True)
    git = prompt('--status', '0')
    assert '' in git and '?' in git, repr(git)
    print('PASS Ubuntu icon, two-line layout, conditional failures/jobs/duration/remote, Bun/Node detection and Git state')
