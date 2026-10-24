# Principles

Apply to every project in the Aero family. When unsure about a design or feature argument, re-read sections 1 and 2.

## 1. Simple on the surface, deep underneath (the "Figma principle")

Figma is as approachable as Canva for someone who has never used a PC, and nearly as powerful as raw CSS. Rounding a square is one obvious gesture, yet nothing stops you from going much deeper. The opposite failures are:

- **Photoshop / Illustrator / GIMP**: powerful, but you need to be an expert to do a trivial thing.
- **Canva**: trivial things are easy, and then you hit a wall and resort to ugly workarounds.

Rules that follow:

- The common action is always one obvious step, with no configuration required first.
- Power is added by **progressive disclosure** (an "Advanced" section, a details panel, a context menu, a shortcut), never by making the simple path longer.
- Never remove or hide a capability just to keep a screen clean. Find a deeper place for it instead.
- If a user needs a workaround to do something reasonable, that is a bug in the design.

## 2. Predictable core, optional smartness (the "C principle")

The base behaviour is plain, explicit and predictable, like C. Smart features are **extensions offered to the user**, never behaviour silently injected into the core. The user always keeps full control and can always predict what happens in their workspace.

Rules that follow:

- Every smart feature has a complete manual equivalent that works without it, and the manual path is built **first**.
- Smart features suggest; the user confirms. Nothing "magic" happens without being visible and reversible.
- Smart features can be ignored or turned off entirely, and the program stays fully usable.
- A smart feature failing must never block the manual path. A failed detection leads into the manual way (pre-filled with whatever was found), never a dead end.

Do not invent large features on your own. Propose them.

## 3. Everything is configurable, nothing is required

- Behaviour that a reasonable person could want differently is a setting, with a sensible default, changed live where possible.
- Settings are grouped by what they are about, one category shown at a time; a new group of settings is a new entry in the list, not a longer page.
- **The user has full control, while the program stays friendly to someone who touches nothing.** Defaults are good; every default can be changed.
- **What is configurable and what is not:** *placement, size, count, order, behaviour and content* are the user's (where a bar sits, icon sizes, which items show, what happens on click, which modules run). The *family identity* is not: button style, rounding, gloss, glass and the other visual language of `STYLE.md` stay fixed so every Aero program looks like one. Choosing between the defined themes is allowed. If a user wants something the identity forbids, that is a deliberate "no", not a missing setting.
- A setting's text says what it does and what it costs (privacy, performance), in plain words.

## 4. Architecture rules shared by the whole family

- **Logic is separate from presentation.** What is not drawing lives in its own layer, testable without the UI. If logic can be written outside the presentation layer, it must be.
- **The presentation layer talks to the rest through one narrow door** (an API module / service layer). Components never reach around it.
- **I/O behind interfaces**, with real and fake implementations, so behaviour is testable without the real world (network, compositor, hardware, keychain).
- **One error type crosses boundaries**, carrying a kind and a technical detail. The UI words the message from the kind; the detail is the technical line.
- **Types cross a boundary once**: one source of truth, generated on the other side, never retyped by hand.
- **Platform and host differences are isolated** in one module per concern with a common interface. No platform checks scattered through feature code.
- **Reuse before writing.** Look for an existing helper, component or token before adding a new one. Small, composable modules over large ones.
- **Secrets never touch disk in plain text** and never appear in logs, config files, errors or crash reports.
- **No telemetry**, and no network calls beyond what the feature visibly needs, unless the owner asks for it and the user opts in.

## 5. Testing

Code is not done until it is tested. The goal is to verify behaviour in small parts **without launching the program and clicking buttons**.

- Unit tests next to the code for every parser, state machine and decision function.
- A bug fix comes with a test that fails before the fix.
- Never make a test pass by weakening or deleting it. If a test is wrong, say so and explain.
- Before declaring work finished, run the checks that apply (each project lists them in its `AGENTS.md`) and **report the real result**. Failing checks are reported as failing; skipped checks are reported as skipped.

## 6. How to work

- Understand before editing: read the relevant code and the rules. Do not guess at conventions.
- Keep changes small and focused. No drive-by refactors, no unrequested features.
- After every change, review exactly what changed and how behaviour was affected.
- **Ask the owner before**: adding a dependency of significant size, changing an architecture rule, changing anything in sections 1-2 or in `STYLE.md`, or doing anything hard to undo.
- Do not commit or push unless asked.
- Report honestly: what was done, what was verified and how, what was not.
- Comments explain *why*, not *what*. Match the surrounding code: naming, comment density, idiom.

## 7. Documentation duty

- Each project's `AGENTS.md` is its single source of truth for rules and decisions. Code and `AGENTS.md` must never disagree: if a decision turns out wrong, change the file in the same change that breaks the rule.
- Each project's `README.md` is the source of truth for **user-visible behaviour**: controls, setup, configuration. A change that adds, changes or removes a feature updates `README.md` in the same task.
- Decisions go to the project's decision log: one line, newest last, `date - decision - reason`. Write the reason; the decision alone is useless in a year.
- User-facing text goes through the project's translation function; no hard-coded UI strings in components.
