import AppKit

/// BetterDisplay's public distributed-notification transport. No subprocesses,
/// HTTP server, or extra CLI installation are needed for polling or adjustments.
final class BetterDisplayBrightnessClient: NSObject {
    static let shared = BetterDisplayBrightnessClient()

    private struct Request: Encodable {
        let uuid: String
        let commands: [String]
        let parameters: [String: String?]
    }
    private struct Response: Decodable {
        let uuid: String?
        let result: Bool?
        let payload: String?
    }
    private struct Pending {
        let timeout: DispatchWorkItem
        let completion: (Float?) -> Void
    }
    private var pending: [String: Pending] = [:]

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "pro.betterdisplay.BetterDisplay"
                || $0.bundleIdentifier == "com.betterdisplay.BetterDisplay"
        }
    }

    private override init() {
        super.init()
        for prefix in ["pro", "com"] {
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(receive(_:)),
                name: .init("\(prefix).betterdisplay.BetterDisplay.response"), object: nil)
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        for request in pending.values { request.timeout.cancel() }
    }

    /// `set get` returns the selected control's current value after adjustment.
    func brightness(displayID: UInt32, setting value: Float? = nil, completion: @escaping (Float?) -> Void) {
        guard isRunning else { completion(nil); return }
        let uuid = UUID().uuidString
        let request = Request(uuid: uuid, commands: value == nil ? ["get"] : ["set", "get"],
                              parameters: ["displayID": String(displayID), "brightness": value.map { String($0) }])
        guard let data = try? JSONEncoder().encode(request),
              let json = String(data: data, encoding: .utf8) else { completion(nil); return }
        let timeout = DispatchWorkItem { [weak self] in
            guard let request = self?.pending.removeValue(forKey: uuid) else { return }
            request.completion(nil)
        }
        pending[uuid] = Pending(timeout: timeout, completion: completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)
        let prefix = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "pro.betterdisplay.BetterDisplay"
        } ? "pro" : "com"
        DistributedNotificationCenter.default().postNotificationName(
            .init("\(prefix).betterdisplay.BetterDisplay.request"),
            object: json, userInfo: nil, deliverImmediately: true)
    }

    @objc private func receive(_ notification: Notification) {
        guard let json = notification.object as? String,
              let response = try? JSONDecoder().decode(Response.self, from: Data(json.utf8)),
              let uuid = response.uuid else { return }
        DispatchQueue.main.async { [weak self] in
            guard let request = self?.pending.removeValue(forKey: uuid) else { return }
            request.timeout.cancel()
            guard response.result != false, let payload = response.payload,
                  let value = Float(payload.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
                request.completion(nil)
                return
            }
            request.completion(value)
        }
    }
}
