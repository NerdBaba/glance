# Polybar gallery → Glance draft map

This maps the 18 themes in [kiddae/polybar-themes](https://github.com/kiddae/polybar-themes) to Glance settings. Their TOML snapshots are bundled in [PolybarThemeDrafts](PolybarThemeDrafts), then imported into Randomazzo as Polybar — <theme> entries the first time the updated app launches. Existing entries and same-named files are left intact. The snapshots are available to apply or roll from Randomazzo; importing them does not change the active config. Colors stay Pywal-driven.

All 18 presets omit the Battery widget and set Blur Wallpaper off.

## Glance controls mapped

| Glance setting | What it changes | Polybar use |
| --- | --- | --- |
| Formation: Full | One edge-to-edge background | Flat full-width strips |
| Formation: Floating | One inset capsule/bar | Compact floating bars |
| Formation: Islands | Individual widget capsules | Loose modular clusters |
| Formation: Pills | Shared backgrounds for groups split by Spacer widgets | Three aligned left/center/right blocks |
| Position, Top Margin, Height | Screen edge, offset, and thickness | Top/bottom anchoring and thin/thick variants |
| Horizontal Margin, Padding, Widget Spacing, Group Gap | Outer inset, internal edge inset, within-group rhythm, and between-group rhythm | Compactness and block separation |
| Floating Width, Horizontal Alignment | Fixed-width floating capsule and its screen-edge alignment; width 0 fills available space | Tiny right-anchored pill |
| Left, Center, Right Capsule Width | Minimum width and item alignment for the three spacer-separated Pills groups; width 0 fits content | Wide independent blocks in `blocks`, `cherryblocks`, and `miniblocks` |
| Left Capsule Offset | Places the first pill independently of the screen edge in a two-pill layout | The two right-side groups in `material_thick` |
| Center Capsule Offset | Moves the middle Pills capsule away from the exact screen center | The deliberately off-center MPD window in `material` |
| Show Widget Backgrounds, Blur Wallpaper | Widget capsule fill and backdrop material | Transparent, solid, and blurred treatments |
| Roundness, Border Width/Opacity, Fill Opacity | Capsule corner shape and outline/fill strength | Square, rounded, bitmap block, or translucent treatments |
| Foreground, Accent, Widget Background, Border 1/2, Glow colors | Static colors when Pywal is off | Theme palette. Drafts leave Pywal enabled |
| Pywal indices | Picks dynamic foreground/accent/border/background colors | Keeps the geometry while adapting colors to the wallpaper |
| Per-widget foreground colors | Assigns a Pywal palette index per displayed widget | Multi-color blocks and status sections |
| Font chooser, Size, Weight | One font shared by bar and widgets | Drafts use installed Menlo and Helvetica Neue as close stand-ins for the Linux fonts |
| Spaces: display mode, highlight, numerals, icon style/tint, key, focused-window title/length | Workspace glyphs and title content; includes focused-number and Roman numerals | `bspwm`/`i3` workspace and window-title modules |
| Time: format and event format | Date/time text and calendar event time | Polybar `date`/`time` modules |
| Widgets: ordering and display options | Which status items appear and their order | Previous/play/next controls, track title, volume, network, CPU/memory, battery, launcher, and power |
| Randomazzo: Add Current Config, Apply, Rename, Delete, Roll, hotkey, exclude-current | Saves or restores complete TOML snapshots | Saves and applies each theme snapshot |

## Theme-by-theme draft

| Gallery theme | Glance draft structure | Main modules to map | Fidelity notes |
| --- | --- | --- | --- |
| `arch-blur` | Full-width, bottom anchored, translucent | Launcher, workspaces, media controls/track, time; battery, system, network, volume, power | Bottom row and narrow monospaced type match the source config |
| `blocks` | Pills, top, three fixed-width capsules | Focused workspace number, active window title; controls/track; volume/time/power | Widths and the right-shifted music pill follow the README screenshot |
| `cherryblocks` | Pills, bottom, three wider capsules | Workspace numbers and active title; controls/track; volume/time/power | Bottom placement, group positions, and thick rounded blocks follow the source screenshot |
| `classic` | Full-width, top, thin; left/center/right sections | Workspace dots; centered date; media controls/track and volume | Matches the narrow strip and centered clock |
| `classic2` | Full-width, top, low bitmap-like strip; date centered | Workspaces; date; track, CPU/memory, network, volume | Mirrors the source module list; font is a Mac fallback |
| `classic2-rounded` | 98%-width, top, rounded strip | Workspaces; centered date; track and system status | Source width and rounded treatment are reflected |
| `float` | 80%-width floating bar, top inset | Launcher/workspaces; controls/track; battery, system/time/volume/power | Width, margins, and module groups follow its source screenshot |
| `float2` | Nearly full-width floating bar, top inset | Launcher/workspaces/window title; track and controls; volume/time/power | Matches the source's 40px strip and 20px screen inset |
| `material` | Three Pills groups with shifted middle group, bottom | Launcher/workspaces; track and controls; volume/date/power | Approximates the source's separated bottom windows while placing MPD off-center |
| `material_bitmap` | Full-width, top, bitmap-sized type | Workspaces/layout; track; volume/battery/network/time | Uses Glance's input-language widget for the layout label |
| `material_one` | Full-width, top, thin | Launcher/workspaces/window title; track; volume/time/power | Player control buttons omitted to match the `playerctl` source module |
| `material_onethick` | Inset full-width, top, medium height | Launcher/workspaces/window title; track and controls; volume/time/power | Source `mpd` plus `mpd-controls` are represented separately |
| `material_thick` | Two square Pills grouped toward the right, top inset | Workspaces; volume and date | Source defines only separate workspace and tray windows |
| `miniblocks` | Pills, top, three narrow fixed-width capsules | Roman-numeral workspaces; track; volume/time | Proportions and compact layout follow the three source bars |
| `minimal` | 50%-width floating bar, bottom | Workspaces; time; volume | Edge, width, height, and minimal module set follow its config |
| `san` | Full-width, top, very thin, frosted | Launcher, spaces, active title; track, volume/time/power | Compact left and right clusters |
| `tiny` | Fixed-width floating pill, aligned right | Roman focused workspace, volume percentage, date/time | Compact width and source's three modules are represented |
| `transparent` | Full-width, top, no bar background | Launcher, workspaces, active title; track/volume/time/power | Preserves the wallpaper-only treatment from the source |

## Fidelity notes

- Glance exposes one shared bar font rather than separate typefaces per widget. The source bitmap/icon font files are not installed on this Mac; the drafts use Menlo or Helvetica Neue fallbacks, so letterforms and bitmap glyphs are not pixel-identical.
- `blocks`, `cherryblocks`, and `miniblocks` show separate Polybar windows. Glance uses three width-configurable capsules in its single bar window to match their placement and proportions. `material` and `material_thick` also have independently positioned source windows; Pills and the center offset approximate those placements.
- Bitmap and icon fonts from the Linux screenshots may not be installed on this Mac. The drafts use installed SF Mono/SF Pro fonts, and Pywal drives colors dynamically.
- Workspace count, active window, battery, network, and live media are supplied by the Mac. Preview renders use a fixed sample track and window title so layout comparisons stay consistent.
- `activeapp` is a macOS frontmost-app label, which is only an approximation of Polybar's arbitrary X window-title module. Glance Spaces can show the focused window title where supported.

The 18 preview PNGs and contact sheet are in [PolybarThemePreviews](PolybarThemePreviews). The 18 snapshots are now seeded into Randomazzo.
