//
//  OpenAIService.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/28/23.
//

// OpenAIService.swift
import Foundation
import OpenAI // Confirm the correct import for the OpenAI SDK

class OpenAIService: ObservableObject {
    private let apiToken = ConstantsAPI.openAIApiKey
    private let session = URLSession.shared
    
    func sendChatCompletion(query: ChatQuery, lastPage: Page, completion: @escaping (Result<Page, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com" + APIPath.chats) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        do {
            let jsonData = try encoder.encode(query)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                
                // Print raw JSON for debugging
                let rawJSON = String(data: data, encoding: .utf8) ?? "Invalid UTF-8 data"
                print("Received JSON: \(rawJSON)")

                if let newPage = self.parsePageFromResponse(data, lastPage: lastPage) {
                    completion(.success(newPage))
                } else {
                    completion(.failure(OpenAIError.invalidResponse))  // Handle nil case appropriately
                }
            }
        }.resume()
    }

    private func parsePageFromResponse(_ data: Data, lastPage: Page) -> Page? {
        do {
            let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            if let content = response.choices.first?.message.content {
                let sections = content.components(separatedBy: "**")
                var pageContent = "Content missing"
                var example = "Example missing"
                var explanation = "Explanation missing"
                var graphics = "Graphics suggestion missing"

                for i in 0..<sections.count {
                    if sections[i].contains("Content:") {
                        pageContent = sections[i + 1]
                    } else if sections[i].contains("Example:") {
                        example = sections[i + 1]
                    } else if sections[i].contains("Explanation:") {
                        explanation = sections[i + 1]
                    } else if sections[i].contains("Graphics:") {
                        graphics = sections[i + 1]
                    }
                }

                return Page(
                    id: UUID().uuidString,
                    content: pageContent.trimmingCharacters(in: .whitespacesAndNewlines),
                    pageNumber: lastPage.pageNumber + 1,
                    readyButtonDisplayed: false,
                    example: example.trimmingCharacters(in: .whitespacesAndNewlines),
                    explanation: explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                    graphics: graphics.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                print("No content available in response.")
                return nil
            }
        } catch {
            print("Decoding JSON failed: \(error)")
            return nil
        }
    }

    struct PageContent: Codable {
        let content: String
        let example: String
        let explanation: String
        let graphics: String
    }
}

// Ensure that your ChatQuery and related models are correctly defined for encoding
struct ChatQuery: Codable {
    let model: Model
    let messages: [ChatMessage]
}

struct ChatMessage: Codable {
    let role: SenderRole
    let content: String
}

enum SenderRole: String, Codable {
    case user, system, assistant
}

struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

enum OpenAIError: Error {
    case emptyResponse
    case invalidResponse  // Add this case
}

enum Model: String, Codable {
    case gpt3_5_turbo = "gpt-3.5-turbo"
    case gpt4 = "gpt-4"
}

extension Array {
    subscript (safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

typealias APIPath = String
extension APIPath {
    
    static let completions = "/v1/completions"
    static let embeddings = "/v1/embeddings"
    static let chats = "/v1/chat/completions"
    static let edits = "/v1/edits"
    static let models = "/v1/models"
    static let moderations = "/v1/moderations"
    
    static let audioSpeech = "/v1/audio/speech"
    static let audioTranscriptions = "/v1/audio/transcriptions"
    static let audioTranslations = "/v1/audio/translations"
    
    static let images = "/v1/images/generations"
    static let imageEdits = "/v1/images/edits"
    static let imageVariations = "/v1/images/variations"
    
    func withPath(_ path: String) -> String {
        self + "/" + path
    }
}

//struct CompletionsQuery {
//    let model: Model
//    let prompt: String
//    let temperature: Double
//    let maxTokens: Int
//}









