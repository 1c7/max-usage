---
name: fix-codesign-error
description: Slash command that inspects a macOS signing or entitlement failure and explains the minimum fix path. Invoke explicitly with /fix-codesign-error — this skill never self-triggers.
disable-model-invocation: true
---

# Fix Codesign Error

Inspect a macOS signing or entitlement failure and explain the minimum fix path.

## Arguments

- `app`: path to `.app` bundle or binary (optional)
- `identity`: signing identity hint (optional)
- `mode`: `inspect` or `repair-plan` (optional, default: `inspect`)

## Workflow

1. Inspect the app bundle, executable, signing info, and entitlements.
2. Determine whether the problem is identity, provisioning, hardened runtime, sandboxing, or trust policy.
3. Summarize the exact failure class in plain language.
4. Provide the minimal repair sequence or validation command.

## Guardrails

- Never invent entitlements; read them from the binary or source files.
- Distinguish local development signing problems from distribution or notarization failures.
- Prefer verifiable commands like `codesign -d`, `spctl`, and `plutil` over guesswork.
