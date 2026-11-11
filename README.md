# VieraRemote (prototype)

Panasonic VIERA TH-43EX600 向けネットワークリモコンの試作 iPhone アプリ。

- キー送信: SOAP X_SendKey → http://<TV-IP>:55000/nrc/control_0 (NRC_* コード)
- 音量取得/設定・ミュート取得: UPnP RenderingControl → http://<TV-IP>:55000/dmr/control_0
- 各操作の HTTP 結果をアプリ内ログに表示し、実機で効くキーを検証するためのプロトタイプ

ビルドは GitHub Actions (macOS) で未署名 IPA を生成し、Release に添付する。
インストールには ESign / AltStore 等での署名が必要。
