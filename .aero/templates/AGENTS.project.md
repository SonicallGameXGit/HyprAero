# AGENTS.md

Single source of truth for any AI agent (or human) working on this project. Read it fully before changing anything. If a decision here turns out to be wrong, change this file in the same change that breaks the rule; never let the code and this file disagree.

## 0. Shared rules (read first)

This project belongs to the Aero family. Before this file, read all of these, fully:

- `.aero/PRINCIPLES.md`: philosophy, architecture rules, testing, how to work, documentation duty
- `.aero/CODE_STYLE.md`: formatting and typing rules
- `.aero/STYLE.md`: visual style and shared tokens
- `.aero/FAMILY.md`: how members of the family relate

This file only adds to them or narrows them. A deliberate exception is marked **Exception** and says why. Where this file is silent, the kit applies.

Working name: **<Name>** (<placeholder or final>). Namespace: `app.hyprAero.<name>`.

## 1. What this is

<One paragraph: what it does, for whom. And what it is explicitly not.>

## 2. Place in the family

- Role: <base | addition>
- Works without: <what it never requires>
- Optional integrations: <which members it can talk to, through which documented interface>

## 3. Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| | | |

## 4. Architecture

### 4.1 Layout

```
<tree of the project, with one line per folder>
```

### 4.2 Rules

- <project-specific architecture rules; the shared ones are in `.aero/PRINCIPLES.md` section 4>

## 5. Project-specific rules

<security, host, platform, performance rules that only this project has>

## 6. Checks and running

Before declaring work finished, run what applies and report the real result:

```bash
<commands>
```

Run: `<one command>`. Build: `<one command>`. These are the only two ways; do not add variants.

## 7. Design

<Layout and UX of this project: what is placed where and why. The style (colours, gloss, radii) is in `.aero/STYLE.md` and is not repeated here.>

Tokens live in: `<path>`. Primitives live in: `<path>`.

## 8. Roadmap and current state

Works today:

- <...>

Not built yet, roughly in this order:

1. <...>

## 9. Decision log

Newest last. One line per decision: date, decision, reason.

- <date> - <decision> - <reason>
