# dev-vault

**Status**: IN DEVELOPMENT - 15% Complete
**Last Updated**: 2025-10-18

## Overview

Planning and documentation repository for HashiCorp Vault infrastructure deployment across the dev lab. This repository serves as the orchestration hub for centralized secret management implementation following the three-machine architecture pattern (Chromebook Orchestrator, Guardian Pi 5, Beast).

## Purpose

- Architecture research and documentation for Vault deployment
- Execution spec creation (RED phase) for Beast to execute
- Implementation validation and audit (GREEN phase)
- Deployment checkpoint and iteration planning (CHECKPOINT phase)

## Repository Structure

```
dev-vault/
├── docs/
│   ├── specs/          # Execution specs for Beast (RED phase outputs)
│   ├── architecture/   # Architecture diagrams and decisions
│   └── checkpoints/    # GREEN/CHECKPOINT validation records
├── devlab-vault-architecture.md  # Introductory research
├── vault-auth-guide.md            # Authentication strategy research
├── AGENTS.md           # AI assistant guidelines
├── CLAUDE.md           # Quick reference for Claude
├── JIMMYS-WORKFLOW.md  # RED→GREEN→CHECKPOINT workflow
└── README.md           # This file
```

## Current Status

**Research & Planning:**
- ✅ Architecture research documents collected
- ✅ Authentication strategy comparison completed
- ✅ Project initialization with AGENTS.md, CLAUDE.md, JIMMYS-WORKFLOW.md
- 🔄 Converting research to actionable execution specs
- ⚪ Phase 1 implementation spec (RED phase)
- ⚪ Vault deployment (Beast execution)
- ⚪ GREEN phase validation and audit
- ⚪ CHECKPOINT and iteration planning

## Getting Started

This is a documentation/planning project for Chromebook Orchestrator. Heavy deployment work will be delegated to Beast.

### For AI Assistants

Start by reading **AGENTS.md** for complete project context and guidelines.

### Workflow

1. **RED Phase**: Create detailed execution specs in `docs/specs/`
2. **Commit & Push**: Push specs to GitHub
3. **Delegate**: Create GitHub issue for Beast to execute
4. **GREEN Phase**: Pull Beast's implementation, validate, audit
5. **CHECKPOINT**: Approve or request iteration

## Three-Machine Architecture

- **Chromebook Orchestrator** (this machine): Strategic planning, specs, review
- **Guardian Pi 5** (192.168.68.10): May host deployed services
- **Beast** (192.168.68.100): Executes heavy Docker deployments

## Resources

- devlab-vault-architecture.md: Comprehensive deployment architecture
- vault-auth-guide.md: Authentication strategy comparison
- JIMMYS-WORKFLOW.md: RED→GREEN→CHECKPOINT system
- ~/CLAUDE-CHROMEBOOK.md: Orchestrator role documentation

## License

Internal development laboratory project.

---

**Coordination Hub**: GitHub (single source of truth)
**Workflow**: Jimmy's Workflow (RED→GREEN→CHECKPOINT)
