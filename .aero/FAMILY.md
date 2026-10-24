# The Aero family

A modular ecosystem. One project is the **base** (the desktop shell); every other app is an **addition** that can be installed without the others and still looks and behaves like the rest. Any app can be taken out and the others keep working.

## 1. What is shared, what stays local

| Shared (the kit, identical everywhere) | Local (each project's own) |
| --- | --- |
| Product principles (`PRINCIPLES.md`) | What the project is and does |
| Code style (`CODE_STYLE.md`) | Its tech stack and layout |
| Visual style and tokens (`STYLE.md`) | Its design: placement, flows, UX |
| Rules for joining the family (this file) | Its decision log, roadmap, checks to run |

If something is useful in two projects, it moves into the kit (rules) or into a shared design primitive (code). If it matters to one project only, it stays in that project.

## 2. Rules for every member

- **Independent.** A member never requires another member to be installed. Talking to the base shell (or another app) is optional and goes through a documented interface; without the other side the member still works, and the missing feature says so instead of failing.
- **Same look from the same tokens.** A member uses the tokens of `STYLE.md` under the same names and values. A visible difference from the family needs the owner's approval and a decision-log entry.
- **Same words for the same things.** The same action has the same name and the same icon in every member (Close, Settings, Search ...). Shared strings and icons are reused, not rewritten.
- **Same settings feel.** Settings windows share the layout: categories listed on the left, one shown at a time on the right, changes applied at once, "Restore the defaults" available.
- **Same safety.** Secrets, logs, telemetry and network rules of `PRINCIPLES.md` section 4 apply to every member without exception.
- **Native to the host.** A member follows the host's conventions where they exist (notifications, tray, file associations, keyboard focus, themes of the system) behind one interface per concern.
- **Own namespace.** Identifiers for config folders, data folders, IPC names, desktop entries, keychain services and compositor-facing names carry the member's name so members never collide. The *name* is the same everywhere; the *case* follows what the host expects for that kind of identifier (reverse-DNS `app.hyprAero.<member>` for app ids, D-Bus and keychain; lowercase kebab `hypraero-<member>-<part>` for compositor layer namespaces and config folders, as Hyprland configs conventionally use). Each project's `AGENTS.md` lists its identifiers.
- **Own `AGENTS.md`, never a fork of the kit.** See section 3.

## 3. A member's `AGENTS.md`

Start from `templates/AGENTS.project.md`. It has, in this order:

1. What this is (and what it is not)
2. Place in the family (base or addition, optional links to other members)
3. Tech stack, with the reason for each choice
4. Architecture: layout, dependency direction, project-specific rules
5. Project-specific rules (security, platform, host)
6. Checks to run before finishing, and the one way to run and to build
7. Design (layout and UX of this project; the style comes from the kit)
8. Roadmap and current state
9. Decision log

It must not repeat kit text. It refers to it ("see `.aero/STYLE.md`") and only adds, narrows, or explicitly marks an exception.

## 4. Talking between members

- Prefer the host's standard mechanisms (desktop entries, D-Bus, `.desktop` actions, URL schemes, files in a known folder) over a private protocol.
- Anything private between members is a **documented, versioned interface**, written in the `AGENTS.md` of the side that owns it, with a fake for tests.
- No member reads another member's data folder directly.

## 5. Starting a new member

1. Copy the kit and the two templates (`.aero/README.md`, "Adding the kit to a project").
2. Fill in `AGENTS.md`; ask the owner for anything the template marks as a decision.
3. Create the token file from `STYLE.md` section 4 first, then the primitives, then the features.
4. Write the first decision-log entries: stack, name, namespace.
