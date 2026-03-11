#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="evals-skills"
PLUGIN_ID="${PLUGIN_NAME}@local"
REPO_URL="https://github.com/hamelsmu/evals-skills"
TARGET="$HOME/.cursor/plugins/$PLUGIN_NAME"
CLAUDE_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

command -v git >/dev/null || { echo "Error: git is required." >&2; exit 1; }
command -v python3 >/dev/null || { echo "Error: python3 is required." >&2; exit 1; }

TMPDIR_CLONE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CLONE"' EXIT

echo "Downloading $PLUGIN_NAME..."
git clone --depth 1 --quiet "$REPO_URL" "$TMPDIR_CLONE"

echo "Installing to $TARGET..."
rm -rf "$TARGET"
mkdir -p "$TARGET"
for item in .cursor-plugin skills meta-skill.md; do
  [ -e "$TMPDIR_CLONE/$item" ] && cp -R "$TMPDIR_CLONE/$item" "$TARGET/"
done

echo "Registering plugin..."
mkdir -p "$HOME/.claude/plugins"

python3 - "$CLAUDE_PLUGINS" "$PLUGIN_ID" "$TARGET" <<'PY'
import json, os, sys
path, pid, ipath = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except (json.JSONDecodeError, IOError):
        data = {}
plugins = data.get("plugins", {})
entries = [e for e in plugins.get(pid, [])
           if not (isinstance(e, dict) and e.get("scope") == "user")]
entries.insert(0, {"scope": "user", "installPath": ipath})
plugins[pid] = entries
data["plugins"] = plugins
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY

python3 - "$CLAUDE_SETTINGS" "$PLUGIN_ID" <<'PY'
import json, os, sys
path, pid = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except (json.JSONDecodeError, IOError):
        data = {}
data.setdefault("enabledPlugins", {})[pid] = True
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY

echo ""
echo "Installed $PLUGIN_NAME. Restart Cursor to load the skills."
echo "Skills will appear in Settings > Rules, Skills, Subagents > Skills."
