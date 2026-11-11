import SwiftUI

struct ContentView: View {
    @StateObject private var model = VieraModel()
    @AppStorage("tvHost") private var host: String = ""

    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    connectionSection
                    volumeSection
                    keySection(title: "電源・基本", keys: [
                        ("電源", "POWER"), ("ホーム", "HOME"), ("メニュー", "MENU"), ("番組表", "EPG"),
                        ("戻る", "RETURN"), ("取消", "CANCEL"), ("情報", "INFO"), ("オプション", "SUBMENU"),
                    ])
                    padSection
                    keySection(title: "チャンネル", keys: [
                        ("CH＋", "CH_UP"), ("CH−", "CH_DOWN"),
                    ])
                    keySection(title: "入力・アプリ", keys: [
                        ("テレビ", "TV"), ("HDMI1", "HDMI1"), ("HDMI2", "HDMI2"), ("HDMI3", "HDMI3"),
                        ("アプリ", "APPS"), ("Netflix", "NETFLIX"), ("マイアプリ", "MYAPP"), ("リンク", "VIERALINK"),
                    ])
                    keySection(title: "再生系", keys: [
                        ("再生", "PLAY"), ("一時停止", "PAUSE"), ("停止", "STOP"), ("録画", "REC"),
                        ("巻戻し", "REW"), ("早送り", "FF"), ("前へ", "SKIP_PREV"), ("次へ", "SKIP_NEXT"),
                    ])
                    keySection(title: "色ボタン", keys: [
                        ("青", "BLUE"), ("赤", "RED"), ("緑", "GREEN"), ("黄", "YELLOW"),
                    ])
                    logSection
                    Text("プロトタイプ v0.1（TH-43EX600向け検証用）。テレビとiPhoneが同じWi-Fi/LANにいること。電源オンはテレビ側の待機設定によっては効かない場合があります。各ボタンの結果は下のログに出ます。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("VieraRemote")
        }
    }

    // MARK: sections

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("テレビのIPアドレス").font(.headline)
            TextField("例: 192.168.1.20", text: $host)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            HStack {
                Button("接続テスト（音量取得）") { Task { await model.fetchVolume(host: host) } }
                    .buttonStyle(.borderedProminent)
                Button("ミュート状態") { Task { await model.fetchMute(host: host) } }
                    .buttonStyle(.bordered)
            }
            Text("ポートは 55000 固定。IPはテレビの「ネットワーク設定」やルーター側で確認できます。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("音量").font(.headline)
            HStack {
                keyButton("音量−", "VOLDOWN")
                keyButton("音量＋", "VOLUP")
                keyButton("ミュート", "MUTE")
            }
            HStack {
                Text("直接指定: \(Int(model.volume))")
                Slider(value: $model.volume, in: 0...100, step: 1, onEditingChanged: { editing in
                    if !editing { Task { await model.applyVolume(host: host) } }
                })
            }
            Text("スライダーは「接続テスト」で取得してから使うと確実です。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var padSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("十字キー・数字").font(.headline)
            HStack {
                Spacer()
                keyButton("↑", "UP")
                Spacer()
            }
            HStack {
                keyButton("←", "LEFT")
                keyButton("決定", "ENTER")
                keyButton("→", "RIGHT")
            }
            HStack {
                Spacer()
                keyButton("↓", "DOWN")
                Spacer()
            }
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(1..<10, id: \.self) { n in keyButton("\(n)", "D\(n)") }
                keyButton("0", "D0")
            }
        }
    }

    private func keySection(title: String, keys: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(keys, id: \.1) { item in keyButton(item.0, item.1) }
            }
        }
    }

    private func keyButton(_ title: String, _ key: String) -> some View {
        Button(title) { Task { await model.sendKey(host: host, key: key, label: title) } }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ログ").font(.headline)
                Spacer()
                Button("クリア") { model.logLines.removeAll() }
                    .font(.footnote)
            }
            if model.logLines.isEmpty {
                Text("まだ操作がありません。まず「接続テスト」を押してみてね。")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(model.logLines, id: \.self) { line in
                    Text(line).font(.system(.footnote, design: .monospaced))
                }
            }
        }
    }
}
