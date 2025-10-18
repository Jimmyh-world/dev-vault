# dev-vault - HashiCorp Vault Infrastructure Documentation

<!--
TEMPLATE_VERSION: 1.5.0
TEMPLATE_SOURCE: /home/jimmyb/templates/AGENTS.md.template
LAST_SYNC: 2025-10-18
SYNC_CHECK: Run ~/templates/tools/check-version.sh to verify you have the latest template version
AUTO_SYNC: Run ~/templates/tools/sync-templates.sh to update (preserves your customizations)
CHANGELOG: See ~/templates/CHANGELOG.md for version history
-->

**STATUS: IN DEVELOPMENT** - Last Updated: 2025-10-18

## Repository Information
- **GitHub Repository**: https://github.com/Jimmyh-world/dev-vault
- **Local Directory**: `/home/jimmyb/dev-vault`
- **Primary Purpose**: Centralized secret management and API authentication system documentation for development laboratory infrastructure

## Important Context

<!-- PROJECT_SPECIFIC START: IMPORTANT_CONTEXT -->
This project contains research, architecture documentation, and implementation planning for HashiCorp Vault deployment in the dev lab. The project includes two comprehensive research documents (devlab-vault-architecture.md and vault-auth-guide.md) that were created externally and serve as introductory research material. The actual implementation will follow Jimmy's RED→GREEN→CHECKPOINT workflow, with execution specs delegated to Beast for heavy deployment work. This is part of the three-machine orchestrated architecture (Chromebook Orchestrator, Guardian Pi 5, Beast).
<!-- PROJECT_SPECIFIC END: IMPORTANT_CONTEXT -->

## Core Development Principles (MANDATORY)

### 1. KISS (Keep It Simple, Stupid)
- Avoid over-complication and over-engineering
- Choose simple solutions over complex ones
- Question every abstraction layer
- If a feature seems complex, ask: "Is there a simpler way?"

### 2. TDD (Test-Driven Development)
- Write tests first
- Run tests to ensure they fail (Red phase)
- Write minimal code to pass tests (Green phase)
- Refactor while keeping tests green
- Never commit code without tests

### 3. Separation of Concerns (SOC)
- Each module/component has a single, well-defined responsibility
- Clear boundaries between different parts of the system
- Services should be loosely coupled
- Avoid mixing business logic with UI or data access code

### 4. DRY (Don't Repeat Yourself)
- Eliminate code duplication
- Extract common functionality into reusable components
- Use configuration files for repeated settings
- Create shared libraries for common operations

### 5. Documentation Standards
- Always include the actual date when writing documentation
- Use objective, factual language only
- Avoid marketing terms like "production-ready", "world-class", "highly sophisticated", "cutting-edge", etc.
- State current development status clearly
- Document what IS, not what WILL BE

### 5.5. AI-Optimized Documentation
**CRITICAL**: Documentation is structured data for both humans AND AI consumption

**Purpose**: Enable AI assistants to effectively help during:
- **Development** (now) - Building the system
- **Deployment** (later) - Setting up and configuring
- **Operations** (ongoing) - Monitoring, troubleshooting
- **User Support** (ongoing) - Helping users use the system

**Key Principles**:
1. **Structured Data Over Prose** - Use tables, JSON, YAML instead of paragraphs
2. **Explicit Context** - Never assume prior knowledge
3. **Cause-Effect Relationships** - Clear "if X then Y" statements
4. **Machine-Readable Examples** - Complete, runnable code blocks
5. **Searchable Patterns** - Consistent headings, markers, formats
6. **Version-Stamped** - Date all documentation updates
7. **Cross-Referenced** - Explicit links between related docs

**Example** (Good AI-optimized documentation):
```markdown
## Database Configuration

**Required Environment Variables**:
| Variable | Format | Example | Required |
|----------|--------|---------|----------|
| DATABASE_URL | postgresql://... | postgresql://postgres:secret@localhost:5432/db | Yes |

**Validation**:
\```bash
npm run db:test-connection
# Expected output: "✅ Connected successfully"
\```
```

**Documentation Layers**:
- **Layer 1**: Development Phase (AGENTS.md, Architecture docs, Phase plans)
- **Layer 2**: Deployment Phase (DEPLOYMENT-GUIDE.md, OPERATIONS.md, API-REFERENCE.md)
- **Layer 3**: User Phase (USER-GUIDE.md, TROUBLESHOOTING.md, Configuration patterns)

