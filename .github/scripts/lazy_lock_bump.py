#!/usr/bin/env python3
"""Bump nvim/lazy-lock.json to plugin commits this workflow first saw 7+ days ago.

Renovate can't read lazy-lock.json, so this does the same job for Neovim
plugins (see .github/workflows/nvim-plugins.yml). It deliberately doesn't trust
commit dates: whoever makes a commit sets its date, so a malicious commit can
claim to be a month old. Instead it keeps its own record of when it first saw
each candidate commit (CANDIDATES_JSON, committed alongside the lock):

  old   the lock in the repo
  new   the lock after a headless `:Lazy! update` (in a separate, read-only job),
        i.e. what the plugin specs allow today (AstroNvim pins many plugins to
        tested releases)
  info  each plugin's GitHub URL

For each plugin, lazy's choice joins that plugin's candidate list with today's
date (if it's new). The lock then moves to the newest candidate first seen at
least MIN_AGE_DAYS ago, provided it's newer than the current commit and is
still on the branch lazy now tracks (checked with GitHub's compare API, so a
force-pushed-away commit is never adopted). Nothing ever moves backwards.

A plugin with no lock entry yet (just added to the config) takes lazy's choice
straight away: without an entry, Neovim would install the newest commit anyway.

Usage: lazy_lock_bump.py OLD_LOCK NEW_LOCK PLUGIN_INFO_JSON CANDIDATES_JSON
Rewrites OLD_LOCK and CANDIDATES_JSON; prints a summary. Needs GITHUB_TOKEN
(read access to public repos is enough). NEW_LOCK and PLUGIN_INFO_JSON come from
the job that ran plugin code, so they're validated before use.
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.error
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


def relation(repo, base, head):
    """GitHub's compare status of head relative to base: ahead/behind/identical/diverged."""
    return gh(f"/repos/{repo}/compare/{base}...{head}")["status"]


def valid_lock(lock):
    ok = {}
    for name, e in lock.items():
        if (NAME.match(name) and isinstance(e, dict) and SHA.match(e.get("commit", ""))
                and BRANCH.match(e.get("branch", ""))):
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


def main(old_path, new_path, info_path, cand_path):
    old = valid_lock(json.load(open(old_path)))
    new = valid_lock(json.load(open(new_path)))
    info = json.load(open(info_path))
    try:
        cands = json.load(open(cand_path))
    except FileNotFoundError:
        cands = {}
    today = dt.date.today()
    cutoff = (today - dt.timedelta(days=MIN_AGE_DAYS)).isoformat()

    result, changes = {}, []
    for name in sorted(set(old) | set(new)):
        cur, cand = old.get(name), new.get(name)
        if cand is None:  # dropped from the config
            changes.append(f"{name}: removed")
            cands.pop(name, None)
            continue
        if cur is None:  # just added to the config
            result[name] = cand
            changes.append(f"{name}: added at {cand['commit'][:7]}")
            continue
        result[name] = cur
        # Record lazy's choice as a candidate, dated the first time we see it.
        queue = [c for c in cands.get(name, []) if SHA.match(c.get("commit", ""))]
        if cand["commit"] != cur["commit"] and all(c["commit"] != cand["commit"] for c in queue):
            queue.append({"commit": cand["commit"], "branch": cand["branch"], "seen": today.isoformat()})
        m = GITHUB_URL.match(str(info.get(name, {}).get("url", "")))
        ripe = [c for c in queue if c["seen"] <= cutoff]
        if ripe and m:
            repo, pick = m.group(1), ripe[-1]
            try:
                # newer than what we have, and still on the branch lazy tracks
                if (relation(repo, cur["commit"], pick["commit"]) == "ahead"
                        and relation(repo, pick["commit"], cand["commit"]) in ("ahead", "identical")):
                    result[name] = {"branch": pick["branch"], "commit": pick["commit"]}
                    changes.append(f"{name}: {cur['commit'][:7]} -> {pick['commit'][:7]} (seen {pick['seen']})")
            except urllib.error.HTTPError as e:  # e.g. a commit force-pushed away
                print(f"skip {name}: {e}")
        # Keep only candidates newer than what's now locked.
        locked = result[name]["commit"]
        idx = next((i for i, c in enumerate(queue) if c["commit"] == locked), None)
        queue = queue[idx + 1:] if idx is not None else [c for c in queue if c["commit"] != locked]
        if queue:
            cands[name] = queue
        else:
            cands.pop(name, None)

    write_lock(old_path, result)
    with open(cand_path, "w") as f:
        json.dump(dict(sorted(cands.items())), f, indent=1)
        f.write("\n")
    waiting = sum(len(v) for v in cands.values())
    print("\n".join(changes) if changes else "no changes")
    print(f"{waiting} newer commit(s) waiting out their {MIN_AGE_DAYS} days")


if __name__ == "__main__":
    main(*sys.argv[1:5])
