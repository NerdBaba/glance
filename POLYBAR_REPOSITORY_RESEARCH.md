# Polybar repository survey and Glance compatibility audit

Survey date: 2026-10-01. This review looked at the adi1090x gallery first, then compared independent themes, dotfiles, script modules, and upstream Polybar documentation/config examples. It covered 21 repositories, with README/gallery material and configuration or module source inspected where available.

## Repository sample

| Repository | What the source demonstrates |
| --- | --- |
| [adi1090x/polybar-themes](https://github.com/adi1090x/polybar-themes) | The main reference collection: simple and bitmap themes, Blocks/Shapes/Panels/Pwidgets variants, dynamic Pywal/random color scripts, Rofi integrations, and multiple text/icon fonts. Its README calls out 12 theme families and several shape/palette variations. |
| [kiddae/polybar-themes](https://github.com/kiddae/polybar-themes) | Separate top/bottom/side bars, tiny and floating layouts, three-bar blocks, bitmap fonts, Xresources colors, workspace and player control modules. |
| [Murzchnvok/polybar-collection](https://github.com/Murzchnvok/polybar-collection) | Theme and palette includes, environment-selected files, left/center/right composition, transparent bar backgrounds, named spacer and separator modules. |
| [Yucklys/polybar-nord-theme](https://github.com/Yucklys/polybar-nord-theme) | Light/dark top and bottom bars; state-dependent media layouts; clickable and scrollable workspaces, volume/backlight and utility modules. |
| [raven2cz/polybar-config](https://github.com/raven2cz/polybar-config) | Shared and user module files, MPRIS scrolling/control scripts, IPC hooks, custom tail scripts, ramps, progress bars, and animated battery/network indicators. |
| [berthosefin/polybar-themes](https://github.com/berthosefin/polybar-themes) | Distinct Blocks, Bordered, Docky, Forest, Grayblocks, and Windows silhouettes; Xresources palette and runtime style switcher. |
| [prcxzm/polybar-themes](https://github.com/prcxzm/polybar-themes) | Eight named theme families with shared module files, palette variants, Nerd/Material fonts, and compositor-driven shadow/transparency. |
| [SeanoNET/dotfiles](https://github.com/SeanoNET/dotfiles/tree/main/polybar/.config/polybar) | Workspace/window modules, system meters, custom scripts, Spotify controls, IPC, and per-state battery indicators. |
| [D-Freitas/polybar-dsh-theme](https://github.com/D-Freitas/polybar-dsh-theme) | Three aligned bar groups with workspace, CPU/memory/disk meters, date, internet, volume, and user display. |
| [catppuccin/polybar](https://github.com/catppuccin/polybar) | Palette-only theme files imported by a separate config; confirms the common separation between palette and layout/module config. |
| [Chris-1101/dotfiles](https://github.com/Chris-1101/dotfiles/blob/2021-blade/polybar.conf) | Multiple bars, state-specific formats, ramps, animations, IPC hooks, scripted weather, and a clickable power menu. |
| [Crowerade/transparentpolybar](https://github.com/Crowerade/transparentpolybar) | Transparent bar styling, clickable workspace controls, scroll-to-switch behavior, launchers, and menus. |
| [Wabri/polybar-minimal-nord-theme](https://github.com/Wabri/polybar-minimal-nord-theme) | Minimal Nord styling, Iosevka Nerd Font, and primary plus secondary bars. |
| [adrian26o/dotfiles](https://github.com/adrian26o/dotfiles/tree/master/polybar) | Python helpers for workspaces, weather, volume, and player controls; host-tool dependencies sit alongside presentation config. |
| [lualducor/polybar-cyberpunk-hud](https://github.com/lualducor/polybar-cyberpunk-hud) | Top/bottom and secondary-monitor bars, custom media/weather/network scripts, progress and ETA, plus multi-button actions. |
| [gh0stzk/dotfiles](https://github.com/gh0stzk/dotfiles/tree/master/config/bspwm/rices) | A theme selector spanning many full desktop themes, with Polybar colors/modules coupled to each desktop setup. |
| [polybar/polybar-scripts](https://github.com/polybar/polybar-scripts) | Community modules for weather, MPRIS, Bluetooth, updates, notifications, mail, timers, and hardware-specific status. |
| [0jdxt/polybar-mpris](https://github.com/0jdxt/polybar-mpris) | A live tail script for scrolling MPRIS metadata paired with a separate IPC play/pause module and clickable previous/next controls. |
| [arcolinux/arcolinux-polybar](https://github.com/arcolinux/arcolinux-polybar) | A distribution-level Polybar config tree and scripts maintained as part of a broader desktop setup. |
| [Wallkerock/X-setup](https://github.com/Wallkerock/X-setup) | Screenshot-backed dark orange, solarized, and canvas variants across bspwm and i3; a visual gallery rather than only a palette file. |
| [polybar/polybar](https://github.com/polybar/polybar) | Upstream module/runtime inventory and docs: tray, window titles, MPD, volume, workspaces, system status, script polling/tailing, menus, IPC, and more. |

The recurring design patterns are clear: a bar is an ordered left/center/right composition; modules can have individually shaded backgrounds; named palettes and fonts are often external files; module states change both content and formatting; and visual elements can also be actions. The adi1090x screenshot itself shows separately shaded controls/status segments, which a single shared bar background cannot reproduce.

## Upstream option semantics checked

Polybar’s [configuration reference](https://github.com/polybar/polybar/wiki/Configuration) defines INI sections, custom value references, inheritance, file/directory includes, bar geometry, fixed/relative centering, opacity, borders, line treatments, per-bar font lists, module ordering, and root fallback formatting.

The [formatting reference](https://github.com/polybar/polybar/wiki/Formatting) defines state-selected formats, labels, prefixes/suffixes, per-format and per-label styling, token width/truncation, ramps, weighted ramp ranges, progress bar fill/indicator/empty parts, gradients, animations, and inline lemonbar tags/actions. The [fonts reference](https://github.com/polybar/polybar/wiki/Fonts) specifies an ordered fallback font list and 1-based font selectors. The [script module reference](https://github.com/polybar/polybar/wiki/Module%3Ascript), [menu reference](https://github.com/polybar/polybar/wiki/Module%3Amenu), and [IPC reference](https://github.com/polybar/polybar/wiki/Module%3Aipc) cover polling/tailing scripts, menus, and state hooks.

## Glance implementation audit

| Capability | Current Glance behavior in this branch | Remaining mismatch |
| --- | --- | --- |
| Separate module colors | Built-in and script widgets can have their own segment foreground/background, opacity, padding, radius, border, and Glance-only `format-min-width`. Script markup can also style spans. | Polybar has more granular style at format, label, ramp level, and state scopes; built-in Glance widgets do not interpret arbitrary Polybar format strings. The three-group offset layout still compresses the media block in the screenshot comparison. |
| Three aligned groups | Glance has left/center/right widget groups and group/capsule width and offset settings used by the theme drafts. | It still renders one macOS menu-bar window. It cannot create arbitrary independent Polybar windows, monitor-bound bars, tray placement, or fully match all fixed-center collision rules. |
| Fonts and glyphs | The script renderer reads indexed font settings and inline font tags; native widgets use Glance’s configured bar/widget fonts. | Fontconfig fallback stacks, exact Linux bitmap fonts, per-run font metrics/vertical offsets, and unavailable font assets are not fully portable. |
| `custom/script` | Supports shell command polling or `tail`, `exec-if`, environment values, failure labels, output/value tokens, click/scroll/double-click options, and inline actions. | Arbitrary scripts retain their Linux command/dependency requirements; `custom/ipc` is not a drop-in service protocol for all Polybar setups. |
| Ramps/progress/animations | Script formatting supports weighted endpoint ramps, custom bar format/fill/indicator/empty/gradient stops, and indexed animation labels at their configured framerate. | These primitives apply to `script.*`; they do not automatically replace every built-in module’s state machine or Polybar’s exact metrics/font measurement. |
| Polybar configuration loading | Glance loads TOML. The widget options intentionally keep familiar Polybar names. | There is no general INI importer, include/inheritance/reference resolver, Xresources/file-variable expansion, or unsupported-option report yet. |
| Ecosystem modules | Glance has native macOS widgets for media, workspaces, volume, system/network/time, and other hardware/software state. | Linux/X11 integrations (bspwm/i3/EWMH, tray, ALSA/PulseAudio, Linux backlight, Rofi, and Linux-specific commands) require native adapters and cannot be made equivalent by copying appearance options. |

The code and configuration audit therefore supports substantial Polybar-style rendering, but it does **not** establish drop-in compatibility with arbitrary `.ini` files. Exact execution depends on the original operating system, window manager, services, fonts, and external programs; exact appearance also depends on matching geometry and glyph assets. The next meaningful engineering step for generic imports is an INI importer that preserves the original options and reports unsupported sections/options instead of silently approximating them.

## Screenshot comparison status

The Glance preview exporter builds and writes a PNG, and the temporary TOML parses in strict mode. Pixel bounds from the user-provided 794×48 reference and the 800×22 Glance export do **not** meet the requested visual parity yet:

| Segment | Reference exact-color bounds | Current Glance exact-color bounds |
| --- | --- | --- |
| Player controls `#976b6b` | x=450–493, y=14–30 (44×17 px) | x=457–468, y=5–17 (12×13 px) |
| Volume `#8e7c72` | x=672–707, y=14–30 (36×17 px) | x=607–663, y=5–17 (57×13 px) |

The colors are represented, but the offset three-group layout squeezes the player segment and over-expands volume. An isolated controls render gets a wider segment, so the remaining defect is in the full three-group layout. This is still a draft screenshot and is not ready for Randomazzo review or saving.

## Renderer corrections made from the source audit

- Two-entry ramps keep both entries as the low/high endpoint states instead of switching at 50%; weighted interior thresholds use the configured weights.
- Progress bars honor `bar-NAME-format` and treat configured width as the number of fill/empty units, with a separate indicator unit.
- Progress gradients use their numeric stop indices, not just the order in which colors happen to appear.
- Indexed `animation-NAME-N` components advance according to `animation-NAME-framerate`.
- Font tags use Polybar’s 1-based selector over Glance’s zero-based `font-N` entries; shorthand `#RGB` colors are recognized.

The Debug app build and PNG export succeeded, and `git diff --check` passed. The full-bar screenshot comparison above failed the visual-parity check. No new Randomazzo entries were saved as part of this survey; review remains the gate for changing those presets.
