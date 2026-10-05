#!/usr/bin/env python3
"""Bump nvim/lazy-lock.json, but only to commits at least MIN_AGE_DAYS old.

Renovate can't read lazy-lock.json, so this does the same job for Neovim
plugins (see .github/workflows/nvim-plugins.yml):

  old   the lock in the repo
  new   the lock after a headless `:Lazy! update`, which respects the plugin
        specs (AstroNvim pins many plugins to tested releases)
  info  each plugin's GitHub URL and whether it follows a release tag

For each plugin:
  - unchanged by lazy: keep it
  - follows a release tag: take lazy's choice only if that commit is old enough
    (otherwise keep the old one until a later run)
  - follows a branch: take the newest commit on the branch that is old enough,
    if it's newer than the one we have (never move backwards)

Usage: lazy_lock_bump.py OLD_LOCK NEW_LOCK PLUGIN_INFO_JSON
Writes the result over OLD_LOCK and prints a summary. Needs GITHUB_TOKEN.
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.request

MIN_AGE_DAYS = 7
API = "https://api.github.com"


def gh(path):
    req = urllib.request.Request(API + path, headers={
        "Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
        "Accept": "application/vnd.github+json",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def repo_of(url):
    m = re.match(r"https://github\.com/([^/]+/[^/]+?)(?:\.git)?/?$", url or "")
    return m.group(1) if m else None


def commit_date(repo, sha):
    c = gh(f"/repos/{repo}/commits/{sha}")
    return dt.datetime.fromisoformat(c["commit"]["committer"]["date"].replace("Z", "+00:00"))


def newest_before(repo, branch, cutoff):
    cs = gh(f"/repos/{repo}/commits?sha={branch}&until={cutoff.strftime('%Y-%m-%dT%H:%M:%SZ')}&per_page=1")
    return cs[0]["sha"] if cs else None


def write_lock(path, lock):
    # lazy.nvim's own layout: one plugin per line, sorted, so diffs stay small.
    lines = [f'  {json.dumps(k)}: {{ "branch": {json.dumps(v["branch"])}, "commit": {json.dumps(v["commit"])} }}'
             for k, v in sorted(lock.items(), key=lambda kv: kv[0].lower())]
    with open(path, "w") as f:
        f.write("{\n" + ",\n".join(lines) + "\n}\n")


def main(old_path, new_path, info_path):
    old, new, info = (json.load(open(p)) for p in (old_path, new_path, info_path))
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=MIN_AGE_DAYS)
    result, changes = {}, []
    for name, entry in old.items():
        result[name] = dict(entry)
        cand = new.get(name)
        if not cand or cand["commit"] == entry["commit"]:
            continue
        repo = repo_of(info.get(name, {}).get("url"))
        if not repo:
            print(f"skip {name}: not a GitHub plugin")
            continue
        try:
            if info[name].get("versioned"):
                if commit_date(repo, cand["commit"]) <= cutoff:
                    result[name] = dict(cand)
                else:
                    print(f"wait {name}: release {cand['commit'][:7]} is under {MIN_AGE_DAYS} days old")
            else:
                branch = cand.get("branch") or entry["branch"]
                sha = newest_before(repo, branch, cutoff)
                if sha and sha != entry["commit"] and commit_date(repo, sha) > commit_date(repo, entry["commit"]):
                    result[name] = {"branch": branch, "commit": sha}
        except Exception as e:  # one plugin's API trouble shouldn't block the rest
            print(f"skip {name}: {e}")
            continue
        if result[name]["commit"] != entry["commit"]:
            changes.append(f"{name}: {entry['commit'][:7]} -> {result[name]['commit'][:7]}")
    # Plugins lazy added or removed (spec changes) follow lazy's new lock.
    for name in set(new) - set(old):
        result[name] = new[name]
        changes.append(f"{name}: added")
    for name in set(old) - set(new):
        result.pop(name, None)
        changes.append(f"{name}: removed")
    write_lock(old_path, result)
    print("\n".join(changes) if changes else "no changes")


if __name__ == "__main__":
    main(*sys.argv[1:4])
