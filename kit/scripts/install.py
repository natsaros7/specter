"""Installer logic for install.sh. Python 3.8+, stdlib only. Idempotent: every write is a full copy or a marker block."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

BEGIN, END = "<!-- specter:begin -->", "<!-- specter:end -->"
KIT_PARTS = ("AGENT_RULES.md", "playbooks", "templates", "roles", "scripts", "hooks", "docs")
HOOK_TAG = "specter"
ROLE_TAG = ".specs/kit/roles/"


HOME = Path.home()
# name: (project signals, CLI names, user dirs, project skill dir, user skill dir)
AGENTS = {
    "claude": ([".claude", "CLAUDE.md"], ["claude"], [".claude"], ".claude/skills", ".claude/skills"),
    "codex": ([".codex", ".agents"], ["codex"], [".codex"], ".agents/skills", ".agents/skills"),
    "cursor": ([".cursor"], ["cursor-agent", "cursor"], [".cursor"], ".cursor/skills", ".cursor/skills"),
    "gemini": ([".gemini", "GEMINI.md"], ["gemini"], [".gemini"], ".gemini/skills", ".gemini/skills"),
    "copilot": ([".github/copilot-instructions.md", ".github/skills"], ["copilot"], [".copilot"], ".github/skills", ".copilot/skills"),
}


def detect_agents(target, args):
    forced = [a.split("=", 1)[1] for a in args if a.startswith("--agents=")]
    if forced:
        return [a for a in forced[0].split(",") if a in AGENTS]
    # Files in the project say what the team uses; CLIs and home folders only say what this machine has.
    in_project = [n for n, (signals, _, _, _, _) in AGENTS.items() if any((target / s).exists() for s in signals)]
    if in_project:
        return in_project
    return MACHINE + [n for n, (_, clis, user_dirs, _, _) in AGENTS.items()
            if any(shutil.which(c) for c in clis) or any((HOME / d).is_dir() for d in user_dirs)]


MACHINE = []  # marker: detect_agents fell back to what is installed on this machine


def detection_source(target):
    forced = any(a.startswith("--agents=") for a in ARGS)
    in_project = any((target / s).exists() for signals, _, _, _, _ in AGENTS.values() for s in signals)
    return "override" if forced else ("project files" if in_project else "this machine (no agent files in the project)")


BUILD_FILES = ("pom.xml", "build.gradle", "build.gradle.kts", "package.json", "go.mod", "Cargo.toml",
               "pyproject.toml", "setup.py", "composer.json", "Gemfile", "mix.exs")
SOURCE_DIRS = ("src", "app", "lib", "cmd", "internal", "pkg")


def detect_code_globs(target):
    """Source folders at the root and in first-level modules (anything holding a build file or a child repo)."""
    globs = [d + "/*" for d in SOURCE_DIRS if (target / d).is_dir()]
    for module in sorted(p for p in target.iterdir() if p.is_dir() and not p.name.startswith(".")):
        if any((module / b).exists() for b in BUILD_FILES) or (module / ".git").exists():
            globs += [module.name + "/" + d + "/*" for d in SOURCE_DIRS if (module / d).is_dir()]
    return globs


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
    src = (kit_home / "kit/skill/spec-first/SKILL.md").read_text()
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


def install(kit_home, target):
    specs = target / ".specs"
    kit = specs / "kit"
    print("Installing specter into " + str(specs))
    for part in KIT_PARTS:
        src, dst = kit_home / "kit" / part, kit / part
        if dst.exists():
            shutil.rmtree(dst) if dst.is_dir() else dst.unlink()
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns("install.py", "__pycache__")) if src.is_dir() else shutil.copy(src, dst)
    version = (kit_home / "VERSION").read_text().strip()
    (kit / "VERSION").write_text(version + "\n")
    say(".specs/kit/ " + version + ": rules, playbooks, templates, roles, scripts, docs")

    config_path = specs / "spec-kit.json"
    top = git(target, "rev-parse", "--show-toplevel").stdout.strip()
    is_repo = bool(top) and Path(top).resolve() == target
    repos = nested_repos(target)
    if not config_path.exists():
        config = json.loads((kit_home / "kit/spec-kit.json").read_text())
        if repos or not is_repo:
            config["spec_sync"] = "off"
        config["code_globs"] = detect_code_globs(target) or config["code_globs"]
        config["kit_version"] = version
        config_path.write_text(json.dumps(config, indent=2) + "\n")
        say(".specs/spec-kit.json (code paths: " + ", ".join(config["code_globs"][:4])
            + ("…" if len(config["code_globs"]) > 4 else "") + "; setup confirms them)")
    else:
        config = json.loads(config_path.read_text())
        if config.get("kit_version") != version:
            say("upgrade " + str(config.get("kit_version")) + " -> " + version + " (your settings kept)")
            config["kit_version"] = version
            config_path.write_text(json.dumps(config, indent=2) + "\n")
    rules = (kit / "AGENT_RULES.md").read_text()
    put_block(target / "AGENTS.md", rules)
    say("AGENTS.md: spec rules block (Codex, Cursor, Copilot, Gemini and others read this)")

    agents = detect_agents(target, ARGS)
    say("agents (" + detection_source(target) + "): " + (", ".join(agents) or "none; AGENTS.md alone works with most agents"))
    for name in agents:
        install_skill(kit_home, target / AGENTS[name][3])
        say("skill spec-first -> " + AGENTS[name][3] + "/spec-first/")
    if "claude" in agents:
        put_block(target / "CLAUDE.md", rules)
        say("CLAUDE.md: spec rules block")
        for agent in sorted((kit_home / "kit/adapters/claude/agents").glob("*.md")):
            dst = target / ".claude/agents" / agent.name
            if dst.exists() and ROLE_TAG not in dst.read_text():
                say(".claude/agents/" + agent.name + " exists and is yours: kept it")
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(agent, dst)
        say(".claude/agents: planner / generator / reviewer (sub-agents for .specs/kit/roles/)")
    if "cursor" in agents and (target / ".cursor").is_dir():
        header = (kit_home / "kit/adapters/cursor/spec-first.mdc").read_text()
        (target / ".cursor/rules").mkdir(parents=True, exist_ok=True)
        (target / ".cursor/rules/spec-first.mdc").write_text(header + rules)
        say(".cursor/rules/spec-first.mdc")
    if put_block(target / ".github/copilot-instructions.md", rules, create=False):
        say(".github/copilot-instructions.md: spec rules block")
    if put_block(target / "GEMINI.md", rules, create=False):
        say("GEMINI.md: spec rules block")

    if repos:
        say("multi-repo workspace (" + ", ".join(repos[:5]) + ("…" if len(repos) > 5 else "") + "): "
            "no git hook, since code commits happen in the child repos. Specs are kept in sync by the agent rules + review.")
    elif is_repo:
        install_hook(target, "mode from .specs/spec-kit.json")
    else:
        say("not a git repo: no hook. Run `git init` here if you want the specs versioned.")

    if "--from-go" in ARGS:
        print("\nDone. Continue with .specs/kit/playbooks/setup.md (GO.md step 5).")
    else:
        print("\nDone. Next: open your agent in " + str(target) + " and say:\n"
              "  \"Set up the spec system: follow .specs/kit/playbooks/setup.md\"")


def uninstall(target):
    specs = target / ".specs"
    shutil.rmtree(specs / "kit", ignore_errors=True)
    for f in ("AGENTS.md", "CLAUDE.md", ".github/copilot-instructions.md", "GEMINI.md"):
        drop_block(target / f)
    for f in (".cursor/rules/spec-first.mdc",):
        (target / f).unlink() if (target / f).exists() else None
    for _, _, _, skill_dir, _ in AGENTS.values():
        shutil.rmtree(target / skill_dir / "spec-first", ignore_errors=True)
    for agent in (target / ".claude/agents").glob("*.md"):
        if ROLE_TAG in agent.read_text():
            agent.unlink()
    hooks = git(target, "rev-parse", "--path-format=absolute", "--git-path", "hooks").stdout.strip()
    hook = Path(hooks) / "pre-commit" if hooks else None
    if hook and hook.exists() and HOOK_TAG in hook.read_text():
        hook.unlink()
    print("Removed the kit, marker blocks, skill, role agents and hook. Your specs in .specs/ are kept.")


ARGS = []


def main(argv):
    kit_home, args = Path(argv[0]), argv[1:]
    global ARGS
    ARGS = args
    if "--user" in args:
        agents = detect_agents(Path.cwd(), args)
        for name in agents:
            install_skill(kit_home, HOME / AGENTS[name][4])
            print("  skill spec-first -> ~/" + AGENTS[name][4] + "/spec-first/")
        print("In any project, ask your agent to \"install spec-first here\"." if agents else "No agents detected; use --agents=codex,claude")
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
    if "--detect" in args:
        agents = detect_agents(target, args)
        print("agents: " + (",".join(agents) or "none") + "\nsource: " + detection_source(target))
        return 0
    if "--uninstall" in args:
        uninstall(target)
    else:
        install(kit_home, target)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
