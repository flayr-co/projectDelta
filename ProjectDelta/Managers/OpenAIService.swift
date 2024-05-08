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
                    print("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Response Status: \(httpResponse.statusCode)")
                }

                guard let data = data, let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(ChatCompletionResponse.self, from: data)
                    if let content = result.choices.first?.message.content {
                        let newPage = Page(
                            id: UUID().uuidString,
                            content: content,
                            pageNumber: lastPage.pageNumber + 1,
                            readyButtonDisplayed: false,
                            example: nil,
                            explanation: nil,
                            graphics: nil
                        )
                        completion(.success(newPage))
                    } else {
                        completion(.failure(OpenAIError.emptyResponse))
                    }
                } catch {
                    print("JSON decoding error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }.resume()
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
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

enum OpenAIError: Error {
    case emptyResponse
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









