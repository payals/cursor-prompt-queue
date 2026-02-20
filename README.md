# cursor-prompt-queue

Batch sequential prompts in Cursor with dynamic variable passing between steps. Each step runs in a fresh subagent context -- no context rot, no manual handoff.

- [The Problem](#the-problem)
- [How It Works](#how-it-works)
- [Installation](#installation)
  - [Quick install](#quick-install)
  - [Manual install](#manual-install)
  - [Custom folder](#custom-folder)
- [Usage](#usage)
  - [Write your prompts](#1-write-your-prompts)
  - [Execute](#2-execute)
  - [Resume](#3-resume-if-session-dies)
  - [Reset](#4-reset-for-a-new-queue-run)
- [Queue File Format](#queue-file-format)
  - [Placeholder syntax](#placeholder-syntax)
  - [Declaring outputs](#declaring-outputs)
  - [Output reporting](#output-reporting)
- [Advanced Example](#advanced-example)
- [Config Options](#config-options)
- [Requirements](#requirements)

## The Problem

When working with AI agents in Cursor on multi-step tasks, you hit three friction points:

1. **Waiting between prompts** -- you have to watch the agent finish step 1 before you can send step 2
2. **Context rot** -- keeping everything in one session degrades quality as the conversation grows
3. **Manual handoff** -- opening a fresh session means copy-pasting context or referencing tracker docs by hand

And the killer: **dynamic references between steps**. If step 1 creates a plan file, step 2 needs to reference it by its actual path -- which you don't know ahead of time.

## How It Works

You write your prompts in a single queue file with `{{step_N.key}}` placeholders for values that will be determined at runtime:

```markdown
# Prompt Queue

## Config
pause_between_steps: false

## Step 1: Create migration plan
### Prompt
Create an implementation plan for the database migration. Save to docs/plans/.
### Outputs
- plan_file: path to the plan file created

---

## Step 2: Execute the plan
### Prompt
Execute the plan at {{step_1.plan_file}}.
### Outputs
(none)
```

When you say **"execute prompt queue"**, the agent:

1. Reads the queue file and state file
2. Validates the queue structure (catches errors before running anything)
3. Dispatches a **fresh subagent** for each step (clean context, no rot)
4. Captures declared outputs (`OUTPUT plan_file = docs/plans/2026-02-19-migration.md`)
5. Resolves `{{step_1.plan_file}}` in subsequent steps before dispatching
6. Writes progress to a state file -- **resumable across sessions**

If a session dies, open a new one and say **"resume prompt queue"**. It picks up exactly where it left off.

## Installation

### Quick install

Clone this repo, then run the install script from your project directory:

```bash
cd /path/to/your-project
bash /path/to/cursor-prompt-queue/install.sh
```

### Manual install

Copy 4 files into your project. Run these from your project root, replacing `REPO` with the path to your cloned cursor-prompt-queue repo:

```bash
REPO=/path/to/cursor-prompt-queue

# Skill (teaches the agent the orchestration protocol)
mkdir -p .cursor/skills/workflow-automation/prompt-queue
cp "$REPO/skill/prompt-queue/SKILL.md" .cursor/skills/workflow-automation/prompt-queue/

# Rule (triggers the skill on "execute prompt queue")
mkdir -p .cursor/rules
cp "$REPO/rules/prompt-queue.mdc" .cursor/rules/

# Templates (your queue file + initial state)
mkdir -p docs
cp "$REPO/templates/prompt_queue.md" docs/prompt_queue.md
cp "$REPO/templates/prompt_queue_state.md" docs/prompt_queue_state.md
```

### Custom folder

Queue files default to `docs/`. To use a different folder, pass it as an argument:

```bash
bash /path/to/cursor-prompt-queue/install.sh prompts
```

This copies templates into `prompts/` and automatically updates the paths in the installed skill and rule files. If you installed manually, update the paths in these two files yourself:

- `.cursor/skills/workflow-automation/prompt-queue/SKILL.md` — the Files table and step 1 of the orchestration process
- `.cursor/rules/prompt-queue.mdc` — the Critical Files table

## Usage

### 1. Write your prompts

Edit `docs/prompt_queue.md` with your steps. See the example in [How It Works](#how-it-works) above, or start from the template the installer copies for you.

### 2. Execute

Open a **fresh Cursor session** and say:

> execute prompt queue

or:

> run the queue

Starting from a clean session avoids context confusion and gives the orchestrator full use of the context window for each step. With `pause_between_steps: true`, the agent stops after each step so you can review before continuing.

You can add new steps to `docs/prompt_queue.md` while the queue is running. The orchestrator re-reads the queue file after each step, so new steps are picked up automatically on the next iteration.

### 3. Resume (if session dies)

Open a new Cursor session and say:

> resume prompt queue

The state file tracks which steps completed and what outputs were produced. The new session picks up from the next pending step.

### 4. Reset (for a new queue run)

Say:

> reset prompt queue

This resets both files to their initial state — the state file is cleared and the queue file is restored to the starter template, ready for new prompts.

You can also reset manually by editing `docs/prompt_queue_state.md`:

```markdown
# Prompt Queue State

## Current Step: 0
## Status: not_started

## Completed Steps

(none yet)
```

Or delete both files — the agent will recreate them on the next run.

## Queue File Format

| Element | Purpose |
|---------|---------|
| `## Config` | Settings like `pause_between_steps: true/false` |
| `## Step N: Title` | Step header with sequential number |
| `### Prompt` | Your instructions (supports `{{step_N.key}}` placeholders) |
| `### Outputs` | Key names the agent must report, or `(none)` |
| `---` | Step separator |

### Placeholder syntax

Reference any earlier step's output with `{{step_N.key}}`:

- `{{step_1.plan_file}}` -- resolves to whatever path step 1 reported
- `{{step_2.decision}}` -- resolves to a decision value from step 2

If a placeholder can't be resolved, the agent stops and asks you.

### Declaring outputs

Each output is a key-value pair in the `### Outputs` section:

```
- key: description of what the subagent should report
```

- **key** — the variable name. You'll reference it in later steps as `{{step_N.key}}`. Use `snake_case` (e.g. `plan_file`, `api_spec`, `test_results`).
- **description** — a hint that tells the subagent what to put in this variable. It should match how you refer to the thing in your prompt.

If your prompt says "create a migration plan and save it to docs/plans/", write:

```
- plan_file: path to the migration plan
```

Another example — a step that produces a decision instead of a file:

```
### Prompt
Evaluate approaches A and B for the caching layer. Pick the better one.

### Outputs
- chosen_approach: which approach was selected (A or B)
- rationale: one-line explanation of why
```

Use `(none)` if the step doesn't produce values needed by later steps.

### Output reporting

Subagents report outputs on separate lines:

```
OUTPUT plan_file = docs/plans/2026-02-19-migration.md
OUTPUT decision = approach_b
```

These values are stored in the state file and available to all later steps. File paths should be relative to the project root (e.g. `docs/plans/migration.md`, not absolute paths).

## Advanced Example

A three-step queue with multiple outputs per step and cross-step references:

```markdown
# Prompt Queue

## Config
pause_between_steps: false

## Step 1: Research and plan
### Prompt
Research the current authentication setup and create two documents:
1. An audit of the existing auth code at docs/auth_audit.md
2. A migration plan to switch to JWT at docs/auth_plan.md

### Outputs
- audit_file: path to the auth audit
- plan_file: path to the migration plan

---

## Step 2: Implement the migration
### Prompt
Follow the migration plan at {{step_1.plan_file}}.
Refer to {{step_1.audit_file}} for context on what exists today.
Create the new auth module and a rollback script.

### Outputs
- auth_module: path to the new auth module
- rollback_script: path to the rollback script

---

## Step 3: Test and document
### Prompt
Write tests for the auth module at {{step_2.auth_module}}.
Verify the rollback script at {{step_2.rollback_script}} works.
Update the original audit at {{step_1.audit_file}} with a "Migration Complete" section.

### Outputs
(none)
```

Key things this demonstrates:

- **Multiple outputs per step** — step 1 produces two files, step 2 produces two files
- **Cross-step references** — step 2 uses both of step 1's outputs, step 3 uses outputs from both step 1 and step 2
- **Outputs aren't limited to file paths** — see [Declaring outputs](#declaring-outputs) for examples with decisions and other values

Outputs can also capture decisions, names, or any value — not just file paths:

```markdown
## Step 1: Evaluate options
### Prompt
Compare Redis vs Memcached for our caching layer. Recommend one.
### Outputs
- cache_choice: which technology was recommended
- reasoning: one-line justification

---

## Step 2: Implement caching
### Prompt
Add a {{step_1.cache_choice}} caching layer. Rationale: {{step_1.reasoning}}
### Outputs
(none)
```

## Config Options

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `pause_between_steps` | `true` / `false` | `false` | Stop after each step for review |

## Repo Structure

```
cursor-prompt-queue/
├── README.md                         ← You are here
├── LICENSE
├── install.sh                        ← Run from your project to install
├── skill/
│   └── prompt-queue/
│       └── SKILL.md                  ← Copy to .cursor/skills/workflow-automation/prompt-queue/
├── rules/
│   └── prompt-queue.mdc             ← Copy to .cursor/rules/
└── templates/
    ├── prompt_queue.md              ← Copy to docs/ (edit with your prompts)
    └── prompt_queue_state.md        ← Copy to docs/ (auto-managed by agent)
```

## Requirements

- **Cursor IDE** with agent mode (uses the Task tool for subagent dispatch)
- **bash** (for `install.sh` — preinstalled on macOS and Linux)
- No external dependencies, no API keys

## License

MIT
