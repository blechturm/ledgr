# ledgr Design Philosophy

**Status:** Guiding document
**Purpose:** Define principles guiding design decisions
**Scope:** Non-enforceable; informs specifications and implementation

---

## 1. Purpose

ledgr is a system for:

```text
expressing, testing, and executing systematic trading ideas
under strict correctness constraints
```

The goal is not to find good strategies quickly.

> **The goal is to avoid believing bad strategies.**

---

## 2. Core Philosophy

### 2.1 Correctness Is A Hard Constraint

Correctness is not an optimization target.

```text
no lookahead
deterministic execution
explicit assumptions
reproducibility
auditability
```

If a feature compromises correctness, it is rejected.

---

### 2.2 Teachability Within Correctness

```text
Teachability is the primary usability goal
within the correctness constraint.
```

Users should be able to:

```text
read a strategy
understand what it does
explain why it does it
```

---

### 2.3 Strategies Express Financial Reasoning

The proposed v0.1.7.2 strategy-helper layer is intended to make common
strategy logic read like a sequence of financial decisions:

```r
ctx |>
  signal_return(20) |>
  select_top_n(10) |>
  weight_equal() |>
  target_rebalance(ctx, equity_fraction = 1)
```

This is a design target for the helper layer, not a statement that these
helpers are available in the currently installed package. Current v0.1.7
workflows remain ordinary `function(ctx, params)` strategies that return
explicit target quantities.

Avoid opaque packaged strategies that hide the reasoning:

```r
ledgr_strategy_momentum_v3(...)
```

---

### 2.4 No Fake Explainability

```text
No inferred intent
No misleading metadata
No hidden transformations
```

Only record what is explicitly known.

---

### 2.5 Composability Over Convenience

Prefer:

```text
small, composable primitives
```

Avoid:

```text
large opaque abstractions
```

---

### 2.6 Explicit Over Implicit

All important choices must be visible:

```text
normalization
selection rules
allocation logic
constraints
```

---

### 2.7 Strategies Remain Free-Form

Users can always write:

```r
function(ctx, params) {
  # arbitrary logic
}
```

Helper layers must reduce boilerplate without becoming mandatory or becoming a
second execution path.

---

### 2.8 Reproducibility Requires Isolation

A strategy must not depend on:

```text
implicit session state
undeclared helpers
mutable global objects
```

Free-form R remains allowed, but reproducibility is tiered. Logic that depends
on external or mutable state cannot receive the same reproducibility guarantees
as self-contained `function(ctx, params)` code with explicit parameters.

---

### 2.9 Design Principle

```text
A strategy that only works due to hidden state is not valid.
```

---

## 3. Usage Guidance

Consult this document when:

```text
evaluating new features
designing APIs
resolving trade-offs
```

This document is not enforceable.

Binding behavior is defined in `contracts.md` and in the active versioned spec
packet. This document is a guide for deciding what belongs in those contracts.

---

## 4. North Star

```text
Strategies should read like financial reasoning
and execute like deterministic systems.
```
