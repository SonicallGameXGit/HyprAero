# Aero Kit

The shared rulebook of the **Aero family**: a desktop shell and the apps that live next to it, all in the same Windows Aero style, built by the same rules. It is project-agnostic: nothing in this folder may name a specific project, language runtime of a specific app, or file path outside `.aero/`.

Kit version: **1** (bump it in `VERSION` below when a rule changes; projects compare it to know they are behind).

VERSION: 1

## What is in the kit

| File | What it holds | Changes when |
| --- | --- | --- |
| `PRINCIPLES.md` | Product philosophy, how to work, honesty and safety rules, documentation duty | The owner changes how things should be thought about |
| `CODE_STYLE.md` | Formatting and typing rules per language (TypeScript, JSON, QML, Rust, general) | The owner changes a style preference |
| `STYLE.md` | The visual style: Windows Aero, Frutiger Aero imagery, Slate dark theme, and the shared design tokens | The look of the family changes |
| `FAMILY.md` | How a project joins the family: what is shared, what stays local, how the pieces talk | The family structure changes |
| `templates/AGENTS.project.md` | Skeleton for a project's own `AGENTS.md` | The expected project sections change |
| `templates/CLAUDE.md` | The `CLAUDE.md` that imports everything | The list of kit files changes |

## Adding the kit to a project

1. Copy the whole `.aero/` folder to the project root.
2. Copy `templates/CLAUDE.md` to the project root as `CLAUDE.md`.
3. Copy `templates/AGENTS.project.md` to the project root as `AGENTS.md` and fill in the project parts.
4. Done. Nothing else is needed; the kit never needs editing inside a project.

## Changing the kit

- The kit is one thing with many copies. A rule change is made **once**, in the copy the owner is working in, then copied over the other projects' `.aero/` folders (overwrite the whole folder, do not merge by hand).
- Never add project-specific content to the kit. If a rule only makes sense for one project, it goes in that project's `AGENTS.md`.
- A project may be **stricter** than the kit in its own `AGENTS.md`, never looser. If it truly has to differ (for example a host that guarantees compositor blur), the exception is written in its `AGENTS.md` with the reason, and the kit's text allows it explicitly where that is expected.
- If a project's `AGENTS.md` and the kit disagree and nothing marks it as a deliberate exception, the kit wins and the project file is the one to fix.

## For agents

Read `PRINCIPLES.md`, `CODE_STYLE.md`, `STYLE.md` and `FAMILY.md` fully before changing anything, then the project's `AGENTS.md`. Claude Code gets them through `CLAUDE.md` imports; any other agent must open them explicitly.
