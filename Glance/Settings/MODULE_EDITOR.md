# Module editor

Settings shows imported modules as native Glance modules, with their own sections.

- **Module preview** renders sample data through the bar formatter. Choose a state and vary the sample percentage to inspect ramps and progress bars. It does not launch commands or invoke click actions.
- **Text & components** previews each draft while typing. Insert offers the module's live values, reusable components, icons, glyphs, and spacing. Return or focus loss applies text changes.
- **Choose icon** offers searchable, named system icons. Original glyphs remain available with Restore glyph. Workspace icon assignments have separate space and icon fields.
- **Customize** beside a label adds foreground, background, font index, padding, margin, truncation, alignment, underline, or overline overrides.
- **Ramps, progress & animation** edits levels, filled/empty/indicator segments, colors, gradients, padding, font indices, and frame duration. Add component creates labels, ramps, or progress bars without overwriting an existing component.
- **Click & scroll actions** offers installed terminal/browser/file manager/application choices and a folder or website destination. Native modules can retain their default action or override the label click. Player control buttons keep their individual commands. Command modules also support left/middle/right/double click and scroll actions, with shell commands available explicitly.
- **Typography**, **Colors**, **Size & spacing**, and **Shared capsule** retain the existing appearance controls. Component fonts have a native font chooser.
- **Other module options** exposes remaining configured options, including environment and token values. Add option has a catalog plus a custom key/type editor. Array and table drafts are validated as TOML before being applied. Unsupported keys do not add new module behavior.

Structured command actions use `glance:terminal`, `glance:browser`, `glance:files`, etc. Destinations belong to each input event (`click-left-app`, `click-left-url`, `click-left-folder`, and equivalents). They use NSWorkspace, not shell interpolation. Native overrides use `native-click-action` and `native-click-action-app/url/folder`. Existing `native-action` shortcuts and `action-app/url/folder` continue to work.

Script runtime settings trigger a process refresh when changed. Formatting and palette edits leave the running command and output intact. Inline system icon markers are atomic during label truncation and render in both native and command modules.

For isolated visual inspection:

```sh
GLANCE_CONFIG_PATH=/tmp/review.toml Glance.app/Contents/MacOS/Glance \
  --export-module-editor /tmp/module.png --module script.my_module
```

This exporter draws the actual settings view with AppKit, without desktop capture permission. Always use a copied configuration for review. Theme drafts are not saved to Randomazzo by opening or exporting an editor.
