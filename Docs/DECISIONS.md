# Decisions

## 2026-04-21 — Adopt TrackGrade Brief v1.0 as Project Specification

### Context

The repository needs a single durable source of truth for scope, architecture, phased delivery, and acceptance criteria before implementation begins.

### Decision

Adopt `Docs/BRIEF.md` (TrackGrade brief v1.0, dated 2026-04-21) as the project specification and phase gate reference.

### Consequences

- Implementation must follow the phased plan and hard acceptance criteria in the brief.
- Ambiguities and unresolved product choices must be tracked in `Docs/OPEN-QUESTIONS.md` instead of being silently assumed.
- Session continuity starts by rereading the brief and living documents from disk.