All documentation follows these principles to maximize AI assistant effectiveness.

### 6. Jimmy's Workflow (Red/Green Checkpoints)
**MANDATORY for all implementation tasks**

Use the Red/Green/Blue checkpoint system to prevent AI hallucination and ensure robust implementation:

- 🔴 **RED (IMPLEMENT)**: Write code, build features, make changes
- 🟢 **GREEN (VALIDATE)**: Run explicit validation commands, prove it works
- 🔵 **CHECKPOINT**: Mark completion with machine-readable status, document rollback

**Critical Rules:**
- NEVER skip validation phases
- NEVER proceed to next checkpoint without GREEN passing
- ALWAYS document rollback procedures
- ALWAYS use explicit validation commands (not assumptions)

**Reference**: See **JIMMYS-WORKFLOW.md** for complete workflow system, templates, and patterns

**Usage**: When working with AI assistants, say: *"Let's use Jimmy's Workflow to execute this plan"*

**Benefits:**
- Prevents "AI says done ≠ Actually done" problem
- Forces validation at every step
- Enables autonomous execution with safety gates
- Provides clear rollback paths
- Integrates seamlessly with TDD approach

### 7. YAGNI (You Ain't Gonna Need It)
- Don't implement features until they're actually needed
- Resist the urge to "future-proof" or add "might be useful later" code
- Build for current requirements, not hypothetical future ones
- Question every feature: "Do we need this NOW?"
- Refactor when requirements change, don't pre-optimize
- Every line of code is a liability - only write what's necessary

**Why This Matters:**
- Prevents scope creep and over-engineering
- Reduces technical debt (unused code is still debt)
- Speeds up development (focus on actual requirements)
- Forces clear prioritization of features

**AI Assistant Reminder:** Don't add "helpful" features like caching, abstraction layers, or config systems unless explicitly required by current needs.

