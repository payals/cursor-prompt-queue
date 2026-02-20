# Prompt Queue

## Config
pause_between_steps: false

<!-- ──────────────────────────────────────────────────────── -->

## Step 1: [Short descriptive title]

### Prompt
[Your instructions here. Be specific about what to create, where to save it, and any constraints.]

### Outputs
- [key]: path to the [thing mentioned in prompt]

---

## Step 2: [Short descriptive title]

### Prompt
[Reference earlier outputs with {{step_1.key}} placeholders.
The orchestrator resolves these before dispatching.]

### Outputs
(none)

---

## Step 3: [Short descriptive title]

### Prompt
[Continue building on previous steps. You can reference any prior step's outputs.]

Review what was done in {{step_1.key}} and continue from there.

### Outputs
- [key]: path to the [thing mentioned in prompt]

---

<!-- Add more steps as needed. Keep the format:
## Step N: Title
### Prompt
### Outputs
---
-->
