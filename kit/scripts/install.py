"""Installer logic for install.sh. Python 3.8+, stdlib only. Idempotent: every write is a full copy or a marker block."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

BEGIN, END = "<!-- spec-first-kit:begin -->", "<!-- spec-first-kit:end -->"
KIT_PARTS = ("AGENT_RULES.md", "playbooks", "templates", "scripts", "hooks", "docs")
HOOK_TAG = "spec-first-kit"


def say(msg):
    print("  " + msg)


def put_block(path, body, create=True):
    """Insert or replace the marker block in path. Returns True if written."""
    if not path.exists() and not create:
        return False
    text = path.read_text() if path.exists() else ""
    block = BEGIN + "\n" + body.strip() + "\n" + END
    pattern = re.compile(re.escape(BEGIN) + ".*?" + re.escape(END), re.S)
    text = pattern.sub(lambda _: block, text) if pattern.search(text) else (text.rstrip() + "\n\n" + block + "\n").lstrip()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return True


def drop_block(path):
    if path.exists():
        text = re.sub(r"\n*" + re.escape(BEGIN) + ".*?" + re.escape(END) + r"\n?", "\n", path.read_text(), flags=re.S)
        if text.strip():
            path.write_text(text.lstrip("\n"))
        else:
            path.unlink()


def git(target, *args):
    return subprocess.run(["git", "-C", str(target)] + list(args), capture_output=True, text=True)


def nested_repos(target):
    return sorted(p.parent.name for p in target.glob("*/.git"))


def install_skill(kit_home, dest_dir):
    dest = dest_dir / "spec-first"
    dest.mkdir(parents=True, exist_ok=True)
    src = (kit_home / "kit/adapters/claude/skills/spec-first/SKILL.md").read_text()
    (dest / "SKILL.md").write_text(src.replace("{{KIT_HOME}}", str(kit_home)))


def install_hook(target, kit_rules_note):
    hooks = Path(git(target, "rev-parse", "--path-format=absolute", "--git-path", "hooks").stdout.strip())
    hook = hooks / "pre-commit"
    if hook.exists() and HOOK_TAG not in hook.read_text():
        say("pre-commit hook exists and isn't ours: add this line to it yourself:")
        say('  python3 "$(git rev-parse --show-toplevel)/.specs/kit/scripts/spec_sync_check.py" || exit 1')
        return
    hooks.mkdir(parents=True, exist_ok=True)
    shutil.copy(target / ".specs/kit/hooks/pre-commit", hook)
    hook.chmod(0o755)
    say("git pre-commit hook: spec-sync check (" + kit_rules_note + ")")


def install(kit_home, target, with_agents):
    specs = target / ".specs"
    kit = specs / "kit"
    print("Installing spec-first-kit into " + str(specs))
    for part in KIT_PARTS:
        src, dst = kit_home / "kit" / part, kit / part
        if dst.exists():
            shutil.rmtree(dst) if dst.is_dir() else dst.unlink()
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns("install.py", "__pycache__")) if src.is_dir() else shutil.copy(src, dst)
    say(".specs/kit/: playbooks, templates, scripts, docs")

    config_path = specs / "spec-kit.json"
    top = git(target, "rev-parse", "--show-toplevel").stdout.strip()
    is_repo = bool(top) and Path(top).resolve() == target
    repos = nested_repos(target)
    if not config_path.exists():
        config = json.loads((kit_home / "kit/spec-kit.json").read_text())
        if repos or not is_repo:
            config["spec_sync"] = "off"
        config_path.write_text(json.dumps(config, indent=2) + "\n")
        say(".specs/spec-kit.json (defaults; setup tunes it)")

    rules = (kit / "AGENT_RULES.md").read_text()
    put_block(target / "AGENTS.md", rules)
    say("AGENTS.md: spec rules block (Codex, Cursor, Copilot, Gemini and others read this)")

    claude = (target / "CLAUDE.md").exists() or (target / ".claude").is_dir() or shutil.which("claude")
    if claude:
        put_block(target / "CLAUDE.md", rules)
        install_skill(kit_home, target / ".claude/skills")
        say("CLAUDE.md block + .claude/skills/spec-first (/spec-first)")
        if with_agents:
            for agent in sorted((kit_home / "kit/adapters/claude/agents").glob("*.md")):
                dst = target / ".claude/agents" / agent.name
                if dst.exists():
                    say(".claude/agents/" + agent.name + " exists: kept yours")
                    continue
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(agent, dst)
            say(".claude/agents: planner / generator / reviewer")
    if (target / ".cursor").is_dir():
        header = (kit_home / "kit/adapters/cursor/spec-first.mdc").read_text()
        (target / ".cursor/rules").mkdir(parents=True, exist_ok=True)
        (target / ".cursor/rules/spec-first.mdc").write_text(header + rules)
        say(".cursor/rules/spec-first.mdc")
    if put_block(target / ".github/copilot-instructions.md", rules, create=False):
        say(".github/copilot-instructions.md block")
    if put_block(target / "GEMINI.md", rules, create=False):
        say("GEMINI.md block")

    if repos:
        say("multi-repo workspace (" + ", ".join(repos[:5]) + ("…" if len(repos) > 5 else "") + "): "
            "no git hook, since code commits happen in the child repos. Specs are kept in sync by the agent rules + review.")
    elif is_repo:
        install_hook(target, "mode from .specs/spec-kit.json")
    else:
        say("not a git repo: no hook. Run `git init` here if you want the specs versioned.")

    print("\nDone. Next: open your agent in " + str(target) + " and say:\n"
          "  \"Set up the spec system: follow .specs/kit/playbooks/setup.md\"")


def uninstall(target):
    specs = target / ".specs"
    shutil.rmtree(specs / "kit", ignore_errors=True)
    for f in ("AGENTS.md", "CLAUDE.md", ".github/copilot-instructions.md", "GEMINI.md"):
        drop_block(target / f)
    for f in (".cursor/rules/spec-first.mdc",):
        (target / f).unlink() if (target / f).exists() else None
    shutil.rmtree(target / ".claude/skills/spec-first", ignore_errors=True)
    hooks = git(target, "rev-parse", "--path-format=absolute", "--git-path", "hooks").stdout.strip()
    hook = Path(hooks) / "pre-commit" if hooks else None
    if hook and hook.exists() and HOOK_TAG in hook.read_text():
        hook.unlink()
    print("Removed the kit, marker blocks, skill and hook. Your specs in .specs/ and any .claude/agents are kept.")


def main(argv):
    kit_home, args = Path(argv[0]), argv[1:]
    if args == ["--user"]:
        install_skill(kit_home, Path.home() / ".claude/skills")
        print("Installed /spec-first into ~/.claude/skills. In any project, say: \"install spec-first here\".")
        return 0
    targets = [a for a in args if not a.startswith("--")]
    if len(targets) != 1:
        print((kit_home / "install.sh").read_text().split("set -eu")[0])
        return 2
    target = Path(targets[0]).expanduser().resolve()
    if not target.is_dir():
        print("No such directory: " + str(target))
        return 2
    if target == kit_home:
        print("Target is the kit itself. Point it at your project.")
        return 2
    if "--uninstall" in args:
        uninstall(target)
    else:
        install(kit_home, target, "--with-agents" in args)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
