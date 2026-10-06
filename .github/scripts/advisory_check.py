#!/usr/bin/env python3
"""Check pinned dependencies against public security advisories and repo health.

  advisory_check.py changed BASE_REF   versions this branch changes vs BASE_REF
                                       (run on Renovate's update branches: a
                                       failure stops Renovate merging)
  advisory_check.py all                every pin, weekly

Release pins (the '# renovate:' lines in dot_proto/dot_prototools.tmpl and
.chezmoidata.toml) are looked up in:
  - GitHub security advisories published by the tool's own repo
    (github-releases), checked against the pinned version's range
  - OSV (osv.dev) for npm packages and Go's standard library
Node and Python runtimes have no version-indexed advisory feed here; their
releases are covered by the 7-day wait only.

In `all` mode, repos pinned to commits (.chezmoidata.toml [git_pins], and
.github/nvim-plugin-repos.json) and the release repos get health checks:
  - BLOCK: the repo is gone
  - REVIEW: moved to another owner or name (usually harmless, but also a
    takeover route), archived (unmaintained), or has published security
    advisories (commit pins can't be matched to version ranges)

Writes a Markdown report to $REPORT (if set); exits 1 if anything BLOCKs.
Needs GITHUB_TOKEN.
"""
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tomllib
import urllib.error
import urllib.request

PROTOTOOLS = "dot_proto/dot_prototools.tmpl"
DATA = ".chezmoidata.toml"
NVIM_REPOS = ".github/nvim-plugin-repos.json"
# Exactly Renovate's pattern (renovate.json customManagers), so the check sees
# every pin Renovate can change; changed mode also fails closed on any changed
# pin line it didn't account for.
PIN = re.compile(r"# renovate: datasource=(?P<ds>[a-z-]+) depName=(?P<dep>\S+)"
                 r"(?: extractVersion=(?P<ev>\S+))?\s*\n"
                 r"(?P<key>[A-Za-z0-9_-]+) = \"(?P<ver>[^\"]+)\"")
VERSION_LINE = re.compile(r'^[+-](?P<key>[A-Za-z0-9_-]+) = "(?P<ver>[^"]+)"\s*$')
REPO = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


def http(url, data=None, github=False):
    headers = {"Accept": "application/json"}
    if github:
        headers |= {"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
                    "Accept": "application/vnd.github+json"}
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data else None,
                                 headers=headers | ({"Content-Type": "application/json"} if data else {}))
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def gh_all(path):
    """Every page of a GitHub list endpoint (an advisory on page 2 still counts)."""
    out, page = [], 1
    while True:
        sep = "&" if "?" in path else "?"
        batch = http(f"https://api.github.com{path}{sep}per_page=100&page={page}", github=True)
        out += batch
        if len(batch) < 100:
            return out
        page += 1


def osv_all(pkg, version):
    vulns, token = [], None
    while True:
        res = http("https://api.osv.dev/v1/query",
                   {"package": pkg, "version": version} | ({"page_token": token} if token else {}))
        vulns += res.get("vulns", [])
        token = res.get("next_page_token")
        if not token:
            return vulns


def vtuple(v):
    return tuple(int(x) for x in re.findall(r"\d+", v.split("+")[0].split("-")[0])[:4])


def in_range(version, spec):
    """GitHub advisory ranges: '>= 1.2.0, < 1.4.3' or '= 2.0.0' (v prefixes allowed)."""
    v = vtuple(version)
    for part in filter(None, (p.strip() for p in spec.split(","))):
        m = re.match(r"(>=|<=|>|<|=)?\s*v?(.+)", part)
        op, bound = m.group(1) or "=", vtuple(m.group(2))
        if not bound:
            return True  # can't read this bound: assume affected (fail closed)
        if not {">=": v >= bound, "<=": v <= bound, ">": v > bound,
                "<": v < bound, "=": v == bound}[op]:
            return False
    return True


def release_pins(text):
    return {m["dep"]: (m["ds"], m["ver"], m["key"]) for m in PIN.finditer(text)}


def pins_at(ref=None):
    def read(path):
        if ref is None:
            return open(path).read()
        return subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, text=True).stdout
    return release_pins(read(PROTOTOOLS)) | release_pins(read(DATA))


