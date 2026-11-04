import Foundation

/// The state handed to a tweak provider: what the wallpaper looks like and what
/// we are anchoring to. All values are plain, serializable data.
struct BarTweakState {
    var paletteHex: [String]
    var templateName: String
    var formation: String
    var widgetIDs: [String]
    var intent: String
}

/// A single typed decision: which question was asked, the chosen answer, and
/// how confident the model was. Decisions below a confidence threshold are
/// dropped before a patch is assembled.
struct BarTweakDecision: Identifiable, Equatable {
    let key: String
    let value: String
    let confidence: Double
    var id: String { key + ":" + value }
}

/// A typed patch of decisions layered on top of an anchored template. Applying a
/// patch never rewrites the template wholesale; it only overrides the fields the
/// decisions touch.
struct BarTweakPatch {
    var decisions: [BarTweakDecision]

    var formation: String? { value(for: "formation") }
    var accentIndex: Int? { value(for: "accent-index").flatMap(Int.init) }
    var density: String? { value(for: "density") }

    func value(for key: String) -> String? {
        decisions.first { $0.key == key }?.value
    }
}

/// A backend that turns bar state into typed tweak decisions.
protocol TweakProvider {
    func generateTweak(state: BarTweakState) async throws -> BarTweakPatch
}

/// Builds a provider from the configured type + resolved API key.
enum TweakProviderFactory {
    static func make(type: String, baseURL: String?, model: String?, apiKey: String?) throws -> TweakProvider {
        switch type {
        case "typesafe-jev":
            return try TypeSafeJevTweakProvider(apiKey: apiKey ?? "", model: model ?? "jev-latest", baseURL: baseURL)
        case "openai-compatible":
            return try OpenAICompatibleTweakProvider(apiKey: apiKey ?? "", model: model ?? "gpt-4o-mini", baseURL: baseURL)
        default:
            throw NSError(domain: "Glance", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown tweak provider type '\(type)'."])
        }
    }
}

/// TypeSafe Jev — a System One decision model. It does not generate text; given
/// `state` + typed `questions`, it returns choices/scores/probabilities with
/// confidence. We ask a small set of well-scoped questions and keep answers that
/// clear a confidence threshold.
struct TypeSafeJevTweakProvider: TweakProvider {

    private let apiKey: String
    private let model: String
    private let endpoint: URL

    init(apiKey: String, model: String, baseURL: String?) throws {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Glance", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No TypeSafe/Jev API key is configured."])
        }
        self.apiKey = apiKey
        self.model = model
        if let raw = baseURL, !raw.isEmpty, let url = URL(string: raw) {
            self.endpoint = url
        } else {
            self.endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
        }
    }

    func generateTweak(state: BarTweakState) async throws -> BarTweakPatch {
        let body: [String: Any] = [
            "model": model,
            "state": Self.statePayload(state),
            "questions": Self.buildQuestions(state: state),
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "TypeSafeJev", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Jev error \(http.statusCode): \(detail)"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = json["answers"] as? [String: Any] else {
            throw NSError(domain: "TypeSafeJev", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected Jev response shape."])
        }
        return Self.parse(answers: answers)
    }

    // MARK: - Questions

    private static func buildQuestions(state: BarTweakState) -> [String: [String: Any]] {
        var questions: [String: [String: Any]] = [:]

        questions["formation"] = [
            "type": "choice",
            "instructions": "Pick the bar formation that best fits this wallpaper and desktop.",
            "criteria": [
                "floating": "A single rounded capsule centered at the top; clean and low-profile.",
                "full": "A full-width edge-to-edge bar; denser, utility-focused.",
                "islands": "Separate capsules per widget with generous spacing.",
                "pills": "Widgets grouped into pills separated by spacers.",
            ],
        ]

        var accentCriteria: [String: String] = [:]
        for (i, hexv) in state.paletteHex.enumerated() {
            // Vivid mid-tones: skip the near-black background (0) and near-white
            // foreground (15), offer at most 8 candidates.
            guard i > 0, i < 15, i % 2 == 1, accentCriteria.count < 8 else { continue }
            accentCriteria[String(i)] = "palette index \(i) (#\(hexv))"
        }
        if !accentCriteria.isEmpty {
            questions["accent"] = [
                "type": "choice",
                "instructions": "Which palette color should act as the accent hue? Prefer vivid mid-tones; avoid near-background and near-foreground.",
                "criteria": accentCriteria,
            ]
        }

        questions["density"] = [
            "type": "choice",
            "instructions": "How information-dense should the bar be?",
            "criteria": [
                "minimal": "Only the few most essential widgets; lots of empty space.",
                "balanced": "A comfortable set of everyday widgets.",
                "rich": "Include monitoring and system widgets for maximum utility.",
            ],
        ]

        return questions
    }

    private static func statePayload(_ state: BarTweakState) -> [String: Any] {
        var payload: [String: Any] = [
            "palette": state.paletteHex,
            "template": state.templateName,
            "formation": state.formation,
            "widget_ids": state.widgetIDs,
        ]
        if !state.intent.isEmpty { payload["user_intent"] = state.intent }
        return payload
    }

    // MARK: - Parsing

    private static func parse(answers: [String: Any]) -> BarTweakPatch {
        let threshold = 0.6
        var decisions: [BarTweakDecision] = []

        for (key, raw) in answers {
            guard let answer = raw as? [String: Any] else { continue }
            switch answer["type"] as? String {
            case "choice":
                guard let choice = answer["choice"] as? String,
                      let conf = answer["confidence"] as? Double, conf >= threshold else { continue }
                decisions.append(BarTweakDecision(key: mappedKey(key), value: choice, confidence: conf))
            case "score":
                guard let score = answer["score"] as? Double,
                      let conf = answer["confidence"] as? Double, conf >= threshold else { continue }
                decisions.append(BarTweakDecision(key: mappedKey(key), value: String(Int(score.rounded())), confidence: conf))
            case "noul":
                // Not used by our current question set; kept for extensibility.
                continue
            default:
                continue
            }
        }
        return BarTweakPatch(decisions: decisions)
    }

    private static func mappedKey(_ key: String) -> String {
        switch key {
        case "formation": return "formation"
        case "accent": return "accent-index"
        case "density": return "density"
        default: return key
        }
    }
}

/// OpenAI-compatible chat backend. Unlike Jev it is a generative LLM, so we
/// constrain it with a strict JSON response and validate every returned value
/// against the same typed decision schema before accepting it.
struct OpenAICompatibleTweakProvider: TweakProvider {

    private let apiKey: String
    private let model: String
    private let endpoint: URL

    init(apiKey: String, model: String, baseURL: String?) throws {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Glance", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No API key configured for the OpenAI-compatible provider."])
        }
        self.apiKey = apiKey
        self.model = model
        if let raw = baseURL, !raw.isEmpty, let url = URL(string: raw) {
            self.endpoint = url
        } else {
            self.endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        }
    }

    func generateTweak(state: BarTweakState) async throws -> BarTweakPatch {
        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": Self.systemPrompt(state: state)],
                ["role": "user", "content": Self.userPrompt(state: state)],
            ],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAICompatible", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Provider error \(http.statusCode): \(detail)"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String,
              let parsed = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any]
        else {
            throw NSError(domain: "OpenAICompatible", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected provider response shape."])
        }
        return Self.parse(parsed)
    }

    private static func systemPrompt(state: BarTweakState) -> String {
        "You are a design decision engine for a macOS status bar. Return ONLY a JSON object with these exact keys:\n" +
        "- \"formation\": one of \"floating\", \"full\", \"islands\", \"pills\"\n" +
        "- \"accent\": a string palette index offered below\n" +
        "- \"density\": one of \"minimal\", \"balanced\", \"rich\"\n" +
        "Choose values that fit the wallpaper palette and template. No prose, no markdown."
    }

    private static func userPrompt(state: BarTweakState) -> String {
        var lines: [String] = []
        lines.append("Template: \(state.templateName)")
        lines.append("Current formation: \(state.formation)")
        lines.append("Available widgets: \(state.widgetIDs.joined(separator: ", "))")
        lines.append("Palette: \(state.paletteHex.enumerated().map { "\($0.offset)=\($0.element)" }.joined(separator: ", "))")
        if !state.intent.isEmpty { lines.append("User intent: \(state.intent)") }
        return lines.joined(separator: "\n")
    }

    private static func parse(_ json: [String: Any]) -> BarTweakPatch {
        var decisions: [BarTweakDecision] = []

        if let formation = json["formation"] as? String,
           ["floating", "full", "islands", "pills"].contains(formation) {
            decisions.append(BarTweakDecision(key: "formation", value: formation, confidence: 1.0))
        }
        if let accent = json["accent"] as? String, let idx = Int(accent), (0...15).contains(idx) {
            decisions.append(BarTweakDecision(key: "accent-index", value: String(idx), confidence: 1.0))
        }
        if let density = json["density"] as? String,
           ["minimal", "balanced", "rich"].contains(density) {
            decisions.append(BarTweakDecision(key: "density", value: density, confidence: 1.0))
        }
        return BarTweakPatch(decisions: decisions)
    }
}
