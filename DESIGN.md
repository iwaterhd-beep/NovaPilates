# Design System

<!-- impeccable:design-schema 1 -->

## World

Sewing-pattern envelope for NŌVA Pilates: cool tissue ground, drafting charcoal, deep violet commitment, dashed grain lines, sharp corners. Practice types are Views A/B/C; plans read as nested size choices.

## Palette

| Token | Hex | Role |
| --- | --- | --- |
| `--bg` | `#e4e7e2` | Cool tissue page ground |
| `--panel` | `#f1f3f0` | Elevated surface |
| `--card` | `#f7f8f6` | Content panels |
| `--ink` | `#1a1f1c` | Primary text / drafting charcoal |
| `--ink-soft` | `#4a524c` | Secondary text |
| `--line` / `--line-strong` | `#c5cbc4` / `#9aa39a` | Solid and dashed structure |
| `--accent` | `#5c3d8a` | Deep violet CTAs and active marks |
| `--accent-soft` | `#7355a3` | Hover / soft accent |
| `--dash` | `#8a938a` | Grain / meta marks |

Light theme locked from a daytime cutting-table scene. Contact band inverts to charcoal for a single deliberate close.

## Typography

- Display: Fraunces (headlines, wordmark, view letters)
- Body: Figtree (UI, paragraphs, nav)
- Tracking floor about `-0.03em` on large display sizes

## Components

- Buttons: sharp, uppercase, red primary / outlined secondary
- Views A/B/C: dashed envelopes, red letter marks, grain arrow
- Process rail: ordered steps with leading-zero counters
- Plans: dashed cards, red tags, solid red border on focus/hover
- Shop cards and modals inherit the same tokens
- Nav: fixed tissue bar with wordmark + isotipo

## Motion

- Hero video drift (disabled under reduced motion)
- Staggered hero rise-in
- Scroll reveals via `.reveal`
- Hover lift on views and plans

## Surfaces

Public marketing: `index.html` / `sections/home_zen.html`, `bonos`, `tienda` via `zen.css`.
