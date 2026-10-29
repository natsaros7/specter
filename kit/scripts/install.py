"""Installer logic for install.sh. Python 3.8+, stdlib only. Idempotent: every write is a full copy or a marker block."""
import datetime
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
RULES_TAG = "Spec-first workflow (specter)"


HOME = Path.home()
# name: (project signals, CLI names, user dirs, project skill dir, user skill dir)
AGENTS = {
    "claude": ([".claude", "CLAUDE.md"], ["claude"], [".claude"], ".claude/skills", ".claude/skills"),
    "codex": ([".codex"], ["codex"], [".codex"], ".agents/skills", ".agents/skills"),
    "cursor": ([".cursor"], ["cursor-agent", "cursor"], [".cursor"], ".cursor/skills", ".cursor/skills"),
    "gemini": ([".gemini", "GEMINI.md"], ["gemini"], [".gemini"], ".gemini/skills", ".gemini/skills"),
    "copilot": ([".github/copilot-instructions.md", ".github/skills"], ["copilot"], [".copilot"], ".github/skills", ".copilot/skills"),
    "antigravity": ([".agent", ".agents/rules", ".agents/workflows"], ["agy"], [".gemini/antigravity-cli", ".gemini/antigravity"],
                    ".agents/skills", ".gemini/antigravity/skills"),
}


def detect_agents(target, args):
    """Return (agents to wire, source, found on machine). Project files say what the team uses; a CLI or home folder
    only says what this machine has, so machine-only finds are reported but not wired unless named with --agents=."""
    forced = [a.split("=", 1)[1] for a in args if a.startswith("--agents=")]
    if forced:
        return [a for a in forced[0].split(",") if a in AGENTS], "override", []
    in_project = [n for n, (signals, _, _, _, _) in AGENTS.items() if any((target / s).exists() for s in signals)]
    if in_project:
        return in_project, "project files", []
    on_machine = [n for n, (_, clis, user_dirs, _, _) in AGENTS.items()
                  if any(shutil.which(c) for c in clis) or any((HOME / d).is_dir() for d in user_dirs)]
    return [], "this machine only", on_machine


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


ROOT = None


def dry():
    return "--dry-run" in ARGS


def say(msg, always=False):
    if always or not dry():
        print("  " + msg)


def write(path, kind, fn):
    """The only way install() touches disk. kind: create, modify or replace. In --dry-run: print and skip fn."""
    if dry():
        print("  " + kind + " " + shown(path))
    else:
        fn()


def put_file(path, text):
    """Write text unless the file already holds it. Returns True when a write was planned."""
    old = path.read_text() if path.exists() else None
    if old == text:
        return False
    def go():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    write(path, "create" if old is None else "replace", go)
    return True


def read_raw(path):
    with open(path, newline="") as f:
        return f.read()


def put_block(path, body, create=True):
    """Insert or replace the marker block in path. Appending never touches existing bytes. Returns False if skipped."""
    if not path.exists() and not create:
        return False
    text = read_raw(path) if path.exists() else ""
    nl = "\r\n" if "\r\n" in text else "\n"
    block = (BEGIN + "\n" + body.strip() + "\n" + END).replace("\n", nl)
    pattern = re.compile(re.escape(BEGIN) + ".*?" + re.escape(END), re.S)
    if pattern.search(text):
        new = pattern.sub(lambda _: block, text)
    elif not text:
        new = block + nl
    else:
        # a file with no trailing newline gets the block with no blank line and no final newline: drop_block restores exact bytes
        new = text + nl + block + (nl if text.endswith(("\n", "\r")) else "")
    if new != text:
        def go():
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, "w", newline="") as f:
                f.write(new)
        write(path, "modify" if text else "create", go)
    return True


def drop_block(path):
    """Remove the marker block and the separator newline put_block added; every other byte stays."""
    if path.exists():
        text = re.sub(r"(?:\r?\n)?" + re.escape(BEGIN) + ".*?" + re.escape(END) + r"(?:\r?\n)?", "", read_raw(path), count=1, flags=re.S)
        if text.strip():
            with open(path, "w", newline="") as f:
                f.write(text)
        else:
            path.unlink()


GITIGNORE_TAG = "# specter"


def ensure_line(path, line):
    """Append line under a `# specter` comment, unless the file already has it (then it is the user's)."""
    text = read_raw(path) if path.exists() else ""
    if line in text.splitlines():
        return
    nl = "\r\n" if "\r\n" in text else "\n"
    def go():
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", newline="") as f:
            f.write(text + ("" if not text or text.endswith(("\n", "\r")) else nl) + GITIGNORE_TAG + nl + line + nl)
    write(path, "modify" if text else "create", go)


