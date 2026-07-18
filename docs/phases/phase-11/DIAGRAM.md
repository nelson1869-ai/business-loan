# Phase Visual Flowchart

## Objectives
* Goal: Handle past due loans and record collection follow-ups.

## Flowchart
```mermaid
flowchart TD
    A[Start Collections] --> B[Implement overdue status flagger]
    B --> C[Define late fee penalty calculator]
    C --> D[Create collector actions logging form]
```

## Entry Requirements
* Dependencies: Phase 10
* Ensure previous phase objectives are completed and verified.

## Exit Requirements
* Status: **Planned**
* All deliverables are verified.

## Deliverables
* Files: lib/features/collections/*

## Related Documentation
* [Phase Overview](OVERVIEW.md)
* [Phase Checklist](CHECKLIST.md)
* [Phase Flow Progression](FLOW.md)
