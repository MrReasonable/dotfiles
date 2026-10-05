#!/usr/bin/env python3
"""Bump nvim/lazy-lock.json to plugin commits this workflow first saw 7+ days ago.

Renovate can't read lazy-lock.json, so this does the same job for Neovim
plugins (see .github/workflows/nvim-plugins.yml). It deliberately doesn't trust
commit dates: whoever makes a commit sets its date, so a malicious commit can
claim to be a month old. Instead it keeps its own record of when it first saw
each candidate commit (CANDIDATES_JSON, committed alongside the lock):

  old   the lock in the repo (trusted)
  info  each plugin's name and GitHub URL, read from the config at the locked
        commits by a job that runs before any plugin is updated (trusted: it
        decides which plugins exist and where they live)
  new   the lock after a headless `:Lazy! update` (untrusted: that job ran the
        updated plugins' own code). Only its commits are used, and only as
        candidates; its plugin names and branches are ignored.

For each plugin, lazy's choice joins that plugin's candidate list with today's
date (if it's new). The lock then moves to the newest candidate first seen at
least MIN_AGE_DAYS ago, but only if GitHub itself confirms it sits on the
plugin's branch (in the trusted repo, between the current commit and the
branch's head right now): so neither an injected fork commit nor a
force-pushed-away one is ever adopted, and nothing moves backwards. Any error
keeps the current commit.

Plugins in the trusted list but not the lock (just added to the config) take
lazy's choice straight away, once GitHub confirms it's on the branch: without
an entry, Neovim would install the newest commit anyway.

Two more guards, because a plugin you've just added has no locked commit, so
the trusted job runs its latest code too and could tamper with the list:
  - each plugin's repo is pinned in URLS_JSON the first time it's seen; if the
    list later names a different repo, that plugin is left alone (and reported)
  - lock entries are never removed (a stale entry is harmless: lazy ignores
    entries for plugins that aren't in the config)

Usage: lazy_lock_bump.py OLD_LOCK NEW_LOCK TRUSTED_INFO_JSON CANDIDATES_JSON URLS_JSON
Rewrites OLD_LOCK and CANDIDATES_JSON; prints a summary. Needs GITHUB_TOKEN
(read access to public repos is enough).
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

MIN_AGE_DAYS = 7
API = "https://api.github.com"
SHA = re.compile(r"^[0-9a-f]{40}$")
NAME = re.compile(r"^[A-Za-z0-9._-]+$")
BRANCH = re.compile(r"^[A-Za-z0-9._/-]+$")
GITHUB_URL = re.compile(r"^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?/?$")


def gh(path):
    req = urllib.request.Request(API + path, headers={
        "Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
        "Accept": "application/vnd.github+json",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def seg(value):
    """One URL path segment: escaped, so a branch like '../../x' can't redirect the call."""
    return urllib.parse.quote(value, safe="")


def relation(repo, base, head):
    """GitHub's compare status of head relative to base: ahead/behind/identical/diverged."""
    return gh(f"/repos/{repo}/compare/{seg(base)}...{seg(head)}")["status"]


def valid_lock(lock):
    ok = {}
    for name, e in lock.items():
        if (NAME.match(name) and isinstance(e, dict) and SHA.match(e.get("commit", ""))
                and BRANCH.match(e.get("branch", "")) and ".." not in e["branch"]):
            ok[name] = {"branch": e["branch"], "commit": e["commit"]}
        else:
            print(f"ignoring malformed lock entry: {name!r}")
    return ok


def write_lock(path, lock):
    # lazy.nvim's own layout (one plugin per line, plain sort), so diffs stay small.
    lines = [f'  {json.dumps(k)}: {{ "branch": {json.dumps(v["branch"])}, "commit": {json.dumps(v["commit"])} }}'
             for k, v in sorted(lock.items())]
    with open(path, "w") as f:
        f.write("{\n" + ",\n".join(lines) + "\n}\n")


