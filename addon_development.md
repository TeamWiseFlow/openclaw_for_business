# Addon Development Guide

This guide covers everything you need to build addons for **openclaw-for-business**.

---

## 1. Pinned OpenClaw Version

All addon development **must target the exact OpenClaw version pinned by this repository**.
The version and commit hash are stored in [`openclaw.version`](./openclaw.version) at the repo root:

```bash
OPENCLAW_VERSION=2026.3.8
OPENCLAW_COMMIT=f6243916b51ca4b4131674fa2f6fa9d863314c01
```

### Why this matters

- `openclaw-for-business` locks a specific upstream commit — not just the tag — because patch releases can land between tags.
- Your addon's patches and overrides must align with this exact source tree.
- CI in `openclaw-for-business` checks out this commit automatically; your addon CI should do the same.

### How to consume the pin in your addon

**Shell (local dev or CI bootstrap):**

```bash
# From your addon repo root, assuming openclaw-for-business is a sibling directory
source ../openclaw-for-business/openclaw.version   # sets OPENCLAW_VERSION and OPENCLAW_COMMIT

git clone https://github.com/openclaw/openclaw.git openclaw
git -C openclaw checkout $OPENCLAW_COMMIT
```

**GitHub Actions (recommended pattern for addon repos):**

```yaml
- name: Read pinned openclaw version
  id: pin
  run: |
    source path/to/openclaw.version     # or fetch from openclaw-for-business repo
    echo "commit=$OPENCLAW_COMMIT" >> $GITHUB_OUTPUT
    echo "version=$OPENCLAW_VERSION"   >> $GITHUB_OUTPUT

- name: Clone openclaw at pinned commit
  run: |
    git clone https://github.com/openclaw/openclaw.git openclaw
    git -C openclaw checkout ${{ steps.pin.outputs.commit }}
```

> **Tip:** If your addon repo doesn't vendor `openclaw.version` directly, fetch it from
> the raw GitHub URL of this repo's `openclaw.version` before sourcing:
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/TeamWiseFlow/openclaw_for_business/main/openclaw.version \
>   -o openclaw.version
> source openclaw.version
> ```

---

## 2. Addon Structure

An addon is a directory placed under `addons/` that contains an `addon.json` manifest:

```
addons/<your-addon-name>/
├── addon.json            # Required: addon metadata
├── overrides.sh          # Optional: pnpm overrides / dependency replacements
├── patches/
│   └── *.patch           # Optional: git-format patches against openclaw source
├── skills/
│   └── <skill-name>/
│       └── SKILL.md      # Optional: global skills (visible to all agents)
└── crew/
    └── <agent-id>/       # Optional: preconfigured agent workspace + skills
        ├── SOUL.md
        ├── IDENTITY.md
        └── skills/
            └── <skill-name>/
                └── SKILL.md
```

### `addon.json` schema

```json
{
  "name": "my-addon",
  "version": "1.0.0",
  "description": "Short description of what this addon does",
  "openclaw_version": "2026.3.8",
  "openclaw_commit": "f6243916b51ca4b4131674fa2f6fa9d863314c01"
}
```

The `openclaw_version` and `openclaw_commit` fields **must match** the values in `openclaw.version` at the time you develop and test the addon. This lets users and CI detect version mismatches early.

---

## 3. Four-Layer Loading Mechanism

`scripts/apply-addons.sh` processes each layer in order of descending stability:

### Layer 1 — `overrides.sh` (most stable)

Replaces npm/pnpm dependencies before the build. No source line numbers are involved, so this layer survives upstream refactors with zero friction.

```bash
# overrides.sh example
pnpm pkg set pnpm.overrides.some-dep="npm:my-fork@1.2.3"
```

Use this layer for: replacing a bundled dependency with a patched fork, pinning a transitive dep, etc.

### Layer 2 — `patches/*.patch`

Applied via `git am` or `patch -p1` against the openclaw source tree. Precise line-level changes — powerful but fragile if upstream moves the code.

```bash
# Generate a patch from your local changes
cd openclaw
git add -p
git commit -m "my change"
git format-patch HEAD~1 -o ../addons/my-addon/patches/
```

> **Important:** always regenerate patches against the pinned commit, not against `main`.
> Patches that were generated against a different commit are likely to fail.

### Layer 3 — `skills/*/SKILL.md` (global skills)

Drop a `SKILL.md` into `skills/<skill-name>/` and it will be copied into the openclaw global skills directory, making it available to all agents.

By default, all enabled built-in skills are visible to all agents (no allowlist needed).
If you want to restrict a skill to specific agents, place it under `crew/<agent-id>/skills/` instead (Layer 4).

### Layer 4 — `crew/<agent-id>/` (preconfigured agents)

Provide a complete agent workspace template. During `apply-addons.sh`, the agent is:
1. Installed to `~/.openclaw/workspace-<agent-id>/`
2. Registered in `openclaw.json` under `agents.list[]`
3. Managed by the built-in HRBP agent going forward

Skills placed under `crew/<agent-id>/skills/<skill-name>/SKILL.md` are installed as agent-private skills, visible only to that agent.

---

## 4. Development Workflow

1. **Pin openclaw** — clone openclaw at the version from `openclaw.version` (see §1).
2. **Make your changes** — write skills, craft patches, add crew configs.
3. **Test locally** — run `./scripts/apply-addons.sh` from `openclaw-for-business` root with your addon in `addons/`.
4. **Add `openclaw_version` + `openclaw_commit` to `addon.json`** — so users know what version you tested against.
5. **Lock CI** — use the pin pattern from §1 in your addon repo's GitHub Actions.

---

## 5. Publishing Your Addon

Addons are independent git repositories. To share:

1. Host your addon repo publicly (GitHub, etc.)
2. Users install by cloning into `addons/`:
   ```bash
   git clone https://github.com/your-org/your-addon.git addons/your-addon
   ./scripts/apply-addons.sh
   ```
3. Submit a PR to add your addon to the table in `README.md` to get listed in the marketplace.

---

## 6. When openclaw-for-business Upgrades OpenClaw

When this repo bumps `openclaw.version` to a newer commit, addon authors should:

1. Re-clone openclaw at the new commit.
2. Re-test all patches — `git am` failures indicate upstream moved the target code.
3. Regenerate broken patches against the new commit.
4. Update `addon.json` with the new `openclaw_version` and `openclaw_commit`.
5. Re-run your addon CI against the new pin.
