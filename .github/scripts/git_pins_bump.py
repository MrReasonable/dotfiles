#!/usr/bin/env python3
"""Bump the [git_pins] commits in .chezmoidata.toml (see .github/workflows/git-pins.yml).

These are things that publish no releases (zsh plugins, zi, Oh My Zsh files,
Oh my tmux, cheat-sheet repos), so Renovate can't age them safely: a commit's
date is whatever its author says. Instead, like lazy_lock_bump.py, this keeps
its own record of when it first saw each branch head (CANDIDATES_JSON) and
moves a pin to the newest one first seen at least MIN_AGE_DAYS ago, once GitHub
confirms that commit is on the pinned branch, after the current pin (so no
fork commits, nothing force-pushed away, never backwards). Any error keeps the
current pin.

It never runs code from these repos; it only asks GitHub's API about commits.
The repo list and branches come from .chezmoidata.toml itself.

Usage: git_pins_bump.py CHEZMOIDATA_TOML CANDIDATES_JSON   (needs GITHUB_TOKEN)
"""
import datetime as dt
import json
import os
import re
import sys
import tomllib
import urllib.parse
import urllib.request

MIN_AGE_DAYS = 7
API = "https://api.github.com"
SHA = re.compile(r"^[0-9a-f]{40}$")
REPO = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
BRANCH = re.compile(r"^[A-Za-z0-9._/-]+$")


def gh(path):
    req = urllib.request.Request(API + path, headers={
        "Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
        "Accept": "application/vnd.github+json",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def seg(value):
    """One URL path segment, escaped (a branch like '../x' can't redirect the call)."""
    return urllib.parse.quote(value, safe="")


def relation(repo, base, head):
    return gh(f"/repos/{repo}/compare/{seg(base)}...{seg(head)}")["status"]


def main(data_path, cand_path):
    text = open(data_path).read()
    pins = tomllib.loads(text).get("git_pins", {})
    try:
        cands = json.load(open(cand_path))
    except FileNotFoundError:
        cands = {}
    today = dt.date.today()
    cutoff = (today - dt.timedelta(days=MIN_AGE_DAYS)).isoformat()
    changes = []

    for repo, pin in sorted(pins.items()):
        branch, cur = pin.get("branch", ""), pin.get("commit", "")
        if not (REPO.match(repo) and ".." not in repo.split("/") and BRANCH.match(branch)
                and ".." not in branch and SHA.match(cur)):
            print(f"skip {repo}: malformed pin")
            continue
        try:
            head = gh(f"/repos/{repo}/commits/{seg(branch)}")["sha"]
            queue = [c for c in cands.get(repo, []) if isinstance(c, dict) and SHA.match(c.get("commit", ""))]
            if head != cur and all(c["commit"] != head for c in queue):
                queue.append({"commit": head, "seen": today.isoformat()})
            ripe = [c for c in queue if str(c.get("seen", "9999")) <= cutoff]
            new = cur
            if ripe:
                pick = ripe[-1]["commit"]
                # on the branch (reachable from its head) and after the current pin
                if (relation(repo, pick, head) in ("ahead", "identical")
                        and relation(repo, cur, pick) == "ahead"):
                    new = pick
                    changes.append(f"{repo}: {cur[:7]} -> {pick[:7]} (seen {ripe[-1]['seen']})")
            if new != cur:
                # Rewrite just this table's commit line, keeping the file's layout.
                table = re.escape(f'[git_pins."{repo}"]')
                text, n = re.subn(rf'({table}\n(?:[^\[\n].*\n)*?commit = ")({cur})(")',
                                  rf"\g<1>{new}\g<3>", text, count=1)
                if n != 1:
                    raise RuntimeError("couldn't find its commit line")
            idx = next((i for i, c in enumerate(queue) if c["commit"] == new), None)
            queue = queue[idx + 1:] if idx is not None else queue
            if queue:
                cands[repo] = queue
            else:
                cands.pop(repo, None)
        except Exception as e:  # fail closed: keep the current pin
            print(f"skip {repo}: {e}")

    open(data_path, "w").write(text)
    with open(cand_path, "w") as f:
        json.dump(dict(sorted(cands.items())), f, indent=1)
        f.write("\n")
    print("\n".join(changes) if changes else "no changes")
    print(f"{sum(len(v) for v in cands.values())} newer commit(s) waiting out their {MIN_AGE_DAYS} days")


if __name__ == "__main__":
    main(*sys.argv[1:3])
