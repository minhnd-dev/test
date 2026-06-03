import Foundation

struct AnkiNote {
    let deckName: String
    let modelName: String
    let fields: [String: String]
    let tags: [String]
}

enum AnkiError: Error {
    case notRunning
    case requestFailed(String)
}

final class AnkiConnectService {
    static let shared = AnkiConnectService()
    private let baseURL = URL(string: "http://localhost:8765")!

    func ping() async throws -> Bool {
        let response = try await send(action: "requestPermission")
        return (response["result"] as? [String: Any])?["permission"] as? String == "granted"
    }

    func addNote(_ note: AnkiNote) async throws {
        let params: [String: Any] = [
            "note": [
                "deckName": note.deckName,
                "modelName": note.modelName,
                "fields": note.fields,
                "tags": note.tags
            ]
        ]
        _ = try await send(action: "addNote", params: params)
    }

    private func send(action: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "action": action,
            "version": 6,
            "params": params
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let json else {
            throw AnkiError.requestFailed("invalid response")
        }

        if let error = json["error"] as? String, !error.isEmpty {
            throw AnkiError.requestFailed(error)
        }

        return json
    }
}
