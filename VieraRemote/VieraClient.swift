import Foundation

/// Minimal Panasonic VIERA network-remote client (prototype for TH-43EX600).
/// - Key commands: SOAP `X_SendKey` to http://<host>:55000/nrc/control_0
/// - Volume / mute: UPnP RenderingControl to http://<host>:55000/dmr/control_0
@MainActor
final class VieraModel: ObservableObject {
    @Published var logLines: [String] = []
    @Published var volume: Double = 20
    @Published var hasVolume = false
    @Published var isBusy = false

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    func log(_ s: String) {
        logLines.insert("[\(timeFmt.string(from: Date()))] \(s)", at: 0)
        if logLines.count > 120 { logLines.removeLast(logLines.count - 120) }
    }

    // MARK: - low level SOAP

    private func soap(host: String, path: String, urn: String, action: String, bodyArgs: String) async -> (Int, String) {
        guard let url = URL(string: "http://\(host):55000\(path)") else {
            return (-1, "URLが作れませんでした（IPを確認）")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 6
        req.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("\"\(urn)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        req.setValue("Panasonic iOS VR-CP UPnP/2.0", forHTTPHeaderField: "User-Agent")
        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
        <u:\(action) xmlns:u="\(urn)">\(bodyArgs)</u:\(action)>
        </s:Body>
        </s:Envelope>
        """
        req.httpBody = Data(envelope.utf8)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""
            return (code, text)
        } catch {
            return (-2, error.localizedDescription)
        }
    }

    private func cleanHost(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .components(separatedBy: "/").first ?? ""
    }

    // MARK: - key commands

    func sendKey(host rawHost: String, key: String, label: String) async {
        let host = cleanHost(rawHost)
        guard !host.isEmpty else { log("⚠️ IPアドレスを入力してね"); return }
        isBusy = true
        defer { isBusy = false }
        let (code, body) = await soap(host: host,
                                      path: "/nrc/control_0",
                                      urn: "urn:panasonic-com:service:p00NetworkControl:1",
                                      action: "X_SendKey",
                                      bodyArgs: "<X_KeyEvent>NRC_\(key)-ONOFF</X_KeyEvent>")
        if code == 200 {
            log("✅ \(label) (NRC_\(key)) → HTTP 200")
        } else {
            let snip = body.prefix(120).replacingOccurrences(of: "\n", with: " ")
            log("❌ \(label) (NRC_\(key)) → HTTP \(code) \(snip)")
        }
    }

    // MARK: - volume / mute (RenderingControl)

    private func renderingControl(host: String, action: String, args: String) async -> (Int, String) {
        await soap(host: host,
                   path: "/dmr/control_0",
                   urn: "urn:schemas-upnp-org:service:RenderingControl:1",
                   action: action,
                   bodyArgs: "<InstanceID>0</InstanceID><Channel>Master</Channel>\(args)")
    }

    func fetchVolume(host rawHost: String) async {
        let host = cleanHost(rawHost)
        guard !host.isEmpty else { log("⚠️ IPアドレスを入力してね"); return }
        isBusy = true
        defer { isBusy = false }
        let (code, body) = await renderingControl(host: host, action: "GetVolume", args: "")
        if code == 200, let v = Self.intValue(in: body, tag: "CurrentVolume") {
            volume = Double(v)
            hasVolume = true
            log("✅ 接続OK・現在音量 = \(v)")
        } else {
            let snip = body.prefix(120).replacingOccurrences(of: "\n", with: " ")
            log("❌ 音量取得 → HTTP \(code) \(snip)")
        }
    }

    func applyVolume(host rawHost: String) async {
        let host = cleanHost(rawHost)
        guard !host.isEmpty else { log("⚠️ IPアドレスを入力してね"); return }
        let v = Int(volume.rounded())
        let (code, _) = await renderingControl(host: host, action: "SetVolume", args: "<DesiredVolume>\(v)</DesiredVolume>")
        log(code == 200 ? "✅ 音量を \(v) に設定" : "❌ 音量設定 → HTTP \(code)")
    }

    func fetchMute(host rawHost: String) async {
        let host = cleanHost(rawHost)
        guard !host.isEmpty else { log("⚠️ IPアドレスを入力してね"); return }
        let (code, body) = await renderingControl(host: host, action: "GetMute", args: "")
        if code == 200, let m = Self.intValue(in: body, tag: "CurrentMute") {
            log("✅ ミュート状態 = \(m == 1 ? "ON（消音中）" : "OFF")")
        } else {
            log("❌ ミュート取得 → HTTP \(code)")
        }
    }

    static func intValue(in xml: String, tag: String) -> Int? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else { return nil }
        return Int(xml[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces))
    }
}
