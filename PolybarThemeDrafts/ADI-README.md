# Adi Polybar themes in Glance

Source: https://github.com/adi1090x/polybar-themes
Upstream commit: `7735b96afd72f835c7c909599265fb431886d7c0`

63 distinct layout presets, containing 76 bar panels:

- Simple and bitmap versions of Blocks, Colorblocks, Cuts, Docky, Forest, Grayblocks, Hack, Material, Shades.
- All 12 Shapes styles in both Simple and Bitmap fonts.
- All eight Pwidgets layouts (including their stacked panels).
- All 13 OS/desktop panels, including the light/dark Elementary and KDE variants.

## Colors

50 non-OS presets enable Pywal. All label, icon, ramp, progress, and transition colors retain symbolic `pywal:N` references, so palette changes recolor the bar. Text contrast is adjusted where a new palette makes a segment unreadable; decorative transition glyphs retain their exact palette colors.

13 OS/desktop presets disable Pywal and retain upstream fixed palettes.

Color-only switcher variants collapse into their shared Pywal layout. Both fonts and all shape/layout variations remain separate presets.

## macOS integration

Linux workspace, X11, MPD, ALSA, backlight, filesystem, memory, CPU, network, keyboard, temperature, and date modules use macOS providers. Labels, fonts, per-component backgrounds, ramps, and progress bars come from upstream. Playback buttons control the current macOS media player. Volume and brightness respond to the mouse wheel. Power triggers use Glance's existing confirmed power menu. Linux package update actions open macOS Software Update; Linux package counts are not emulated. Linux commands and launch scripts are not executed.

Battery modules are omitted for this desktop. Wallpaper blur is disabled. No wallpaper changes are included.

## Editing

Primary bar modules appear in Settings → Widgets. Native modules expose Polybar formatting keys instead of shell polling controls. Additional bar panels are defined by `[additional-bars.NAME]` in the preset TOML and remain independently editable in the config file. Export an additional bar with `--export-bar-name NAME` alongside `--export-bar`.

The original text/icon fonts are bundled, including the older Nerd Font glyph set and CoreText-compatible outline conversions of Waffle and Terminus's original bitmap pixels. Font fallback follows the configured Polybar font list. Rendering on macOS uses CoreText, so font rasterization can differ from Linux.

## Review artifacts

`manifest.json` maps every preset to the upstream config and active bars. `render-report.json` records the per-panel image exports. The contact sheets group Simple, Bitmap, Shapes, Pwidgets, and OS layouts. These are stable preview data, not live system readings. Exact pixel parity across every upstream screenshot has not been certified.

## Readability update

Adi presets keep bar height and font sizes in native macOS points (`scale-content = false`). The reference width now scales horizontal placement and floating bar width only. The smallest fonts use 14 points, including Waffle icons; larger title and transition fonts retain their source sizes. Square module edges no longer clip glyph overhang. Inline underline/overline colors follow Polybar's separate enable flags, and eight-digit inline colors use ARGB.

`readability-render-report.json` contains 152 exports (all 76 panels at both 1600 and 1920 pixels). `readability-comparison.png` shows before/after samples at native 1600-pixel width. Saved Adi snapshots are updated only when unchanged from their bundled version; backups preserve the prior application, active config and Randomazzo store.

### Older Polybar presets

The same 14-point minimum applies to 21 older bundled templates and 24 existing saved Polybar snapshots. Font changes are applied to each saved file's existing configuration so custom colors, module choices and formatting remain intact. Workspace numbers and music icons respect the selected theme font. Native capsule layouts fit the center group between the edge groups; Tiny's capsule is widened to fit its original date, workspace and volume content at 14 points.

`font-minimum-audit.json` checks every font definition. `legacy-render-report.json` covers all 24 older saved presets at 1600 and 1920 pixels.
