# CL8Y Ecosystem QA

Centralized QA repository for all CL8Y ecosystem projects.

## Projects

| Project | Repo | Status |
|---------|------|--------|
| [CL8Y Bridge](projects/cl8y-bridge-monorepo/) | [GitLab](https://gitlab.com/PlasticDigits/cl8y-bridge-monorepo) | Active |
| [CL8Y DEX](projects/cl8y-dex-terraclassic/) | [GitLab](https://gitlab.com/PlasticDigits/cl8y-dex-terraclassic) | Active |
| [UST1CMM](projects/ustr-cmm/) | [GitLab](https://gitlab.com/PlasticDigits/ustr-cmm) | Maintenance |

## Structure

```
projects/{name}/templates/   — QA test pass templates
projects/{name}/passes/      — completed QA pass results
projects/{name}/evidence/    — screenshots, logs, evidence
qatool/                      — CLI tool (Rust)
```

## QA Tool

A Rust CLI tool that unifies QA workflows across all projects:

```bash
qatool pass new          # Generate QA pass from template
qatool bug "description" # File a bug issue
qatool pass upload file  # Upload completed pass
qatool report            # Generate summary
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for full design.

## Quick Start

```bash
# Clone
git clone https://gitlab.com/PlasticDigits/cl8y-ecosystem-qa.git

# Install qatool (once built)
cd qatool && cargo install --path .

# Use in any project repo
cd ~/cl8y-dex-terraclassic
qatool pass new
```