def advisories_for(ds, dep, version):
    """Advisories for this exact version: list of (id, url, certain). certain is
    True when the advisory's range covers the version, or the advisory's
    publication date when it gives no version range at all (e.g. 'master'):
    old ones are for a person to judge (blocking would block every update),
    but a recent one blocks updates."""
    found = []
    if ds == "github-releases" and REPO.match(dep):
        if not vtuple(version):
            raise ValueError(f"can't read version {version!r}")
        for adv in gh_all(f"/repos/{dep}/security-advisories?state=published"):
            for vuln in adv.get("vulnerabilities") or []:
                rng = vuln.get("vulnerable_version_range") or ""
                if not rng:
                    continue
                if not re.search(r"\d", rng):
                    found.append((adv["ghsa_id"], adv.get("html_url", ""), adv.get("published_at") or ""))
                    break
                # Some ranges are open-ended ('>= v2.28.0') with the fix given
                # separately ('v2.98.0'): only then does the fix bound the range.
                # A range with its own upper bound is taken as written.
                fixed = [vtuple(p) for p in re.split(r"[,\s]+", vuln.get("patched_versions") or "") if vtuple(p)]
                if fixed and not re.search(r"<", rng) and vtuple(version) >= min(fixed):
                    continue
                if in_range(version, rng):
                    found.append((adv["ghsa_id"], adv.get("html_url", ""), True))
                    break
    elif ds in ("npm", "golang-version"):
        pkg = {"name": dep, "ecosystem": "npm"} if ds == "npm" else {"name": "stdlib", "ecosystem": "Go"}
        found += [(v["id"], f"https://osv.dev/vulnerability/{v['id']}", True) for v in osv_all(pkg, version)]
    return found


def repo_health(repo):
    """(level, message) problems for a GitHub repo, or []."""
    try:
        info = http(f"https://api.github.com/repos/{repo}", github=True)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return [("BLOCK", "repo is gone (404)")]
        raise
    out = []
    if info["full_name"].lower() != repo.lower():
        out.append(("REVIEW", f"repo now resolves to {info['full_name']}: moved or transferred."
                    " Usually a rename or a move into an organisation; a move to a"
                    " different person deserves a look before trusting new commits"))
    if info.get("archived"):
        out.append(("REVIEW", "archived (no longer maintained)"))
    advs = gh_all(f"/repos/{repo}/security-advisories?state=published")
    if advs:
        out.append(("REVIEW", f"has {len(advs)} published security advisor{'y' if len(advs) == 1 else 'ies'}: "
                    + ", ".join(a["ghsa_id"] for a in advs[:5]) + (", ..." if len(advs) > 5 else "")))
    return out


def main(mode, base=None):
    findings = []  # (level, what, message)

    if mode == "changed":
        # Compare with where this branch left main, not main's latest commit.
        base = subprocess.run(["git", "merge-base", base, "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
        old, new = pins_at(base), pins_at()
        targets = {d: v for d, v in new.items() if old.get(d) != v}
        # Every changed `name = "version"` line in the pin files must be one of
        # the pins checked above; anything else blocks (fail closed).
        diff = subprocess.run(["git", "diff", "-U0", base, "--", PROTOTOOLS, DATA],
                              capture_output=True, text=True, check=True).stdout
        checked = {(key, ver) for _, ver, key in targets.values()}
        for line in diff.splitlines():
            m = VERSION_LINE.match(line)
            if m and line.startswith("+") and (m["key"], m["ver"]) not in checked:
                findings.append(("BLOCK", f'{m["key"]} {m["ver"]}',
                                 "changed pin line this check couldn't match to a '# renovate:' pin"))
    else:
        targets = pins_at()
    recent = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=90)).isoformat()
    for dep, (ds, ver, _) in sorted(targets.items()):
        try:
            for adv_id, url, certain in advisories_for(ds, dep, ver):
                if certain is True:
                    findings.append(("BLOCK", f"{dep} {ver}", f"affected by {adv_id} {url}"))
                elif mode == "changed" and str(certain) >= recent:
                    # No version range, but new: don't adopt a fresh release
                    # while a fresh, unbounded advisory is open against it.
                    findings.append(("BLOCK", f"{dep} {ver}",
                                     f"{adv_id} (published {str(certain)[:10]}) gives no version range: {url}"))
                else:
                    findings.append(("REVIEW", f"{dep} {ver}",
                                     f"{adv_id} gives no version range, so may apply: {url}"))
        except Exception as e:  # an update we can't check doesn't merge (fail closed)
            findings.append(("BLOCK" if mode == "changed" else "REVIEW", f"{dep} {ver}",
                             f"couldn't check advisories: {e}"))

    if mode == "all":
        repos = {d for d, (ds, _, _) in targets.items() if ds == "github-releases"}
        repos |= set(tomllib.load(open(DATA, "rb")).get("git_pins", {}))
        if os.path.exists(NVIM_REPOS):
            repos |= set(json.load(open(NVIM_REPOS)).values())
        for repo in sorted(r for r in repos if REPO.match(r)):
            try:
                for level, msg in repo_health(repo):
                    findings.append((level, repo, msg))
            except Exception as e:
                findings.append(("REVIEW", repo, f"couldn't check: {e}"))

    blocks = [f for f in findings if f[0] == "BLOCK"]
    checked = f"{len(targets)} pinned version(s)" + (" and their repos" if mode == "all" else "")
    lines = [f"Checked {checked}: {len(blocks)} blocking, {len(findings) - len(blocks)} to review.", ""]
    for level, what, msg in findings:
        lines.append(f"- **{level}** `{what}`: {msg}")
    report = "\n".join(lines)
    print(report)
    if os.environ.get("REPORT"):
        open(os.environ["REPORT"], "w").write(report + "\n")
    return 1 if blocks else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
