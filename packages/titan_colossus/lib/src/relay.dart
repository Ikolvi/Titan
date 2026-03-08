/// **Relay** — Cross-platform HTTP bridge for AI-driven campaign execution.
///
/// Relay embeds a lightweight HTTP server inside the running Flutter app,
/// enabling AI assistants (via the MCP server) to execute Campaigns,
/// read Terrain data, and receive Debrief reports — all without any
/// human interaction.
///
/// ## Platform Support
///
/// | Platform | Support | Mechanism |
/// |----------|---------|-----------|
/// | Android  | ✅ Full | `dart:io` HttpServer |
/// | iOS      | ✅ Full | `dart:io` HttpServer |
/// | macOS    | ✅ Full | `dart:io` HttpServer |
/// | Windows  | ✅ Full | `dart:io` HttpServer |
/// | Linux    | ✅ Full | `dart:io` HttpServer |
/// | Web      | ⚠ Stub  | Browsers cannot host servers |
///
/// ## Architecture
///
/// ```
/// AI Assistant → MCP Server (stdio) → HTTP → Relay (in-app) → Colossus
///                                                 ↓
///                                          executeCampaignJson
///                                                 ↓
///                                          CampaignResult → HTTP Response
/// ```
///
/// ## Network Connectivity
///
/// | Scenario | How MCP reaches the app |
/// |----------|------------------------|
/// | Desktop (macOS/Win/Linux) | `localhost:{port}` |
/// | Android emulator | `adb forward tcp:{port} tcp:{port}` |
/// | Android device | `adb forward` or device IP on same WiFi |
/// | iOS simulator | `localhost:{port}` |
/// | iOS device | Device IP on same WiFi |
///
/// ## Security
///
/// Relay uses a bearer token for authentication. Every request must
/// include `Authorization: Bearer <token>` or be rejected with 401.
/// The token is generated on startup and logged to Chronicle so
/// the MCP server can read it.
///
/// ## Endpoints
///
/// | Method | Path | Purpose |
/// |--------|------|---------|
/// | GET | `/health` | Health check (no auth required) |
/// | GET | `/terrain` | Current Terrain graph |
/// | GET | `/blueprint` | Full AI context |
/// | POST | `/campaign` | Execute Campaign JSON, return results |
/// | POST | `/debrief` | Analyze verdicts |
/// | GET | `/status` | Relay status + port + version |
library;

export 'relay/relay.dart';
