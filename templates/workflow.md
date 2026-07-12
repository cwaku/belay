# Workflow config
# Copy to <project>/.claude/workflow.md and fill in. The task-router skill
# reads this; if it's missing, the router infers a tier, asks once, and
# writes this file for you.

# T1 = production (real money/users/credentials/irreversible data)
# T2 = personal product (kept/shipped, no external blast radius yet)
# T3 = throwaway / coursework
tier: T2

# Name this project's critical surfaces (what counts as L4 here).
# Examples: "auth endpoints, data deletion, payment webhooks"
l4-examples:

# Where handoff-checkpoint writes its resumable snapshot.
# Use .superpowers/sdd/progress.md if the project runs SDD.
checkpoint-file: PROGRESS.md

# Standing rules for this project (branching, commit style, merge flow).
notes:
