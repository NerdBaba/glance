#!/usr/bin/env python3
"""Benchmark production Swift paths without launching or changing the live bar."""
import argparse, json, pathlib, subprocess, tempfile, tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
parser.add_argument('--themes', type=pathlib.Path)
parser.add_argument('--output', type=pathlib.Path, required=True)
parser.add_argument('--iterations', type=int, default=2000)
parser.add_argument('--runs', type=int, default=7)
args = parser.parse_args()
assert args.iterations > 0 and args.runs >= 3
root = args.source.resolve()
models = (root/'Glance/Config/ConfigModels.swift').read_text()
models = models[models.index('enum WidgetColorMode:'):models.index('class ConfigProvider:')] + models[models.index('struct WidgetsSection:'):models.index('struct YabaiConfig:')]
clock_source = (root/'Glance/Widgets/Time+Calendar/TimeWidget.swift').read_text()
clock_start = clock_source.index('class TimeProvider:')
if clock_source[clock_start-6:clock_start] == 'final ': clock_start -= 6
clock = clock_source[clock_start:clock_source.index('struct TimeWidget_Previews:')]
# Disable only automatic scheduling in this extracted benchmark. Formatting and
# publication methods below are the production implementations; no live UI runs.
start = clock.index('    init() {')
brace = clock.index('{', start)
depth, end = 1, brace+1
while depth:
    depth += (clock[end] == '{') - (clock[end] == '}')
    end += 1
clock = clock[:start] + '    init() {}' + clock[end:]
optimized = (root/'Glance/Widgets/Time+Calendar/DateFormattingCache.swift').exists()
cache = (root/'Glance/Widgets/Time+Calendar/DateFormattingCache.swift').read_text() if optimized else ''
renderer = (root/'Glance/Widgets/Script/PolybarScriptCompatibility.swift').read_text()
themes = args.themes or root/'PolybarThemeDrafts'
fixtures = []
for path in sorted(themes.glob('*.toml')):
    widgets = tomllib.loads(path.read_text()).get('widgets', {})
    others = {k:v for k,v in widgets.items() if isinstance(v, dict) and k != 'widget-colors'}
    names = [item if isinstance(item, str) else next(iter(item)) for item in widgets.get('displayed', [])]
    fixtures.append({'name':path.stem, 'others':others, 'names':names})