def on_branch(repo, branch, base, sha):
    """True if GitHub says sha is on branch, after base (base=None: anywhere)."""
    head = gh(f"/repos/{repo}/commits/{seg(branch)}")["sha"]
    if relation(repo, sha, head) not in ("ahead", "identical"):
        return False  # not reachable from the branch head (fork commit, or gone)
    return base is None or relation(repo, base, sha) == "ahead"


def main(old_path, new_path, info_path, cand_path, urls_path):
    old = valid_lock(json.load(open(old_path)))
    new = valid_lock(json.load(open(new_path)))
    trusted, spec_branch = {}, {}
    for name, v in json.load(open(info_path)).items():
        m = GITHUB_URL.match(str(v.get("url", ""))) if isinstance(v, dict) else None
        if NAME.match(name) and m and not {".", ".."} & set(m.group(1).split("/")):
            trusted[name] = m.group(1)
            b = v.get("branch")
            if isinstance(b, str) and BRANCH.match(b) and ".." not in b:
                spec_branch[name] = b
    try:
        cands = json.load(open(cand_path))
    except FileNotFoundError:
        cands = {}
    try:
        pinned_repo = json.load(open(urls_path))
    except FileNotFoundError:
        pinned_repo = {}
    today = dt.date.today()
    cutoff = (today - dt.timedelta(days=MIN_AGE_DAYS)).isoformat()

    result, changes = dict(old), []  # never removes an entry
    for name, repo in sorted(trusted.items()):
        if pinned_repo.setdefault(name, repo) != repo:
            changes.append(f"WARNING {name}: config says {repo}, pinned {pinned_repo[name]}; left alone")
            continue
        cur, cand = old.get(name), new.get(name)
        try:
            if cur is None:
                # Just added to the config: check lazy's commit against the
                # branch the (trusted) spec names, else the repo's default as
                # GitHub reports it; never the branch the untrusted job claims.
                if cand:
                    branch = spec_branch.get(name) or gh(f"/repos/{repo}")["default_branch"]
                    if on_branch(repo, branch, None, cand["commit"]):
                        result[name] = {"branch": branch, "commit": cand["commit"]}
                        changes.append(f"{name}: added at {cand['commit'][:7]}")
                continue
            queue = [c for c in cands.get(name, []) if isinstance(c, dict) and SHA.match(c.get("commit", ""))]
            if cand and cand["commit"] != cur["commit"] and all(c["commit"] != cand["commit"] for c in queue):
                queue.append({"commit": cand["commit"], "seen": today.isoformat()})
            ripe = [c for c in queue if str(c.get("seen", "9999")) <= cutoff]
            if ripe and on_branch(repo, cur["branch"], cur["commit"], ripe[-1]["commit"]):
                pick = ripe[-1]
                result[name] = {"branch": cur["branch"], "commit": pick["commit"]}
                changes.append(f"{name}: {cur['commit'][:7]} -> {pick['commit'][:7]} (seen {pick['seen']})")
            locked = result[name]["commit"]
            idx = next((i for i, c in enumerate(queue) if c["commit"] == locked), None)
            queue = queue[idx + 1:] if idx is not None else queue
            if queue:
                cands[name] = queue
            else:
                cands.pop(name, None)
        except Exception as e:  # fail closed: keep the current commit
            print(f"skip {name}: {e}")

    write_lock(old_path, result)
    with open(urls_path, "w") as f:
        json.dump(dict(sorted(pinned_repo.items())), f, indent=1)
        f.write("\n")
    with open(cand_path, "w") as f:
        json.dump(dict(sorted(cands.items())), f, indent=1)
        f.write("\n")
    waiting = sum(len(v) for v in cands.values())
    print("\n".join(changes) if changes else "no changes")
    print(f"{waiting} newer commit(s) waiting out their {MIN_AGE_DAYS} days")


if __name__ == "__main__":
    main(*sys.argv[1:6])
