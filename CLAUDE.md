# CLAUDE.md

WaTEM/SEDEM: Water and Tillage Erosion Model / Sediment Delivery Model
Python migration project.
Author: Jörn Stöhler
Original: watem-sedem/watem-sedem (legacy codebase, multiple branches)

## [Aspirational] End state

A clean, modern Python reimplementation of WaTEM/SEDEM that:
- Is self-sufficient and replaces the legacy codebase
- Has a well-structured, installable Python package (`watem_sedem_py/src/watem_sedem/`)
- Has a comprehensive test suite (pytest)
- Has clean, modern documentation
- Is installable via `uv` / `pip`
- Passes CI

## Project context

WaTEM/SEDEM is a spatially distributed soil erosion and sediment delivery model used in land management and agricultural research. The model simulates water erosion, tillage erosion, and sediment transport across agricultural landscapes using raster-based geospatial data.

The current `main` branch is the Python migration effort. The goal is a clean, modern Python codebase — cherry-picking and modernizing code from legacy branches as needed, not a faithful 1:1 port of everything. The migration agent works under Jörn's supervision.

Key dependencies: numpy, pandas, rasterio (geospatial raster I/O), and GDAL (system-level, provided by the devcontainer).

## About This File

CLAUDE.md is the single conventions file read by every agent. It follows these structural rules:

- Organized by **topic** (kind of work). Each topic mentions its relevant review subagent(s).
- Sections should be **self-contained** — minimize cross-references between sections.
- **Redundancy is cheap** to read (extra tokens cost nothing) but every duplicate is a maintenance point when editing.
- Agents make **small edits to individual sections**, never full rewrites — structure accordingly.
- **Stable conventions** (unlikely to change) may be duplicated across topics for self-containedness.
- **Volatile conventions** (evolving) stay in one place to avoid stale duplicates.
- When editing a section, check for duplicates and cross-references that may need updating.
- Subagent definitions live in `.claude/agents/` and copy the relevant CLAUDE.md topic sections into their prompt, turning conventions into a checklist.

## Roles

The project team consists of Jörn and Claude Code. "Claude Code" refers to multiple agents running in parallel and sequential sessions, each in its own git worktree. This CLAUDE.md is read by every agent; each agent sees only its own session context.

**1. Time bottleneck**

- Jörn's time is scarce. Claude Code's time is practically unbounded.
- Plans minimize Jörn's workload, even at vastly higher total Claude Code work than a balanced plan would assign.
- We parallelize Claude Code via multiple sessions in parallel, via agent teams, and via subagents.
- Each agent and its spawned teams and subagents work in its own git worktree.
- Jörn coordinates between sessions and prioritizes which tasks to pass to new sessions.
- Agents orchestrate their own, simpler-to-handle teams and subagents.

**2. Correctness of scientific results**

We use several approaches together to ensure correctness:

- We write code and documentation in a clear, detailed, explicit, structured, verifiable way.
  - "clear" = easy to understand, not vague or ambiguous
  - "explicit" = relevant implications are already spelled out, not left to derive
  - "detailed" = all steps are included for verification or derived tasks
  - "structured" = knowledge organized into modular chunks
  - "verifiable" = the reader can check correctness by doing local validity checks for every step
- We refactor, simplify, and improve until verification becomes straightforward.
- We use pytest to validate numerical results and model behavior.

**3. Exhaustiveness of test suites**

- Jörn must decide which model behaviors and numerical properties the test suites need to cover.
- Claude Code CAN: brainstorm, implement, and debug tests.
- Claude Code CANNOT: provide the exhaustiveness signal (deciding whether the test suite covers enough to give high confidence in scientific correctness).

**4. Task scoping**

Claude Code's ability to spot implicit scope criteria:
- Claude Code is okay (specifically: not bad, not good) at spotting implicit criteria imposed on a task's scope and acceptance criteria.
- These implicit criteria come from three sources: other tasks, Claude Code's own capability limits, and Claude Code's default habits.
- Claude Code can design and write down acceptance criteria for tasks that are similar to standard software development tasks.

