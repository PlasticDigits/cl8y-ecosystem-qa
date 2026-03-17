# CL8Y Ecosystem QA — Architecture

## Overview

Centralized QA repository for all CL8Y ecosystem projects. Eliminates duplication of QA templates, scripts, and tooling across repos.

## Directory Structure

```
cl8y-ecosystem-qa/
├── README.md
├── ARCHITECTURE.md          ← this file
├── projects/
│   ├── cl8y-bridge-monorepo/
│   │   ├── templates/       ← QA test pass templates
│   │   ├── passes/          ← completed QA pass results
│   │   └── evidence/        ← screenshots, logs
│   ├── cl8y-dex-terraclassic/
│   │   ├── templates/
│   │   ├── passes/
│   │   └── evidence/
│   └── ustr-cmm/
│       ├── templates/
│       ├── passes/
│       └── evidence/
└── qatool/
    ├── Cargo.toml           ← Rust CLI tool
    └── src/
        ├── main.rs          ← CLI entry point + arg parsing
        ├── config.rs        ← Project detection + config loading
        ├── template.rs      ← Generate new QA pass from template
        ├── issue.rs         ← Create GitLab issues via glab
        ├── evidence.rs      ← Upload screenshots/evidence
        └── report.rs        ← Generate QA summary reports
```

## QA Tool — CLI Design

### Language Choice: Rust

Rationale:
- Type safety catches errors at compile time — important for a tool that manages QA data
- Token-efficient for LLM development (fewer tokens per feature vs TypeScript)
- Matches the indexer stack (team already familiar)
- Single binary — easy to install via `cargo install`
- Compiles to native — fast execution

### Core Commands

```bash
# Initialize — detect which project repo you're in
qatool init

# Generate a new QA test pass from template
qatool pass new
# → Creates timestamped pass file from project template
# → Opens in $EDITOR or outputs to stdout

# File a bug issue on GitLab
qatool bug "swap fails with zero amount"
qatool bug --evidence screenshot.png "swap fails with zero amount"
# → Creates GitLab issue via glab CLI
# → Uploads evidence if provided
# → Copies evidence to ecosystem-qa/projects/{name}/evidence/

# Upload completed QA pass
qatool pass upload passes/QA_PASS_2026-03-17.md
# → Posts as comment on GitLab QA tracking issue
# → Copies to ecosystem-qa/projects/{name}/passes/

# Generate summary report
qatool report
# → Reads all passes, counts PASS/FAIL/SKIP across sessions
# → Shows trend over time
```

### Project Detection

The tool detects which project it's running in by checking:
1. Git remote URL (`gitlab.com/PlasticDigits/cl8y-*`)
2. Presence of known files (e.g. `docker-compose.yml`, `packages/frontend`)
3. `.qatool.toml` config file (optional override)

### Config File (.qatool.toml)

```toml
[project]
name = "cl8y-dex-terraclassic"
gitlab_repo = "PlasticDigits/cl8y-dex-terraclassic"
qa_issue = 18  # tracking issue for QA passes

[ecosystem]
repo = "https://gitlab.com/PlasticDigits/cl8y-ecosystem-qa.git"
local_path = "~/cl8y-ecosystem-qa"

[templates]
pass = "templates/qa-test-pass.md"
bug = "templates/bug-report.md"
```

## Design Principles

1. **Modular** — each file under 600 LOC
2. **Simple** — wraps existing tools (glab, git) rather than reimplementing
3. **Convention over configuration** — works with zero config if in a known project
4. **Offline-first** — generates files locally, uploads on command
5. **Non-destructive** — never modifies project repo files without explicit command

## Migration Plan

### Phase 1: Structure (current)
- Set up directory structure
- Create architecture doc
- Copy existing templates from project repos

### Phase 2: CLI Skeleton
- Rust project setup with clap for arg parsing
- `qatool init` — project detection
- `qatool pass new` — template generation

### Phase 3: GitLab Integration
- `qatool bug` — issue creation via glab
- `qatool pass upload` — post to tracking issue
- Evidence management

### Phase 4: Reporting
- `qatool report` — cross-project QA summary
- Trend tracking over time
- Coverage metrics

## Current QA Script Duplication

These scripts exist in multiple repos and should be consolidated:

| Script | Bridge | DEX | Purpose |
|--------|--------|-----|---------|
| `scripts/qa/new-bug.sh` | ✅ | ✅ | File bug issue |
| `scripts/qa/new-test-pass.sh` | ✅ | ✅ | Create test pass |
| `scripts/qa/new-test-pass-cursors.sh` | ✅ | ❌ | Test pass with cursors |

The qatool replaces all of these with a single binary.
