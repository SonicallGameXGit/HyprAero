# Code style

The owner's style, the same in every project of the family. Where a linter or formatter can enforce a rule, the project configures it so the result does not depend on who (or what) wrote the code.

## 1. TypeScript / JavaScript / Svelte

- Strings use `'single quotes'`, even when the text contains `'` (escape it: `'don\'t'`).
- A string with a variable **inside** it uses a template literal: `` `Hello ${name}, welcome` ``. If the variable is only at the **start or end**, concatenate instead: `'Hello ' + name`, `count + ' unread'`.
- No semicolons. Only use `;` when several statements really have to share one line.
- Indent with 4 spaces.
- `PascalCase` for classes, enums and enum members; `camelCase` for variables and functions.
- Prefer procedural code: plain functions and data. Use a class or another paradigm when it genuinely fits the case better, then use it without hesitation.
- `const` everywhere it is possible. Exception: follow the framework's own rules where `let` vs `const` changes behaviour (for example Svelte's `<script>` blocks, reactivity and SSR).
- Arrays and objects that are too long for one line are split one element per line, indented one level, **with a trailing comma after the last element**. Never leave the last element without a comma in multi-line form.
- Every `if` has braces and a body on its own lines. Never brace-less, never inline:

```ts
if (condition) {
    ...
}
```

- **Zero type errors, and no lying to the compiler.** If a value is `unknown` or a union, narrow it with real checks (`typeof`, `in`, discriminants, guards) even when you "know" the runtime type. No `any`, no `as` casts to silence errors, no `@ts-ignore`, no `!` assertions.
- Check existence explicitly: `value === undefined`, `value === null`, `list.length === 0`. Not `!value`.

```ts
const describeUnread = (count: number, folder: string | undefined): string => {
    if (folder === undefined) {
        return count + ' unread'
    }

    return `${count} unread in ${folder} folder`
}

const defaultPorts = [
    993,
    465,
    587,
    995,
]
```

## 2. JSON

- Indent with 4 spaces.
- An array / object with 0-3 small elements is written inline; objects get a space after `{` and before `}`: `{ "host": "imap.example.com", "port": 993 }`, `[1, 2, 3]`.
- Anything bigger is split across lines, one level of indent per nesting.

## 3. QML (Quickshell and any other QML project)

**General rule for every language without its own section: the TypeScript rules of section 1 apply as far as the language and its syntax allow.** For QML that is confirmed by the owner (2026-10-10); the points below are what that means in practice. For a case not covered, follow the TypeScript rule closest in spirit.

- 4 spaces, no semicolons (except several statements on one line), `'single quotes'` for strings, template literals / concatenation as in section 1.
- `if` always with braces and a body on its own lines, also inside property bindings and handlers (use a block body, not a ternary chain, once it stops fitting on one line).
- Prefer `readonly property` and `const` inside JavaScript blocks; declare something mutable only when it truly changes.
- Explicit checks: `value === undefined`, `value === null`, not `!value`.
- Ids and properties are `camelCase`; component files and types are `PascalCase` (`GlassPanel.qml`).
- Order inside an object: `id`, then properties (public first), then signals, then functions, then child objects. Blank line between groups.
- Multi-line lists and objects: one element per line, trailing comma where the language allows it.
- All visual values come from the shared theme singleton (see `STYLE.md`); no hard-coded colour, radius, spacing, blur or duration in a feature component.
- Types for anything crossing out of QML into C++ / scripts are declared; do not rely on untyped `var` where a real type exists.

## 4. Rust

- `rustfmt` defaults (4 spaces), `clippy` clean with `-D warnings`.
- No `unwrap` / `expect` / `panic!` outside tests; return typed errors. The workspace lints deny them, and every crate opts in with `[lints] workspace = true`.
- Errors are typed per crate and carry enough context to show the user something useful.
- Same spirit as TypeScript: plain functions and data first, traits where they buy testability or real polymorphism.

## 5. Shell, CSS / SCSS, config files

- 4 spaces. Same trailing-comma / one-per-line rules for long lists where the format allows.
- CSS values that are visual decisions are tokens (`STYLE.md`), not literals.
- Config files read by the program are validated on load; a bad value falls back to its default and says so, it never crashes the program.

## 6. General

- Match the surrounding code: naming, comment density, idiom.
- Comments explain *why*, not *what*.
- Plain, explicit code beats clever code (`PRINCIPLES.md` section 2).
