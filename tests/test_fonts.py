"""Font installer integration using an isolated font directory and a cached release."""
import os
import pathlib
import subprocess
import tempfile

repo = pathlib.Path(__file__).resolve().parents[1]
archive = os.environ.get('ATLAS_TEST_FONT_ARCHIVE')
with tempfile.TemporaryDirectory(prefix='atlas-font-test-') as td:
    root = pathlib.Path(td)
    bin_dir = root / 'bin'
    bin_dir.mkdir()
    target = root / 'fonts'
    home = root / 'home'
    home.mkdir()
    scripts = {
        'fc-list': '#!/bin/sh\nprintf "%s\\n" "${TEST_REGISTERED_FONT:-}"\n',
        'fc-cache': '#!/bin/sh\nprintf cache > "$TEST_CACHE_MARKER"\n',
        'curl': '#!/bin/sh\nprintf called >> "$TEST_CURL_MARKER"\nwhile [ "$#" -gt 0 ]; do if [ "$1" = -o ]; then shift; cp "$TEST_ARCHIVE" "$1"; exit; fi; shift; done\nexit 1\n',
    }
    for name, code in scripts.items():
        script = bin_dir / name
        script.write_text(code)
        script.chmod(0o755)
    env = {'HOME': str(home), 'PATH': str(bin_dir) + ':/usr/bin:/bin', 'ATLAS_FONT_DIR': str(target),
           'TEST_CACHE_MARKER': str(root / 'cache'), 'TEST_CURL_MARKER': str(root / 'curl')}
    def run(extra):
        return subprocess.run(['sh', str(repo / 'scripts/fonts.sh')], cwd=root, env=env | extra, capture_output=True, text=True)
    found = run({'TEST_REGISTERED_FONT': 'Monaspace Argon NF'})
    assert found.returncode == 0 and not (root / 'curl').exists(), found.stderr
    bad = root / 'bad.tar.xz'
    bad.write_bytes(b'invalid')
    result = run({'TEST_ARCHIVE': str(bad)})
    assert result.returncode != 0 and 'checksum mismatch' in result.stderr and not target.exists(), result.stderr
    if archive:
        result = run({'TEST_ARCHIVE': archive})
        assert result.returncode == 0, result.stderr
        for face in ('Regular', 'Italic', 'Bold', 'BoldItalic'):
            assert (target / f'MonaspiceArNerdFontMono-{face}.otf').is_file()
        assert (root / 'cache').exists()
        (root / 'curl').unlink()
        result = run({'TEST_ARCHIVE': str(bad)})
        assert result.returncode == 0 and not (root / 'curl').exists(), result.stderr
        print('PASS verified archive installs four faces and reruns without downloading')
    else:
        print('SKIP successful archive installation: set ATLAS_TEST_FONT_ARCHIVE to the v3.5.1 release archive')
    print('PASS existing Argon NF is reused and an invalid archive is rejected before installation')