harness = r'''
import AppKit
import Combine
import CryptoKit
import CoreFoundation
import Foundation

func value(_ object: Any) -> TOMLValue {
    if let string = object as? String { return .string(string) }
    if let number = object as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
        if String(cString: number.objCType) == "d" { return .double(number.doubleValue) }
        return .int(number.intValue)
    }
    if let array = object as? [Any] { return .array(array.map(value)) }
    if let dict = object as? [String: Any] { return .dictionary(dict.mapValues(value)) }
    return .null
}
func serialize(_ value: TOMLValue) -> String {
    switch value {
    case .string(let s): return "s:\(s)"
    case .bool(let b): return "b:\(b)"
    case .int(let i): return "i:\(i)"
    case .double(let d): return "d:\(d)"
    case .array(let a): return "[" + a.map(serialize).joined(separator: "|") + "]"
    case .dictionary(let d): return "{" + d.keys.sorted().map { "\($0)=\(serialize(d[$0]!))" }.joined(separator: "|") + "}"
    case .null: return "null"
    }
}
func color(_ color: NSColor?) -> String {
    guard let c = color?.usingColorSpace(.deviceRGB) else { return "nil" }
    return "\(c.redComponent),\(c.greenComponent),\(c.blueComponent),\(c.alphaComponent)"
}
func signature(_ pieces: [PolybarScriptPiece]) -> String {
    pieces.map { piece in
        switch piece {
        case .offset(let size): return "offset:\(size)"
        case .text(let text, let style, let actions):
            let font = style.font.map { "\($0.fontName):\($0.pointSize)" } ?? "nil"
            let action = actions.keys.sorted().map { "\($0):\(actions[$0]!)" }.joined(separator: "|")
            return "\(text)/\(color(style.foreground))/\(color(style.background))/\(color(style.underline))/\(color(style.overline))/\(font)/\(action)"
        }
    }.joined(separator: "\n")
}
func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
struct RenderCase { let output: String; let config: ConfigData; let failed: Bool }
let cases: [RenderCase] = [
    .init(output: "hello", config: [:], failed: false),
    .init(output: "Boards of Canada — An Eagle… 🐻", config: ["label": .string("%output:8:25:...%")], failed: false),
    .init(output: "47%", config: ["format": .string("<ramp-volume> <label> <bar-volume>"), "label": .string("%percentage%%"), "ramp-volume-0": .string("▁"), "ramp-volume-1": .string("▃"), "ramp-volume-2": .string("█"), "bar-volume-width": .int(10), "bar-volume-fill": .string("━"), "bar-volume-empty": .string("─"), "bar-volume-indicator": .string("●"), "format-background": .string("#222222"), "format-foreground": .string("#eeeeee")], failed: false),
    .init(output: "57", config: ["format": .string("%{A1:echo hi:}%{F#fa8072}<label>%{F-}%{A} %{O4px}"), "label": .string("%counter% %pid% %output%")], failed: false),
    .init(output: "通信 42.5%", config: ["value-regex": .string("([0-9]+\\.[0-9]+)%"), "format": .string("<bar-load> <label>"), "label": .string("%value%"), "bar-load-width": .int(8), "bar-load-gradient": .bool(true), "bar-load-foreground-0": .string("#ff0000"), "bar-load-foreground-1": .string("#00ff00")], failed: false),
    .init(output: "tail", config: ["format": .string("<animation-wait> <label>"), "animation-wait-0": .string("◐"), "animation-wait-1": .string("◓"), "animation-wait-2": .string("◑"), "animation-wait-framerate": .int(250), "label-padding": .int(2), "format-offset": .string("3px")], failed: false),
    .init(output: "unavailable", config: ["format-fail": .string("<label-fail>"), "label-fail": .string("ERR %output%"), "format-fail-foreground": .string("#ff8800")], failed: true),
    .init(output: "-5", config: ["value-min": .int(-10), "value-max": .int(10), "format": .string("<ramp-test>"), "ramp-test-0": .string("low"), "ramp-test-1": .string("mid"), "ramp-test-2": .string("high"), "ramp-test-1-weight": .int(3)], failed: false),
    .init(output: "21", config: ["value-regex": .string("[invalid"), "label": .string("%output% %% %unknown%")], failed: false),
    .init(output: "ABC", config: ["format": .string("%{T1}%{u#ff0000}%{o#00ff00}%{A3:echo x\\:y:}<label>%{A}%{u-}%{o-}%{T-}"), "font-0": .string("Menlo:size=12"), "label-minlen": .int(12), "label-alignment": .string("center")], failed: false),
]
func render(_ i: Int) -> [PolybarScriptPiece] {
    let c = cases[i % cases.count]
    return PolybarScriptRenderer.render(output: c.output, config: c.config, actions: [1:"echo default",4:"echo up"], counter: i, pid: 123, failed: c.failed, animationTime: Double(i) / 10)
}
@inline(never) func measure(iterations: Int, runs: Int, operation: (Int) -> Int) -> [String: Any] {
    var consumed = 0
    for i in 0..<100 { consumed &+= operation(i) }
    var samples: [Double] = []
    for _ in 0..<runs {
        let start = DispatchTime.now().uptimeNanoseconds
        for i in 0..<iterations { consumed &+= operation(i) }
        samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
    }
    let median = samples.sorted()[samples.count/2]
    return ["samples_ms":samples, "median_ns_per_op":median*1_000_000/Double(iterations), "iterations":iterations, "runs":runs, "consumed":consumed]
}
@main struct PerformanceBenchmark {
    static func main() throws {
        let iterations = Int(CommandLine.arguments[2])!
        let runs = Int(CommandLine.arguments[3])!
        let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [[String: Any]]
        var widgetResults: [String] = []
        for fixture in fixtures {
            let sections = (fixture["others"] as! [String: [String: Any]]).mapValues { $0.mapValues(value) }
            let widgets = WidgetsSection(displayed: [], others: sections)
            let names = (fixture["names"] as! [String]) + ["missing.widget", "default", "default.time.calendar"]
            for name in names { widgetResults.append("\(fixture["name"]!)/\(name)/\(widgets.config(for: name).map { serialize(.dictionary($0)) } ?? "nil")") }
        }
        var sections: [String: ConfigData] = [:]
        var nested: ConfigData = [:]
        var names: [String] = []
        for i in 0..<24 {
            var values: ConfigData = [:]
            for k in 0..<12 { values["option-\(k)"] = .int(i*12+k) }
            values["space"] = .dictionary(["highlight": .string("pill"), "padding": .int(8)])
            values["calendar"] = .dictionary(["format": .string("HH:mm"), "show-events": .bool(true)])
            nested["module\(i)"] = .dictionary(values)
            names.append("default.module\(i)")
        }
        nested["empty"] = .dictionary([:])
        sections["default"] = nested
        for i in 0..<8 {
            sections["script.metric\(i)"] = ["format": .string("<label>"), "label": .string("%output%"), "interval": .int(5)]
            names.append("script.metric\(i)")
        }
        let widgets = WidgetsSection(displayed: [], others: sections)
        for name in names + ["default.empty", "default.module2.space", "script", "missing"] {
            widgetResults.append("synthetic/\(name)/\(widgets.config(for: name).map { serialize(.dictionary($0)) } ?? "nil")")
        }
        let time = TimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let patterns = ["E d, HH:mm", "HH:mm:ss", "yyyy-MM-dd HH:mm"]
        let zones = ["Asia/Kolkata", "UTC", "America/New_York"]
        var dateResults: [String] = []
        for pattern in patterns + ["J:mm", "EEE d MMM"] {
            for zone in zones + ["Invalid/Zone"] {
                let date = Date(timeIntervalSince1970: 1_794_000_000)
                let expected = DateFormatter()
                expected.dateFormat = pattern
                expected.timeZone = TimeZone(identifier: zone) ?? .current
                let actual = time.format(pattern: pattern, date: date, timeZone: zone)
                precondition(actual == expected.string(from: date), "Date output differs from a fresh formatter")
                dateResults.append(actual)
            }
        }
        var report: [String: Any] = [
            "widget_fingerprint":digest(widgetResults.joined(separator:"\n")),
            "render_fingerprint":digest((0..<250).map { signature(render($0)) }.joined(separator:"\n")),
            "clock_fingerprint":digest(dateResults.joined(separator:"\n")),
            "theme_fixtures":fixtures.count,
            "widget_lookup":measure(iterations: iterations, runs: runs) { widgets.config(for: names[$0 % names.count])?.count ?? 0 },
            "widget_index_build":measure(iterations: max(100,iterations/20), runs: runs) { _ in WidgetsSection(displayed: [], others: sections).config(for:"default.module2")?.count ?? 0 },
            "polybar_render":measure(iterations: iterations, runs: runs) { render($0).count },
            "clock_same_format":measure(iterations: iterations, runs: runs) { time.format(pattern:"HH:mm", date:baseDate.addingTimeInterval(Double($0)), timeZone:"UTC").count },
            "clock_alternating_formats":measure(iterations: iterations, runs: runs) { time.format(pattern:patterns[$0 % patterns.count], date:baseDate.addingTimeInterval(Double($0)), timeZone:zones[$0 % zones.count]).count }
        ]
        __CLOCK_CHECKS__
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(data:data, encoding:.utf8)!)
    }
}
'''
checks = r'''
        let cache = DateFormattingCache()
        let lock = NSLock()
        var mismatches = 0
        DispatchQueue.concurrentPerform(iterations: 256) { index in
            let pattern = patterns[index % patterns.count]
            let zone = zones[index % zones.count]
            let date = baseDate.addingTimeInterval(Double(index))
            let formatter = DateFormatter()
            formatter.dateFormat = pattern
            formatter.timeZone = TimeZone(identifier: zone)
            if cache.string(pattern:pattern, date:date, timeZone:zone) != formatter.string(from:date) {
                lock.lock(); mismatches += 1; lock.unlock()
            }
        }
        precondition(mismatches == 0, "Concurrent formatter mismatch")
        var updates = 0
        time.configure(pattern:"HH:mm", timeZone:"UTC")
        let observer = time.$formattedTime.dropFirst().sink { _ in updates += 1 }
        for second in 0..<120 { time.update(at:baseDate.addingTimeInterval(Double(second))) }
        report["minute_clock_publications_120_ticks"] = updates
        precondition(updates == 2, "Minute-only clock should publish twice")
        time.configure(pattern:"HH:mm:ss", timeZone:"UTC")
        updates = 0
        for second in 0..<120 { time.update(at:baseDate.addingTimeInterval(Double(second))) }
        report["second_clock_publications_120_ticks"] = updates
        precondition(updates == 120, "Clock containing seconds must update every second")
        observer.cancel()
        report["concurrent_date_checks"] = 256
'''
harness = harness.replace('__CLOCK_CHECKS__', checks if optimized else '''
        // The old timer assigned its @Published label unconditionally every tick.
        var updates = 0
        let observer = time.$formattedTime.dropFirst().sink { _ in updates += 1 }
        for second in 0..<120 { time.formattedTime = time.format(pattern:"HH:mm", date:baseDate.addingTimeInterval(Double(second)), timeZone:"UTC") }
        report["minute_clock_publications_120_ticks"] = updates
        observer.cancel()
''')
with tempfile.TemporaryDirectory(prefix='glance-perf-') as tmp:
    tmp = pathlib.Path(tmp)
    swift = tmp/'benchmark.swift'
    swift.write_text('import AppKit\nimport Combine\nimport Foundation\nimport SwiftUI\n' + models + '\n' + renderer + '\n' + cache + '\n' + clock + '\n' + harness)
    fixture_path = tmp/'themes.json'
    fixture_path.write_text(json.dumps(fixtures, ensure_ascii=False))
    subprocess.run(['xcrun','swiftc','-O','-parse-as-library',str(swift),'-o',str(tmp/'benchmark')], check=True)
    result = subprocess.run([str(tmp/'benchmark'),str(fixture_path),str(args.iterations),str(args.runs)], check=True, capture_output=True, text=True)
    report = json.loads(result.stdout)
    report['source'] = str(root)
    report['optimized'] = optimized
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if not isinstance(v,dict)}, indent=2))
