"""Credential regressions using isolated Git configuration and synthetic API responses."""

import pathlib, subprocess, tempfile, os, json, stat
repo = pathlib.Path(__file__).resolve().parents[1]
s = (repo / 'scripts/git.sh').read_text()
select = s[s.index('forge_curl()'):s.index('# 3. repository context')]
install = s[s.index('# 6. Persist'):s.index('# 7. setup')]
with tempfile.TemporaryDirectory() as td:
    d = pathlib.Path(td)
    home = d / 'home'
    home.mkdir()
    work = d / 'repo'
    work.mkdir()
    bin = d / 'bin'
    bin.mkdir()
    env = {'PATH': str(bin) + ':/usr/bin:/bin', 'HOME': str(home), 'GIT_CONFIG_SYSTEM': str(d / 'system'), 'GIT_TERMINAL_PROMPT': '0', 'GH_TOKEN': 'selected-gh', 'GL_TOKEN': 'selected-gl', 'GITHUB_TOKEN': 'foreign', 'IS_INTERACTIVE': 'false'}

    def git(*a):
        return subprocess.run(['git', *a], cwd=work, env=env, check=True, text=True, capture_output=True).stdout
    git('init', '-q')
    curl = bin / 'curl'
    curl.write_text('#!/bin/sh\nheader=$(cat)\ncase "$header" in\n *selected-gh*) printf \'{"login":"iamvikshan"}\' ;;\n *selected-gl*) printf \'{"username":"vikshan"}\' ;;\n *) printf \'{"login":"foreign","username":"foreign"}\' ;;\nesac\n')
    curl.chmod(493)
    base = 'set -e\nlog_fail() { echo "$1" >&2; exit 1; }; log_ok() { :; }; log_warn() { :; }; lowercase() { printf "%s" "$1" | tr "[:upper:]" "[:lower:]"; }; GH_USERNAME=iamvikshan; GL_USERNAME=vikshan; REPO_ROOT="$PWD"\n'

    def run(e=env, code=select + install):
        return subprocess.run(['sh', '-c', base + code], cwd=work, env=e, text=True, capture_output=True)
    git('config', '--global', 'credential.helper', '!echo username=foreign; echo password=foreign')
    git('config', '--local', 'credential.https://github.com/owner/repo.helper', '!echo username=foreign; echo password=foreign')
    git('config', '--system', 'http.https://github.com/owner/repo.extraheader', 'Authorization: fake')
    r = run()
    assert r.returncode == 0, r.stderr
    f = home / '.local/share/atlas/credentials.json'
    assert stat.S_IMODE(f.stat().st_mode) == 384
    assert stat.S_IMODE(f.parent.stat().st_mode) == 448
    original = f.read_bytes()

    def fill(host, envx=env):
        return subprocess.run(['git', 'credential', 'fill'], input=f'protocol=https\nhost={host}\npath=owner/repo\n\n', cwd=work, env=envx, capture_output=True, text=True)
    for host, token in [('github.com', 'selected-gh'), ('gitlab.com', 'selected-gl')]:
        r = fill(host, env | {'GH_TOKEN': 'foreign', 'GL_TOKEN': 'foreign'})
        assert r.returncode == 0 and 'password=' + token in r.stdout, (host, r.stderr)
        r = fill(host, {k: v for k, v in env.items() if k not in ('GH_TOKEN', 'GL_TOKEN', 'GITHUB_TOKEN')})
        assert 'password=' + token in r.stdout
    print('PASS both forges: saved credentials beat inherited helpers/tokens and work without env tokens')
    assert not git('config', '--get-urlmatch', 'http.extraheader', 'https://github.com/owner/repo').strip()
    r = run(env | {'GH_TOKEN': 'foreign', 'GL_TOKEN': 'foreign'})
    assert r.returncode == 0 and f.read_bytes() == original
    print('PASS rerun retains verified store; mode 0600/directory 0700; conflicting local header removed')
    f.unlink()
    r = run(env | {'GH_TOKEN': 'foreign'})
    assert r.returncode != 0 and (not f.exists())
    print('PASS wrong account rejected before saving')
    for content in [None, 'invalid json', json.dumps({'github.com': {'username': 'iamvikshan', 'token': ''}})]:
        if content is not None:
            f.write_text(content)
        elif f.exists():
            f.unlink()
        r = fill('github.com')
        assert r.returncode != 0 and 'foreign' not in r.stdout
    print('PASS missing/corrupt/disabled credentials fail closed')
    f.write_bytes(original)
    helper = home / '.local/bin/git-credential-atlas'
    r = subprocess.run([str(helper), 'get'], input='protocol=http\nhost=github.com\n\n', env=env, capture_output=True, text=True)
    assert r.stdout == 'quit=true\n\n'
    print('PASS refuses non-HTTPS credential requests')