Why Jörn must be involved:
- Claude Code lacks training on workflows that need a deep, accurate model of the whole remaining project.
- In particular: tasks that affect many other tasks, or that affect tasks that run only much later in the project.
- Claude Code also lacks training on multi-agent workflows that build upon a task.
- Consequence: Claude Code frequently makes bad scoping decisions for long-term work.

What Jörn requires before a Claude-scoped task can be merged:
- Jörn must greenlight the scope as matching his long-term vision. Normally this happens during the scope phase (see Session workflow). If that was skipped or the scope drifted during implementation, Jörn must greenlight before the merge instead — this is the safety net, not the normal path.
- Jörn requires an analysis of (a) the task's effect on downstream aspects and (b) side effects on how agents and Jörn work on the project.
- Jörn requires an analysis of how an agent would complete the task, to catch gaps in acceptance criteria caused by pathological agent behavior.
- For tasks not yet started: Claude Code should do a throwaway preliminary investigation to gauge how an agent would approach the task.
- For already-completed tasks: show Jörn the final executed plan.

**5. Code Review and Merge into `main`**

- Claude Code reviews branches using the Review workflow (see Subagents & Meta-rules)
- Review output: thorough findings + calibrated recommendation
- Jörn reads review and makes merge decision (often deviates ~50% from recommendation based on project context)
- Jörn performs the actual merge

**6. Writing code, tests, docs**

- Claude Code is perfectly capable of writing sufficiently good code, tests, and documentation.
- No need to bother Jörn for usual writing tasks.
- When consulting Jörn: describe clearly what narrowly scoped cognitive task Jörn should do, why Jörn should do it, and what context it exists within.

**7. Troubleshooting and investigating root causes**

- Claude Code is perfectly capable of doing investigations, especially with a subagent that extracts a concise findings report.
- Before pinging Jörn, Claude Code should do an investigation first.
- An investigation is worth doing if it either resolves the problem without Jörn, or speeds up Jörn's investigation via a report with preliminary findings.

**8. Attempting autonomous but difficult tasks**

- Claude Code's work time is cheap.
- We can spawn multiple agents for the same task and pick the best deliverable.
- Key design principle: there must be a plan ahead-of-time for how to revert an agent's work.
- This is why we use git and git worktrees, why only Jörn merges into `main`, and why we scope large tasks carefully ahead-of-time.

## Session Workflow

Every Claude Code agent session owns a git worktree. Subagents and teams work in the same worktree. Each session has a communication channel with Jörn.

Sessions follow this pattern: **scope → plan → implement → review → Jörn: merge**

**Scope phase** (Jörn + Claude Code together):
- Claude Code and Jörn agree on what single chunk of work the session will focus on.
- They work out a task scope that fits into the rest of the project.
- They decide on extra strategies, such as forking the session and letting multiple agents work through plan → implement → review independently, for a best-of-N tactic.
- Handoff from scope to plan phase happens explicitly.

**Plan → implement → review** (Claude Code autonomous):
- These three phases are carried out autonomously, usually with no involvement or monitoring from Jörn.
- Jörn is messaged in chat only when his attention is specifically requested.
- Jörn does not monitor agent actions or intermediate status updates. Therefore, the end-of-turn message must recap the context, so Jörn can jump back in without needing to read the full history.
- Claude Code decides autonomously when to transition between stages.
- Claude Code MAY return to earlier stages — e.g. planning a new approach after a dead end, or fixing bugs found during review.

**Merge phase** (Jörn + Claude Code together):
- When Claude Code is satisfied with its deliverable OR wants to give up, it messages Jörn.
- The message must include: what happened this session, what unknown unknowns were discovered, how known unknowns were resolved, and a checklist of the final review.
- Jörn may then: merge the branch, re-scope and ask for another cycle, or abandon the branch.

