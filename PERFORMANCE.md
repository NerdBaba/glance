# Performance improvements

Measured on a Mac mini M4 on 4 October 2026. These are optimized Swift microbenchmarks of the production implementations, not a claim about total application CPU usage or startup time. Both versions are compiled with `swiftc -O`. Each timing is the median of seven runs after 100 warm-up operations; the repeated paths use 2,000 operations per run, and config construction uses 100. Background system activity can affect individual samples; the raw samples are included below.

## Results

| Operation | Before | After | Change |
| --- | ---: | ---: | --- |
| Widget config lookup (32-module fixture) | 79.342 μs | 0.033 μs | 99.96% less time |
| Clock formatting (alternating patterns/zones) | 38.944 μs | 0.960 μs | 97.53% less time |
| Polybar script rendering (10 formatting fixtures) | 39.532 μs | 18.654 μs | 52.81% less time |
| Clock formatting (already-warm single pattern) | 0.345 μs | 0.562 μs | 0.217 μs additional time |
| Config construction plus first widget lookup | 78.936 μs | 410.824 μs | 331.888 μs additional time |

The widget index is built once per decoded configuration. Construction plus one lookup increases from about 0.079 ms to 0.411 ms in this fixture. Repeated queries then return an existing dictionary instead of traversing and flattening every module. The already-warm clock control shows the small cost of locking and checking locale/calendar/time-zone keys; alternating clock/calendar patterns avoid repeatedly rebuilding the formatter.

In a deterministic 120-tick clock simulation, a minute-only label produces **2 publications instead of 120 (98.3% fewer)**. A pattern with seconds still produces all 120 updates. The one-second timer remains so seconds and live configuration changes work, while the dedicated clock thread and background run loop are removed.

## Implementation

- `WidgetsSection` precomputes its immutable settings index when the snapshot is initialized or decoded. Nested tables, dotted keys, and parent dictionaries retain their existing lookup behavior.
- `Config` resolves appearance once per immutable snapshot, including Pywal overrides, instead of rebuilding and logging it on each read. This also removes repeated appearance-related log work; no separate numerical gain is claimed for that change.
- The script renderer reuses its three fixed regular expressions and maintains a thread-safe, bounded 64-entry cache for user value regexes. Tokens, actions, markup, ramps, progress bars, and animations still use the same render path.
- Clock and calendar formatting share a bounded, locked cache of 16 formatters. Configured label changes drive publication, including custom patterns and time zones.

## Correctness checks

- Matching widget-output fingerprints for all **21 bundled theme configurations**, plus synthetic nested/dotted settings and missing/empty modules.
- Matching rendered text, styles, fonts, offsets, and click-action fingerprints for **250 script cases** covering labels, Unicode, token widths, progress bars, ramps, gradients, animations, failure formats, and invalid regex fallback.
- Matching date-output fingerprints against fresh formatters, including an invalid time-zone fallback; **256 concurrent formatter checks** pass.
- The Release build succeeds. Of 21 fixed-label before/after bar exports, **20 PNG files are identical**. `arch-blur` differs only in its live RAM label (`11.4G` versus `11.3G`); visual inspection shows unchanged layout. The other preview labels were fixed, but that module still reads live RAM.

## Reproduce

Requires macOS, Xcode command-line tools, and Python 3.11 or newer. The benchmark reads production Swift source and compiles an isolated executable. It disables automatic clock scheduling in that executable; date formatting and optimized clock publication use the production methods. The baseline clock publication simulation mirrors the old timer's unconditional assignment. No live bar, saved preset, or user config is changed.

```sh
baseline_dir=$(mktemp -d)
git archive 0ee47e4 | tar -x -C "$baseline_dir"
python3 scripts/benchmark-performance.py --source "$baseline_dir" --themes PolybarThemeDrafts --output /tmp/glance-before.json
python3 scripts/benchmark-performance.py --output /tmp/glance-after.json
```

Raw data: [before](PerformanceBenchmarks/before.json), [after](PerformanceBenchmarks/after.json), [bar export comparison](PerformanceBenchmarks/render-parity.json). The baseline feature commit is `0ee47e4`.