### 8. Fix Now, Not Later
- Fix vulnerabilities immediately when discovered (npm audit, security warnings)
- Fix warnings immediately (don't suppress or accumulate)
- Fix failing tests immediately (understand root cause, don't skip)
- Fix linter errors immediately (don't disable rules without reason)
- Address build errors and deprecation warnings as they appear
- Don't use suppressions (@ts-ignore, eslint-disable, etc.) without documented justification

**Exception Clause:**
- If you MUST defer or bypass an issue:
  1. Investigate the root cause thoroughly
  2. Weigh multiple solution options
  3. Make an explicit decision
  4. DOCUMENT why (in code comments, KNOWN_ISSUES.md, or technical debt tracker)
  5. Create a tracking issue/ticket

**Why This Matters:**
- Prevents technical debt accumulation
- Keeps codebase healthy and maintainable
- Vulnerabilities don't ship to production
- Warnings don't become noise
- Tests remain meaningful

**AI Assistant Reminder:** Never suggest "we'll fix this later" or "skip for now". Always investigate root cause and fix immediately. If deferring is necessary, document comprehensively.

## GitHub Workflow

### Use GitHub CLI (gh) for All GitHub Operations

**Standard Tool**: Use `gh` CLI for all GitHub interactions (issues, PRs, CI/CD monitoring, releases)

**Installation**: `gh` should already be installed. Verify with `gh --version`

**Common Operations:**

**Pull Requests:**
```bash
gh pr create --title "Feature" --body "Description"
gh pr list                          # View open PRs
gh pr checks                        # Check CI/CD status
gh pr view [number]                 # View PR details
gh pr merge [number]                # Merge PR
```

**CI/CD Monitoring:**
```bash
gh run list                         # List workflow runs
gh run view [id]                    # View run details
gh run watch                        # Watch current run (live updates)
gh workflow list                    # List workflows
```

**Issues:**
```bash
gh issue create --title "Bug" --body "Description"
gh issue list                       # View open issues
gh issue view [number]              # View issue details
gh issue close [number]             # Close issue
```

**Releases:**
```bash
gh release create v1.0.0            # Create release
gh release list                     # List releases
gh release view [tag]               # View release details
```

**Why GitHub CLI:**
- ✅ Scriptable and automation-friendly
- ✅ Consistent across all projects
- ✅ Works seamlessly with AI assistants
- ✅ Faster than web UI for most operations
- ✅ Built-in CI/CD monitoring
- ✅ Integrates with Jimmy's Workflow checkpoints

**AI Assistant Note**: Always use `gh` commands instead of suggesting "check the GitHub web UI" or manual git operations for GitHub-specific tasks.

## Service Overview

<!-- PROJECT_SPECIFIC START: SERVICE_OVERVIEW -->
This repository serves as the planning and documentation hub for HashiCorp Vault infrastructure deployment across the dev lab. It contains architecture research, implementation specs, and deployment planning for a centralized secret management system that will serve multiple projects including the Cardano trading bot, API key management for external users, and general secret storage across the three-machine infrastructure.

As the Orchestrator in the three-machine architecture, this Chromebook is responsible for strategic planning, architecture decisions, and creating detailed execution specs. Heavy deployment work will be delegated to Beast, while Guardian may host certain services once deployed.

**Key Responsibilities:**
- Architecture research and documentation for Vault deployment
- RED phase planning for implementation phases
- Creating execution specs for Beast to deploy Vault infrastructure
- GREEN phase review and validation of Beast's implementation
- Documentation maintenance and iteration based on deployment learnings

**Important Distinctions:**
- **Research Documents** (devlab-vault-architecture.md, vault-auth-guide.md): Introductory/reference material, not actual implementation
- **Execution Specs** (to be created): RED phase outputs following Jimmy's Workflow, ready for Beast execution
- **This is Planning**: Chromebook orchestrates, Beast executes heavy Docker/infrastructure work
<!-- PROJECT_SPECIFIC END: SERVICE_OVERVIEW -->

## Current Status

<!-- PROJECT_SPECIFIC START: CURRENT_STATUS -->
🔄 **Active Development** - 70% Complete

**Phase 1: Infrastructure Deployment** ✅ COMPLETE (2025-10-18)
- ✅ Architecture research documents collected
- ✅ Authentication strategy comparison completed
- ✅ Project initialization with AGENTS.md, CLAUDE.md, JIMMYS-WORKFLOW.md
- ✅ Phase 1 execution spec created (RED phase)
- ✅ Vault v1.15.6 deployed on Beast:8200 (Beast execution - 10 min)
- ✅ GREEN phase validation completed (all checks passed)
- ✅ CHECKPOINT approved (docs/checkpoints/PHASE-1-CHECKPOINT-APPROVAL.md)
- ✅ Orchestrator + Specialist pattern validated

**Phase 2: Secrets & Policies** ✅ COMPLETE (2025-10-18)
- ✅ Phase 2 execution spec created (RED phase)
- ✅ KV v2 secrets engine enabled at secret/ (Beast execution - 25 min)
- ✅ Three policies created and uploaded (admin, bot, external-readonly)
- ✅ Userpass authentication enabled (768h TTL)
- ✅ Test secrets stored in hierarchy
- ✅ **Policy enforcement validated (6/6 security tests passed)**
- ✅ Management scripts created (manage-policies.sh, create-token.sh)
- ✅ GREEN phase validation completed (all artifacts reviewed)
- ✅ CHECKPOINT approved (docs/checkpoints/PHASE-2-CHECKPOINT-APPROVAL.md)

**Phase 3: Production Readiness** ⚪ PENDING
- ⚪ Replace test secrets with real Cardano keys
- ⚪ Backup automation (daily snapshots)
- ⚪ Monitoring integration (Prometheus/Grafana)
- ⚪ Revoke root token (use admin user token)
- ⚪ External access configuration
- ⚪ Or: Advanced features (AppRole, dynamic secrets, PKI)
<!-- PROJECT_SPECIFIC END: CURRENT_STATUS -->

## Technology Stack

### Infrastructure & Documentation

**Core Infrastructure (Deployed by Beast):**
- **Secret Management**: HashiCorp Vault (containerized)
- **Storage Backend**: File-based (Phase 1), Raft/Consul (future HA)
- **Container Runtime**: Docker on Beast
- **Network**: Internal Docker network + Cloudflare WAF (external)
- **Backup**: Automated volume snapshots with GPG encryption

**Documentation:**
- **Format**: Markdown
- **Version Control**: Git + GitHub
- **AI Optimization**: AGENTS.md, structured data formats
- **Workflow**: JIMMYS-WORKFLOW.md (RED→GREEN→CHECKPOINT)

**Development Environment (Chromebook Orchestrator):**
- **OS**: ChromeOS with Linux container (Debian)
- **Tools**: git, gh (GitHub CLI), Claude Code
- **Coordination**: GitHub as single source of truth
- **SSH Access**: Guardian (192.168.68.10), Beast (192.168.68.100)

## Build & Test Commands

### Planning & Documentation
```bash
# Validate Markdown documentation
markdownlint *.md                    # If markdownlint installed

# Check for placeholder remnants
grep -r "\[" *.md | grep -v "http" | grep -v "example"

# Verify template version
~/templates/tools/check-version.sh  # Check if templates are up to date

# Update templates if needed
~/templates/tools/sync-templates.sh --dry-run  # Preview updates
```

### Coordination Workflow
```bash
# Create execution spec for Beast (RED phase)
# 1. Plan implementation in docs/specs/SPEC-NAME.md
# 2. Commit and push to GitHub
git add docs/specs/SPEC-NAME.md
git commit -m "spec: Add [description] for Beast execution"
git push origin main

# Review Beast's implementation (GREEN phase)
git pull origin main                # Pull Beast's changes
git log --oneline -5                # Review commits
git diff HEAD~1                     # Review changes

# Create GitHub issue for Beast task
gh issue create --title "Deploy Phase 1 Vault" --body "See docs/specs/..."

# Check issue status
gh issue list
```

### Deployment (Delegated to Beast)
```bash
# These commands run on Beast, not Chromebook
# Documented here for reference:

# SSH to Beast
ssh jamesb@192.168.68.100

# Execute deployment spec
# (Beast pulls spec from GitHub and executes)
```

## Repository Structure

```
dev-vault/
├── docs/
│   ├── specs/                          # Execution specs for Beast (RED phase outputs)
│   ├── architecture/                   # Architecture diagrams and decisions
│   └── checkpoints/                    # GREEN/CHECKPOINT validation records
├── devlab-vault-architecture.md        # Introductory research (external)
├── vault-auth-guide.md                 # Authentication strategy research (external)
├── AGENTS.md                           # AI assistant guidelines (this file)
├── CLAUDE.md                           # Quick reference for Claude
├── JIMMYS-WORKFLOW.md                  # RED→GREEN→CHECKPOINT workflow system
├── README.md                           # Project overview and getting started
└── .gitignore                          # Git ignore patterns
```

**Directory Purpose:**
- **docs/specs**: Detailed execution specifications created during RED phase for Beast to implement
- **docs/architecture**: Architecture decisions, diagrams, and reference documentation
- **docs/checkpoints**: GREEN phase validation records and CHECKPOINT decisions
- **Root level**: Research documents, workflow guides, and project metadata

## Development Workflow

### Starting Work on a Task
1. Read this AGENTS.md file for context
2. Check current implementation status above
3. Review known issues and TODOs below
4. **Use Jimmy's Workflow**: Plan → Implement → Validate → Checkpoint
5. Follow TDD approach - write tests first
6. Implement minimal code to pass tests
7. Refactor while maintaining green tests

### Before Committing Code
1. Validate documentation: `grep -r "\[" *.md | grep -v "http" | grep -v "example"`
2. Check for sensitive data: `git diff` (review changes)
3. Update AGENTS.md current status if needed
4. Ensure execution specs are complete and actionable
5. Verify no credentials or secrets are exposed
6. Use Jimmy's Workflow checkpoints to validate completeness
7. Create clear commit messages following conventions

### Documentation Updates
1. Update README.md with any API changes
2. Add inline comments for complex logic
3. Update this AGENTS.md if development approach changes
4. Document all decisions with dates
5. Keep development diary current (if applicable)

## Known Issues & Technical Debt

<!-- PROJECT_SPECIFIC START: KNOWN_ISSUES -->
### 🔴 Critical Issues
None currently - project is in planning phase.

### 🟡 Important Issues
1. Need to decide between Vault Auth vs Supabase Auth for web applications
2. GitHub repository not yet created (https://github.com/Jimmyh-world/dev-vault)
3. Directory structure (docs/specs, docs/architecture, docs/checkpoints) not yet created

### 📝 Technical Debt
1. Research documents need to be converted to actionable RED phase specs (estimated: 4-6 hours)
2. Need to create deployment checklist and validation criteria
<!-- PROJECT_SPECIFIC END: KNOWN_ISSUES -->

## Project-Specific Guidelines

<!-- PROJECT_SPECIFIC START: PROJECT_SPECIFIC_GUIDELINES -->
### Documentation Style
- All documentation in Markdown format
- Use structured data (tables, lists) over prose paragraphs
- Include actual dates for all planning and decisions
- No marketing language - factual and objective only
- AI-optimized: machine-readable examples and explicit cause-effect relationships

### Execution Spec Requirements (RED Phase Outputs)
- Complete and actionable - Beast should be able to execute without clarification
- Include explicit validation criteria for GREEN phase
- Document rollback procedures
- Include time estimates and complexity ratings
- Reference source research documents

### Security Considerations
- Never commit secrets, API keys, or credentials
- Research documents may contain architecture examples - always sanitize before real deployment
- Vault deployment specs must follow zero-trust security model
- All deployment validation must include security audit steps
<!-- PROJECT_SPECIFIC END: PROJECT_SPECIFIC_GUIDELINES -->

## Common Patterns & Examples

<!-- PROJECT_SPECIFIC START: COMMON_PATTERNS -->
### RED Phase Spec Creation Pattern
When creating execution specs for Beast:

```markdown
# SPEC: [Task Name]

**Created**: YYYY-MM-DD
**Status**: RED Phase
**Estimated Effort**: X hours
**Complexity**: Low/Medium/High

## Objective
[Clear, actionable objective]

## Prerequisites
- [ ] Requirement 1
- [ ] Requirement 2

## Implementation Steps
1. Step with explicit commands
2. Step with validation criteria
3. Step with rollback procedure

## GREEN Phase Validation
- [ ] Validation criterion 1
- [ ] Validation criterion 2

## Rollback Procedure
[Explicit rollback steps if implementation fails]

## References
- devlab-vault-architecture.md: Section X
- vault-auth-guide.md: Section Y
```

### Coordination Pattern with Beast
1. **RED**: Create spec in docs/specs/
2. **COMMIT**: Push spec to GitHub
3. **DELEGATE**: Create GitHub issue for Beast
4. **WAIT**: Beast pulls spec, executes, pushes results
5. **GREEN**: Pull Beast's changes, validate, audit
6. **CHECKPOINT**: Approve or request iteration
<!-- PROJECT_SPECIFIC END: COMMON_PATTERNS -->

## Dependencies & Integration

<!-- PROJECT_SPECIFIC START: DEPENDENCIES -->
### External Services
- **GitHub**: Version control and coordination hub (single source of truth)
- **Cloudflare**: WAF and CDN (for external Vault access, future)

### Related Services (Three-Machine Architecture)
- **Guardian Pi 5** (192.168.68.10): May host deployed Vault instance or related services
- **Beast** (192.168.68.100): Executes heavy deployment work, Docker infrastructure
- **Chromebook Orchestrator**: This machine - planning, specs, review, coordination
<!-- PROJECT_SPECIFIC END: DEPENDENCIES -->

## Environment Variables

<!-- PROJECT_SPECIFIC START: ENVIRONMENT_VARIABLES -->
```bash
# This project is documentation/planning only - no environment variables required
# Actual Vault deployment environment variables will be documented in execution specs

# Example for Beast deployment (documented in specs):
# VAULT_ADDR=http://vault:8200
# VAULT_TOKEN=s.xxx (generated during initialization)
# BACKUP_ENCRYPTION_KEY=path/to/gpg-key
```
<!-- PROJECT_SPECIFIC END: ENVIRONMENT_VARIABLES -->

## Troubleshooting

<!-- PROJECT_SPECIFIC START: TROUBLESHOOTING -->
### Common Issues

**Issue**: Execution spec seems too vague or incomplete
**Solution**: Reference the "RED Phase Spec Creation Pattern" above. Ensure all validation criteria, rollback procedures, and explicit commands are included.

**Issue**: Not sure if this should run on Chromebook or be delegated to Beast
**Solution**: Heavy/resource-intensive work (Docker, builds, long-running processes) → Beast. Strategic planning, code review, documentation → Chromebook.

**Issue**: Research documents are comprehensive but not actionable
**Solution**: Research documents are reference material only. Create execution specs following Jimmy's Workflow RED phase that translate research into concrete, implementable steps.
<!-- PROJECT_SPECIFIC END: TROUBLESHOOTING -->

## Resources & References

### Internal Documentation
- devlab-vault-architecture.md: Comprehensive Vault deployment architecture
- vault-auth-guide.md: Authentication strategy comparison (Vault vs Supabase)
- JIMMYS-WORKFLOW.md: RED→GREEN→CHECKPOINT workflow system
- ~/dev-workflow/: Three-machine workflow documentation
- ~/CLAUDE-CHROMEBOOK.md: Chromebook Orchestrator role and context

### External Resources
- HashiCorp Vault Documentation: https://www.vaultproject.io/docs
- Vault Docker Image: https://hub.docker.com/_/vault
- agents.md Standard: https://agents.md/
- Jimmy's Templates: ~/templates/

## Template Version Management

**Current Template Version**: See `<!-- TEMPLATE_VERSION -->` comment at top of this file

**This project uses versioned templates** from `/home/jimmyb/templates/`

### Check if Templates are Up to Date

```bash
~/templates/tools/check-version.sh
```

**What it does:**
- Compares your AGENTS.md version with master template version
- Exit code 0 = up to date ✅
- Exit code 1 = out of date ⚠️

### View Template Changelog

```bash
cat ~/templates/CHANGELOG.md
```

See what's new in each version and migration instructions.

### Sync to Latest Version (Manual for now)

```bash
~/templates/tools/sync-templates.sh --dry-run   # Preview changes
~/templates/tools/sync-templates.sh             # Apply changes (with confirmation)
~/templates/tools/sync-templates.sh --auto      # Auto-apply without confirmation
```

**What gets preserved during sync:**
- ✅ All `<!-- PROJECT_SPECIFIC -->` sections (your customizations)
- ✅ All placeholder values (PROJECT_NAME, commands, etc.)
- ✅ Custom additions to Known Issues, Technical Debt, etc.
- ✅ Project-specific guidelines and patterns

**What gets updated during sync:**
- 🔄 Core Development Principles (if new ones added)
- 🔄 Template structure improvements
- 🔄 Standard sections and formatting
- 🔄 Tool integrations (GitHub CLI, etc.)

**Important Notes:**
- Always review the diff before applying
- Backups are created automatically in `.template-sync-backup/`
- If sync fails, restore from backup
- Commit template updates separately from feature work

### Template Compliance Checking

**AI Assistant Behavior**: When user asks "check templates" or "are we up to date?", automatically:
1. Run: `~/templates/tools/audit-project.sh` OR manually execute checks
2. Generate compliance report
3. Offer remediation based on findings

**User can also run manually:**
```bash
~/templates/tools/audit-project.sh          # Full audit
~/templates/tools/audit-project.sh --quick  # Quick check
```

**Quick Manual Check:**
```bash
# Are we up to date?
~/templates/tools/check-version.sh

# What's new?
cat ~/templates/CHANGELOG.md
```

## Important Reminders for AI Assistants

1. **Always use Jimmy's Workflow** for implementation tasks
2. **Follow TDD** - Write tests before implementation
3. **Keep it KISS** - Simplicity over complexity
4. **Apply YAGNI** - Only implement what's needed now, not future "might need" features
5. **Use GitHub CLI** - Use `gh` for all GitHub operations (PRs, issues, CI/CD monitoring)
6. **Fix Now** - Never defer fixes for vulnerabilities, warnings, or test failures. No suppressions without documented justification
7. **Document dates** - Include actual dates in all documentation
8. **Validate explicitly** - Run commands, don't assume
9. **Never skip checkpoints** - Each phase must complete before proceeding
10. **Update this file** - Keep AGENTS.md current as project evolves

---

**This document follows the [agents.md](https://agents.md/) standard for AI coding assistants.**

**Template Version**: 1.0
**Last Updated**: 2025-10-18