**Interaction rules during scope and merge discussions:**
- Claude Code SHOULD push back on contradictions, gaps, unclear statements, and oversights from Jörn.
- Claude Code MUST NEVER take silence as confirmation.

**Post-session reflection** (just before session ends via merge or abandon):

1. A report with all sources of friction, false steps, steps that turned out to have lower-than-expected value, unexpectedly good steps, and time sinks.
2. A breakdown of where Jörn spent time this session and what work Jörn did.
3. A list of suggestions, each labeled as confident or unconfident, and as actionably concrete or unactionably abstract.

### Decision authority

The deciding factors are rollback cost and verification cost:

**Act freely** — cheap to verify, easy to roll back:
- Writing and editing code (git handles rollback; tests verify)
- Investigation, research, trying things out and throwing them away
- Committing and pushing to the working branch

**Act, then Jörn verifies** — cheap to verify, moderate risk:
- Attempts where agent self-verification is reliable and Jörn's check is fast

**Discuss with Jörn first** — expensive to verify or hard to roll back:
- Scope changes — agents don't reliably notice when they've drifted or when a scope change has bad downstream consequences

**Never without explicit instruction:**
- Destructive operations with no rollback
- Creating PRs or merging to `main` (Jörn does this)

**When in doubt**, default to discuss-first.

## Communication

When requesting Jörn's attention: describe the narrowly scoped cognitive task, why Jörn should do it, and what context it exists within.

Formatting for efficient exchange:
- Aim for efficient information exchange, not politeness or engagement
- Number items so Jörn can respond "3 yes, 5 no" instead of quoting paragraphs
- Omit filler phrases
- When presenting decisions with tradeoffs: use tables, quantify costs/benefits, state recommendation upfront
- When you make repo changes Jörn should know about, mention and explain them

## Subagents & Meta-rules

Spawn a subagent when a subtask can run in parallel, needs isolated context, or benefits from focused work.

- Create a temporary file, e.g. in /tmp/ with the subagent prompt. Persistent record, easier to restart if agent fails.
- Subagent output returns via the Task tool into your conversation. If it needs to persist, commit it to the repo on your branch.
- Use Sonnet for read-heavy extraction tasks (code review). Reserve Opus for tasks requiring deep reasoning (code writing, architectural decisions).
- Keep subagent tasks focused and small.
- **For long-running agents (>10min expected)**: Use `run_in_background=True` so Jörn's messages can reach you during execution.

### Meta-rules

**The core rule:** Never write a factual claim without verifying it against evidence in the same session. "The function does X" requires reading the code and confirming it. "The tests cover Y" requires reading the tests. When verification is impossible, mark with `# TODO: JÖRN -` or `# GAP -`. Violating this rule is the single most damaging failure mode.

**Why rules get ignored:**
1. Too many rules active at once — only rules that stand out get applied
2. Contradictions between rules — agents fall back to default behavior
3. Rules conflict with agent defaults — defaults win silently
4. Rules not actionable — too abstract to apply during execution

**Mitigation: subagent-based rule enforcement.** Use subagents that focus on one cluster of conventions at a time.

- **Pre-delivery verification:** Before presenting a deliverable to Jörn, spawn a Sonnet subagent with (a) the relevant CLAUDE.md convention sections and (b) the deliverable. The subagent checks every factual claim against evidence and every applicable convention. Fix all issues before presenting to Jörn.
- **Plan subagent conventions:** Inject Roles §1 and §4, Session workflow, and Decision authority into Plan subagent prompts.
- **Meta-rule auditing:** After editing CLAUDE.md, spawn a subagent to check for internal contradictions, non-actionable rules, and stale references.

**MEMORY.md scope:** Session learnings and postmortems only. Stable project conventions belong in CLAUDE.md. If a MEMORY.md entry has been confirmed across multiple sessions, migrate it to CLAUDE.md and delete the MEMORY.md entry.