def drop_line(path, line):
    """Remove only the line (and its `# specter` comment) that ensure_line added."""
    if not path.exists():
        return
    with open(path, newline="") as f:
        lines = f.read().splitlines(keepends=True)
    kept, i = [], 0
    while i < len(lines):
        if lines[i].rstrip("\r\n") == GITIGNORE_TAG and i + 1 < len(lines) and lines[i + 1].rstrip("\r\n") == line:
            i += 2
            continue
        kept.append(lines[i])
        i += 1
    if len(kept) == len(lines):
        return
    if any(l.strip() for l in kept):
        with open(path, "w", newline="") as f:
            f.write("".join(kept))
    else:
        path.unlink()


def git(target, *args):
    return subprocess.run(["git", "-C", str(target)] + list(args), capture_output=True, text=True)


def nested_repos(target):
    return sorted(p.parent.name for p in target.glob("*/.git"))


def ours(path):
    """True when specter wrote path (a missing file is not ours). Kit dir: VERSION plus the rules marker."""
    if path.is_dir():
        rules = path / "AGENT_RULES.md"
        return (path / "VERSION").exists() and rules.exists() and RULES_TAG in rules.read_text()
    if not path.is_file():
        return False
    text = path.read_text(errors="replace")
    if path.name == "SKILL.md":
        return "name: spec-first" in text and ".specs/kit/" in text
    return (RULES_TAG if path.suffix == ".mdc" else ROLE_TAG) in text


def writable(path):
    """True when path is absent or ours; otherwise say it is the user's and keep it."""
    if not path.exists() or ours(path):
        return True
    say(shown(path) + " exists and is yours: kept it", True)
    return False


def shown(path):
    try:
        return path.relative_to(ROOT).as_posix()
    except (ValueError, TypeError):
        return str(path)


def install_skill(kit_home, dest_dir):
    dst = dest_dir / "spec-first" / "SKILL.md"
    if not writable(dst):
        return False
    src = (kit_home / "kit/skill/spec-first/SKILL.md").read_text()
    put_file(dst, src.replace("{{KIT_HOME}}", str(kit_home)))
    return True


def install_hook(kit_home, kit_rules_note):
    hooks = Path(git(ROOT, "rev-parse", "--path-format=absolute", "--git-path", "hooks").stdout.strip())
    hook = hooks / "pre-commit"
    if hook.exists() and HOOK_TAG not in hook.read_text():
        say("pre-commit hook exists and isn't ours: add this line to it yourself:", True)
        say('  python3 "$(git rev-parse --show-toplevel)/.specs/kit/scripts/spec_sync_check.py" || exit 1', True)
        return
    def go():
        hooks.mkdir(parents=True, exist_ok=True)
        shutil.copy(kit_home / "kit/hooks/pre-commit", hook)
        hook.chmod(0o755)
    write(hook, "replace" if hook.exists() else "create", go)
    say("git pre-commit hook: spec-sync check (" + kit_rules_note + ")")


def hook_ours(target):
    hooks = git(target, "rev-parse", "--path-format=absolute", "--git-path", "hooks").stdout.strip()
    return bool(hooks) and (Path(hooks) / "pre-commit").is_file() and HOOK_TAG in (Path(hooks) / "pre-commit").read_text()


def mode(target):
    """upgrade (kit installed), adopt (a spec system exists, no kit) or fresh. --fresh forces fresh unless upgrading."""
    specs = target / ".specs"
    if ours(specs / "kit"):
        return "upgrade"
    if "--fresh" in ARGS:
        return "fresh"
    return "adopt" if any((specs / d).exists() for d in ADOPT_DIRS) else "fresh"


ADOPT_DIRS = ("features", "domains", "system", "steering")


