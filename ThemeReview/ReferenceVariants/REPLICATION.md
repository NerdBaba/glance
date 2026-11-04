# New reference variants

The previous 22 bundled and saved snapshots are frozen; their SHA-256 hashes are recorded in original-hashes.json. New files use the suffix “Reference”. They remain drafts until reviewed.

| Style | Measured reference | Changes to component structure |
|---|---|---|
| Ember Capsules | 1366px; x18 launcher36px, separate spaces118px; y11 height34; center104px; right223px | Separate launcher and spaces, 10px filled dots with a 20px active pill, dotted terminal divider, joined right utility capsule |
| Rose Orbit | 1920px; y4 height26; clock65px, shared connection63px, center236px; right100px +340px | Shared connection and system capsules, ten 14px solid workspace dots, smaller outer gaps |
| Sakura Dock | 1366px; bottom38px; time68px/weather48px; center97px | Pale bottom bar, rounded user icon, 12h clock, four small filled dots plus 30px active pill, compact language/audio/network cluster |
| Cloud Ribbon | 1600px; x160 width1280 height50; six dots; center95px clock | Wide pale rounded bar, six colored dots, vertical menu separator, slanted volume segments, joined storage/CPU/RAM pill, compact network speed |
| River Tabs | 1366px; bottom28px; shortcuts63/70/55/55/70px; title region387px; date112px | Correct shortcut order, joined title/space region, quiet condensed system status, live Bluetooth status |
| Petal Toolbar | 1920px; top36px; circular editor; centered music capsule; pastel right controls | Play indicator after music label, extra privacy and shortcut icons, shared output/input audio capsule |
| Midnight Air | 1024px; bottom~24px; transparent; numerical center spaces | Regular weight quiet text, bare speaker icon, calendar clock, no capsule backgrounds |
| Crimson Rail | 1200x675; x12 width36; y12 height651; clock2 lines; ornamentcenter; empty lower rail | Minimal narrow inset rail, centered ornament and tiny markers, no grid launcher or large workspace row |

## Shared options

- Named contiguous capsule groups with editable background, radius, height, padding and spacing.
- Native workspace indicator shapes: label, filled dot, outlined ring, and elongated active pill. Actual macOS workspaces remain clickable; preview counts are fixture data only.
- New token aliases for compact disk and network values; existing tokens and defaults stay unchanged.
- Pywal roles remain live; manual sampled colors exist only in comparison copies.
- Existing requested constraints apply: text at least14pt, no battery, no wallpaper blur, bars only. These differences and native icon substitutions mean screenshots cannot be literally pixel identical to Linux desktop captures.