### Plan workflow

Conventions for planning together with Jörn (subagent overrides default `/plan`):

Save Jörn's time:
- Obtain findings upfront
- Present findings in a skimmable progressive-disclosure format
- Pre-empt follow-up investigations
- Provide session context after pauses in the discussion
- Check scope against Roles §1 and §4 before finalizing

Track where task scope comes from:
- The root terminal goal is a working, clean Python reimplementation of watem-sedem
- Convergent instrumental goals like rule adherence, best practices, and minimizing Jörn's time are omnipresent
- Keeping track of why some plan element was picked over what alternatives is necessary to later adapt the plan

### Review workflow

Orchestrates review subagents based on changed files:
1. Pick relevant subagents, e.g. based on `git diff main...HEAD --name-only`
2. Run them in parallel
3. Merge findings into one report
4. Address findings and carry out follow up investigations
5. Present to Jörn

## Git

**Always use local `main`, never `origin/main`.**

Jörn merges locally and pushes later, so `origin/main` is frequently stale. Comparing against `origin/main` inflates diffs with already-merged commits.

**For code reviews:** Use three-dot diff (`git diff main...HEAD`) to show only what the branch changed.

**State the base explicitly:** "Compared against local `main` at `abc1234`."

If unexpected files appear in diff, investigate — likely means branch needs rebasing.

## Python Package

**Invariant:** `pytest` passes from the repo root with zero failures.

### Package structure

```
watem_sedem_py/              Python migration (new code goes here)
  src/watem_sedem/           Python package
  tests/                     pytest test suite

# Existing Pascal (untouched — will shrink as code is ported and deleted)
common/                      Pascal model logic (~6350 lines)
watem_sedem/                 Pascal CLI entry point
tests/                       Pascal unit tests
testfiles/                   Integration tests (Pascal binary vs reference data)
```

### Coding conventions

- Use `pathlib.Path` for all file paths, never string concatenation
- Type hints on all public functions
- Docstrings on all public functions and classes (Google style)
- `ruff` for linting and formatting
- No hardcoded paths — accept paths as arguments or derive from `Path(__file__)`

### Testing

Two classes of tests:

1. **Correctness tests**: Does the model produce the correct output for known inputs? Use reference datasets where available.
2. **Regression tests**: Does a change break existing behavior? Use fixtures.

### Script/tool headers

Every standalone script must document in the module docstring:
- **Goal**: What does this do?
- **Input**: What data does it read?
- **Output**: What files does it write?

### Commit checklist

Before final report:
- [ ] All tests pass (`pytest`)
- [ ] Zero ruff warnings (`ruff check .`)
- [ ] Working tree clean (no uncommitted changes)

## Environment

- Sessions run in a devcontainer with the repo at `/workspaces/watem-sedem`.
  - Worktrees: use `--worktree` flag or `EnterWorktree` tool. Hooks in `.claude/hooks/` override defaults to branch from local `main`. Worktrees land at `.claude/worktrees/<name>/`.
- Pre-installed: Python 3.x (uv for package management), FPC/Lazarus (Pascal compiler), gh CLI, GDAL system libs
- Python packages managed via uv

**Runtime limits:**
- Repeated standard commands (tests, lints) **must complete in ≤10 minutes**
- This prevents triggering the CPU monitor, which kills sessions after 20min of sustained high CPU

## Quick Commands

```bash
# Python
uv run pytest                      # runs tests from watem_sedem_py/tests/ only
uv run ruff check .
uv run ruff format .

# Pascal
make                               # compile binary + unit tests
testfiles/test.sh                  # run integration tests

# Long-running commands: always wrap with timeout to prevent zombie processes
timeout 10m uv run pytest

# Git
git diff main...HEAD --name-only   # files changed on this branch
git diff main...HEAD               # full diff vs local main
```
