# Polybar Script Widgets in Glance

Glance's `script.*` widgets accept Polybar `custom/script` option names and render Polybar-style script output. Add the widget ID to `widgets.displayed`, then put its options under `[widgets."script.<name>"]`.

```toml
[widgets]
displayed = ["script.volume"]

[widgets."script.volume"]
exec = "osascript -e 'output volume of (get volume settings)'"
interval = 2
exec-if = "true"
format = "<label> <ramp-volume> <bar-volume>"
label = "VOL %output%%"
value-regex = "([0-9]+)"

click-left = "open -a 'System Settings'"
click-right = "osascript -e 'set volume output muted true'"
scroll-up = "osascript -e 'set volume output volume (output volume of (get volume settings) + 5)'"
scroll-down = "osascript -e 'set volume output volume (output volume of (get volume settings) - 5)'"

ramp-volume-0 = "▁"
ramp-volume-1 = "▃"
ramp-volume-1-weight = 2
ramp-volume-2 = "▅"
ramp-volume-3 = "▇"
ramp-volume-4 = "█"

bar-volume-width = 8
bar-volume-fill = "━"
bar-volume-indicator = "╸"
bar-volume-empty = "─"
bar-volume-gradient = true
bar-volume-foreground-0 = "#82aaff"
bar-volume-foreground-1 = "#c792ea"
bar-volume-foreground-2 = "#ff5370"
```

## Supported script options

- `exec` (or Glance's older `command`), `exec-if`, `tail`, `interval`, `interval-fail`, `interval-if`, `timeout`, and `env-NAME`.
- `format`, `format-fail`, the matching state-specific `format-fail-*` prefix/suffix/style fields, and the common `format-*` foreground/background/underline/overline/font/padding/offset fields.
- `label`, `label-fail` and label foreground/background/font/underline/overline, padding, margin, minimum/maximum width, alignment, and ellipsis options; tokens `%output%`, `%value%`, `%percentage%`, `%counter%`, and `%pid%`, including Polybar-style min/max width and truncation suffixes such as `%output:0:15:...%`.
- `click-left`, `click-middle`, `click-right`, `double-click-left`, `double-click-middle`, `double-click-right`, `scroll-up`, and `scroll-down`.

Script output supports Polybar markup for nested actions, foreground/background colors, reverse colors, underline/overline, font selection, and pixel/point offsets: `%{A1:command:}`, `%{F#rrggbb}`, `%{B#rrggbb}`, `%{R}`, `%{u#rrggbb}`, `%{o#rrggbb}`, `%{T1}`, and `%{O5}`. A colon inside an action command must be escaped as `\:` as in Polybar.

## Per-widget segments

Built-in widgets and `script.*` widgets can each use a separate segment style in their normal `[widgets.<module>]` table. Glance also exposes these settings in **Settings → Modules → select a module**.

```toml
[widgets.default.mediacontrols]
format-background = "#976b6b"
format-foreground = "#171010"
format-background-opacity = 1.0
format-padding = 7
format-radius = 0

[widgets.default.volume]
format-background = "pywal:8"
format-foreground = "#171010"
format-padding = 7
```

`format-background` and `format-foreground` accept `#RRGGBB`, Polybar `#AARRGGBB`, or `pywal:N` / `pywal-index:N` for palette indices 0–15. `format-border-color`, `format-border-width`, `format-background-opacity`, and `format-radius` style the widget segment. Built-in widgets interpret `format-padding` as image points (0–48). Script widgets preserve Polybar padding semantics: integers add spaces and `px` / `pt` values add offsets, without a second native inset. Glance adds `format-min-width` (0–320), `format-alignment` (`left`, `center`, `right`), and `format-font-name` / `format-font-size` / `format-font-weight` for native widget layout; these are Glance extensions. Explicit segment padding replaces a built-in widget's automatic horizontal inset. A segment background draws over the formation's normal widget background. In pills, groups with segment backgrounds have no extra capsule padding, so the first colored module starts flush with the panel edge.

## Native typography and icons

Native media controls accept `icon-prev`, `icon-play`, `icon-pause`, `icon-next`, and `control-spacing`. Volume accepts numerically indexed `ramp-volume-N` glyphs and `content-spacing`; launcher and power widgets accept `glyph`. These widgets use `icon-font-name`, `icon-font-size`, and `icon-offset-y` when a glyph is configured, and keep their native click actions. Glance bundles Font Awesome 5 Free Solid with its upstream license and registers it for the process. `SF Mono` uses macOS's monospaced system font.

Now playing accepts `content-spacing`, `content-padding`, `time-separator`, and `time-opacity`, along with the existing title/artist/album, position, duration, progress, and visualizer options. Text and playback time inherit the widget foreground. All native module typography and glyph options are exposed in Settings → Modules → select a module.

## Image comparisons

`Glance --export-bar PATH --export-width WIDTH` produces a PNG without starting the normal app or importing Randomazzo drafts. `--export-top-inset` and `--export-bottom-inset` add space for panel shadows. Preview-only environment overrides `GLANCE_PREVIEW_WINDOW_TITLE`, `GLANCE_PREVIEW_TRACK_TITLE`, `GLANCE_PREVIEW_TRACK_ARTIST`, `GLANCE_PREVIEW_TRACK_POSITION`, `GLANCE_PREVIEW_TRACK_DURATION`, `GLANCE_PREVIEW_VOLUME_PERCENT`, and `GLANCE_PREVIEW_TIME_LABEL` make comparisons repeatable. Live widgets still display real local values. Exported native fonts use macOS antialiasing, which can differ from a Linux screenshot.

`--preview-panel` opens the diagnostic content in a native bar panel while skipping Randomazzo import, updater startup, hotkeys, window-gap management, and normal onboarding. Use `GLANCE_CONFIG_PATH` to point it at a review config. Native bar windows reserve vertical space for shadows and glow while keeping the configured bar margin and height.

For a layout measured from a screenshot, set `[experimental.foreground] reference-width` to the source image width. Glance scales the complete bar uniformly to the current display/export width, including text and effect geometry. The default `0` preserves normal display layout. The option is also available in Settings → Layout as Reference Image Width. This is a Glance extension for screenshot replication, rather than Polybar's percentage-width syntax.

Use `<ramp-NAME>`, `<bar-NAME>`, and `<animation-NAME>` in `format` to render components from `ramp-NAME-N`, `bar-NAME-*`, and `animation-NAME-N` options. The script output supplies the ramp/progress value; by default Glance reads its first number as a 0–100 percentage. Set `value-regex` to select a capture group, or `value-min` and `value-max` to map another range to 0–100. Ramps preserve the first and last entries as range endpoints and use interior `-weight` values for thresholds. Progress bars accept `-width`, `-format`, `-fill`, `-indicator`, `-empty`, `-gradient`, and `-foreground-N` gradient stops. Animations cycle their indexed labels at `-framerate` milliseconds.

Script and action commands run through `/bin/sh -c` under the current user's environment, with Homebrew paths added for GUI-launched Glance. These options cover the custom-script presentation surface; they do not make Glance a general Polybar INI interpreter. Polybar's Linux/X11 modules, window-manager integration, tray, arbitrary multi-bar geometry, configuration includes/inheritance, and Rofi menu ecosystem still need explicit Glance equivalents or adapters.
