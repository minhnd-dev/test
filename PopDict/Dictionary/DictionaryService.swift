import Foundation

struct Definition {
    let partOfSpeech: String
    let meaning: String
}

struct DictionaryResult {
    let word: String
    let definitions: [Definition]
    let examples: [String]
}

protocol DictionaryServiceProtocol {
    func lookup(_ text: String) async throws -> DictionaryResult
}

final class MockDictionaryService: DictionaryServiceProtocol {
    func lookup(_ text: String) async throws -> DictionaryResult {
        DictionaryResult(
            word: text,
            definitions: [
                Definition(partOfSpeech: "noun", meaning: "A placeholder definition for \"\(text)\"")
            ],
            examples: []
        )
    }
}
