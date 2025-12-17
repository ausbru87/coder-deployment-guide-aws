# Repo Agent Instructions
## Coder on AWS Deployment Guide

You are assisting on a documentation repository that incrementally builds an opinionated 500 workspace PEAK **step-by-step production deployment guide for Coder on AWS**.

This repo is written **iteratively**. You must work in small, verifiable chunks so the human can test each step before proceeding.

---

## Non-negotiables (source of truth)
- Treat **coder/docs** as the canonical example for **structure, tone, headings, and language**.
- For **Coder behavior** (configuration, flags, deployment expectations), reference **Coder documentation**.
- For **AWS behavior** (IAM, VPC, ALB/NLB, EKS/EC2, RDS, Route 53, ACM, quotas, limits), reference **official AWS documentation**.
- Do **not** invent AWS console labels, defaults, limits, pricing, or CLI output.
- If something cannot be verified, **say so explicitly** and link to the relevant Coder or AWS docs.

> Note: `coder/docs` is a structural and stylistic reference. If its content conflicts with current docs, prefer the current Coder docs site.

---

## Scope & pacing (critical)
- Work **piece-by-piece only**.
- Default output is **one small deliverable**, not a full guide:
  - one documentation section (≈60–120 lines max), or
  - one logical step group (≈5–10 steps), or
  - one command/config snippet with verification.
- **Stop after each deliverable.** Do not continue into the next section unless explicitly told.
- If asked for “the guide”, “everything”, or “full docs”:
  - respond with a **chunked plan** only
  - wait for the human to choose the next chunk.

---

## Collaboration cadence
Before writing anything new, briefly state:
1. What you’re about to write (1–2 sentences)
2. Assumptions it depends on (region, architecture choice, DNS ownership, etc.)
3. What the human should **verify/test** after applying it

If assumptions are missing, choose the safest default and **label it clearly as an assumption**.

---

## Writing style (match coder/docs)
- Clear, imperative steps: *Create*, *Configure*, *Verify*.
- Short paragraphs; lists for procedures.
- Prefer copy-pasteable commands and config blocks.
- Explain **after** the snippet, not before.
- Use consistent structure where applicable:
  - Purpose
  - Prerequisites
  - Steps
  - Verify
  - Troubleshooting
  - Next steps
- Include “why this matters” notes **only** to prevent real failures (IAM, networking, TLS, persistence, upgrades).

---

## Production assumptions
Unless explicitly told otherwise, assume:
- TLS is required for external access
- A persistent PostgreSQL database is required
- Least-privilege IAM
- Clear upgrade and rollback expectations
- Cost awareness when enabling AWS resources

---

## Verification is mandatory
Every chunk must include a **Verification checklist**:
- Commands to run or UI state to confirm
- What success looks like
- Common failure signals (brief)

No verification = incomplete work.

---

## Output limits
- Keep responses under **~300–600 words** unless explicitly asked for more.
- Prefer the **next actionable step** over extra background.
- Do not repeat earlier sections unless they are being revised.

---

## Modes of operation

### Plan mode
When asked to plan:
- Propose a **coder/docs-style outline**
- Call out assumptions
- Identify which steps rely on Coder docs vs AWS docs
- Present alternatives briefly and state the recommended path

### Exec mode
When asked to write:
- Produce markdown that can be pasted directly into the repo
- Write only the requested chunk
- Add TODOs only when genuinely blocked by missing info

---

## Web usage
- Validate any AWS or Coder details that may change (versions, limits, supported services).
- Prefer primary sources:
  - https://docs.aws.amazon.com
  - Official Coder documentation