def install(kit_home, target):
    global ROOT
    ROOT = target
    specs = target / ".specs"
    kit = specs / "kit"
    if kit.exists() and not ours(kit):
        print(".specs/kit/ exists and isn't specter's: move it, then re-run")
        return 2
    how = mode(target)
    seed = specs / "steering/project-profile.md"
    adopted = how == "adopt" or (how == "upgrade" and seed.exists() and "\nadopted:" in seed.read_text())
    src_kit = kit_home / "kit"
    print(("Dry run: nothing will be written. Planned changes for " if dry() else "Installing specter into ") + str(specs))
    if dry() or how == "adopt":
        print("  mode: " + how + {"adopt": " (existing spec system found: your .specs/ content is kept as is)",
                                  "upgrade": " (kit installed: it is replaced, your specs and settings kept)",
                                  "fresh": " (forced by --fresh)" if "--fresh" in ARGS else " (no spec system yet)"}[how])
    old_version = (kit / "VERSION").read_text().strip() if how == "upgrade" else None
    for part in KIT_PARTS:
        src, dst = src_kit / part, kit / part
        def go(src=src, dst=dst):
            if dst.exists():
                shutil.rmtree(dst) if dst.is_dir() else dst.unlink()
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns("install.py", "__pycache__")) if src.is_dir() else shutil.copy(src, dst)
        write(dst, "replace" if dst.exists() else "create", go)
    version = (kit_home / "VERSION").read_text().strip()
    put_file(kit / "VERSION", version + "\n")
    say(".specs/kit/ " + version + ": rules, playbooks, templates, roles, scripts, docs")

    config_path = specs / "spec-kit.json"
    top = git(target, "rev-parse", "--show-toplevel").stdout.strip()
    is_repo = bool(top) and Path(top).resolve() == target
    repos = nested_repos(target)
    if not config_path.exists():
        config = json.loads((src_kit / "spec-kit.json").read_text())
        if repos or not is_repo:
            config["spec_sync"] = "off"
        config["code_globs"] = detect_code_globs(target) or config["code_globs"]
        config["kit_version"] = version
        put_file(config_path, json.dumps(config, indent=2) + "\n")
        say(".specs/spec-kit.json (code paths: " + ", ".join(config["code_globs"][:4])
            + ("…" if len(config["code_globs"]) > 4 else "") + "; setup confirms them)")
    elif how == "adopt":
        say(".specs/spec-kit.json exists: untouched (set tracker_pattern and merged_ref yourself, see README)")
    elif old_version and old_version != version:
        say("upgrade " + old_version + " -> " + version + " (your settings kept)")
    ensure_line(specs / ".gitignore", "report.html")
    profile = specs / "steering" / "project-profile.md"
    if not profile.exists():
        text = (src_kit / "templates/steering/project-profile.md").read_text()
        if how == "adopt":
            text = text.replace("status: setup-incomplete", "status: active\nadopted: " + datetime.date.today().isoformat()
                                + ", existing spec system kept; setup interview not run", 1)
        put_file(profile, text)
        say(".specs/steering/project-profile.md (status: " + ("active, adopted" if how == "adopt" else "setup-incomplete") + ")")
    rules = (src_kit / "AGENT_RULES.md").read_text()
    put_block(target / "AGENTS.md", rules)
    say("AGENTS.md: spec rules block (Codex, Cursor, Copilot, Gemini and others read this)")

    agents, source, on_machine = detect_agents(target, ARGS)
    if agents:
        say("agents (" + source + "): " + ", ".join(agents))
    else:
        say("agents: none in the project files; AGENTS.md alone works with most agents")
        if on_machine:
            say("  installed on this machine: " + ", ".join(on_machine) + ". To wire some: --agents=" + ",".join(on_machine))
    for name in agents:
        if install_skill(kit_home, target / AGENTS[name][3]):
            say("skill spec-first -> " + AGENTS[name][3] + "/spec-first/")
    if "claude" in agents:
        put_block(target / "CLAUDE.md", rules)
        say("CLAUDE.md: spec rules block")
        wrote = []
        for agent in sorted((kit_home / "kit/adapters/claude/agents").glob("*.md")):
            if (HOME / ".claude/agents" / agent.name).exists():
                say("user-level " + agent.stem + " agent found: kept yours, project copy skipped", True)
                continue
            dst = target / ".claude/agents" / agent.name
            if writable(dst):
                put_file(dst, agent.read_text())
                wrote.append(agent.stem)
        if wrote:
            say(".claude/agents: " + " / ".join(wrote) + " (sub-agents for .specs/kit/roles/)")
    if "cursor" in agents and (target / ".cursor").is_dir():
        header = (kit_home / "kit/adapters/cursor/spec-first.mdc").read_text()
        if writable(target / ".cursor/rules/spec-first.mdc"):
            put_file(target / ".cursor/rules/spec-first.mdc", header + rules)
            say(".cursor/rules/spec-first.mdc")
    if put_block(target / ".github/copilot-instructions.md", rules, create=False):
        say(".github/copilot-instructions.md: spec rules block")
    if put_block(target / "GEMINI.md", rules, create=False):
        say("GEMINI.md: spec rules block")

    if repos:
        say("multi-repo workspace (" + ", ".join(repos[:5]) + ("…" if len(repos) > 5 else "") + "): "
            "no git hook, since code commits happen in the child repos. Specs are kept in sync by the agent rules + review.")
    elif adopted and "--hook" not in ARGS and not hook_ours(target):
        say("no git hook: adopting never changes how commits behave. To enable the spec-sync check, re-run with --hook", True)
    elif is_repo:
        install_hook(kit_home, "mode from .specs/spec-kit.json")
    else:
        say("not a git repo: no hook. Run `git init` here if you want the specs versioned.")

    if dry():
        print("\nDry run done (mode: " + how + "). Nothing was written.")
    elif "--from-go" in ARGS and how == "adopt":
        print("\nDone. Setup interview skipped: your specs were kept. Next: read the README section on adding specter to a "
              "project that already has specs (tracker_pattern, merged_ref).")
    elif "--from-go" in ARGS:
        print("\nDone. Continue with .specs/kit/playbooks/setup.md (GO.md step 5).")
    elif how == "adopt":
        print("\nDone. Your specs were kept. Next: read the README section on adding specter to a project that already has specs (tracker_pattern, merged_ref).")
    else:
        print("\nDone. Next: open your agent in " + str(target) + " and say:\n"
              "  \"Set up the spec system: follow .specs/kit/playbooks/setup.md\"")
    return 0


def untouched_seed(target):
    """Config and profile exactly as the installer wrote them (never edited): safe to remove with the kit."""
    specs, gone = target / ".specs", []
    profile = specs / "steering/project-profile.md"
    config = specs / "spec-kit.json"
    tmpl = (Path(__file__).resolve().parent.parent / "templates/steering/project-profile.md")
    if not (profile.exists() and tmpl.exists()):
        return []
    seed = re.escape(tmpl.read_text()).replace(re.escape("status: setup-incomplete"),
                                               r"status: (?:setup-incomplete|active\nadopted: [^\n]*)", 1)
    if not re.fullmatch(seed, read_raw(profile)):
        return []  # set up since: the config holds confirmed settings too
    gone.append(profile)
    if config.exists():
        try:
            have = json.loads(config.read_text())
            default = json.loads((Path(__file__).resolve().parent.parent / "spec-kit.json").read_text())
        except (OSError, ValueError):
            return gone
        free = ("code_globs", "spec_sync", "kit_version")
        if isinstance(have, dict) and have.get("kit_version") and {k: v for k, v in have.items() if k not in free} == {k: v for k, v in default.items() if k not in free}:
            gone.append(config)
    return gone


def uninstall(target):
    global ROOT
    ROOT = target
    specs = target / ".specs"
    kept = []
    if (specs / "kit").exists():
        if ours(specs / "kit"):
            seeds = untouched_seed(target)
            shutil.rmtree(specs / "kit", ignore_errors=True)
            for f in seeds:
                f.unlink()
        else:
            kept.append(".specs/kit/ (not specter's)")
    drop_line(specs / ".gitignore", "report.html")
    for f in ("AGENTS.md", "CLAUDE.md", ".github/copilot-instructions.md", "GEMINI.md"):
        drop_block(target / f)
    rule = target / ".cursor/rules/spec-first.mdc"
    if rule.exists():
        rule.unlink() if ours(rule) else kept.append(shown(rule))
    for _, _, _, skill_dir, _ in AGENTS.values():
        skill = target / skill_dir / "spec-first" / "SKILL.md"
        if skill.exists():
            if ours(skill):
                skill.unlink()
                if not any(skill.parent.iterdir()):
                    skill.parent.rmdir()
            else:
                kept.append(shown(skill))
    for agent in (target / ".claude/agents").glob("*.md"):
        if ours(agent):
            agent.unlink()
    hooks = git(target, "rev-parse", "--path-format=absolute", "--git-path", "hooks").stdout.strip()
    hook = Path(hooks) / "pre-commit" if hooks else None
    if hook and hook.exists() and HOOK_TAG in hook.read_text():
        hook.unlink()
    print("Removed the kit, marker blocks, skill, role agents and hook. Your specs in .specs/ are kept.")
    for k in kept:
        print("  kept " + k)


ARGS = []


def main(argv):
    kit_home, args = Path(argv[0]), argv[1:]
    global ARGS
    ARGS = args
    if "--user" in args:
        agents, _, on_machine = detect_agents(Path.cwd(), args)
        agents = agents or on_machine
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
        agents, source, on_machine = detect_agents(target, args)
        print("agents: " + (",".join(agents) or "none") + "\nsource: " + source
              + ("\non this machine: " + ",".join(on_machine) if on_machine else ""))
        return 0
    if "--uninstall" in args:
        if "--dry-run" in args:
            print("--dry-run works with install only; uninstall was not run.")
            return 2
        uninstall(target)
        return 0
    return install(kit_home, target)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
