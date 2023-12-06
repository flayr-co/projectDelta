//
//  OpenAIService.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/28/23.
//

// OpenAIService.swift
import Foundation
import Alamofire

class OpenAIService {
    private let endpointUrl = "https://api.openai.com/v1/chat/completions"
    
    //    func sendMessage(messages:[Message]) async -> OpenAIChatResponse? {
    //        let openAIMessages = messages.map({OpenAIChatMessage(role: $0.role, content: $0.content)})
    //        let body = OpenAIChatBody(model: "gpt-4", messages: openAIMessages)
    //        let header: HTTPHeaders = [
    //            "Authorization": "Bearer \(ConstantsAPI.openAIApiKey)"
    //        ]
    //        return try? await AF.request(endpointUrl, method: .post, parameters: body, encoder: .json, headers: header).serializingDecodable(OpenAIChatResponse.self).value
    //    }
    
    func generateQuestion(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let openAIMessage = OpenAIChatMessage(role: .user, content: prompt)
        let body = OpenAIChatBody(model: "gpt-4", messages: [openAIMessage])
        let header: HTTPHeaders = [
            "Authorization": "Bearer \(ConstantsAPI.openAIApiKey)"
        ]
        
        AF.request(endpointUrl, method: .post, parameters: body, encoder: .json, headers: header).responseDecodable(of: OpenAIChatResponse.self) { response in
            switch response.result {
            case .success(let chatResponse):
                if let questionText = chatResponse.choices.first?.message.content {
                    completion(.success(questionText))
                } else {
                    completion(.failure(AFError.responseValidationFailed(reason: .dataFileNil)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func generateHint(forQuestion question: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = "Provide a hint for the following question: \(question)"
        let openAIMessage = OpenAIChatMessage(role: .user, content: prompt)
        let body = OpenAIChatBody(model: "gpt-4", messages: [openAIMessage])
        let header: HTTPHeaders = [
            "Authorization": "Bearer \(ConstantsAPI.openAIApiKey)"
        ]
        
        AF.request(endpointUrl, method: .post, parameters: body, encoder: .json, headers: header).responseDecodable(of: OpenAIChatResponse.self) { response in
            switch response.result {
            case .success(let chatResponse):
                if let hint = chatResponse.choices.first?.message.content {
                    completion(.success(hint))
                } else {
                    completion(.failure(AFError.responseValidationFailed(reason: .dataFileNil)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

struct OpenAIChatBody: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
}

struct OpenAIChatMessage: Codable {
    let role: SenderRole
    let content: String
}

enum SenderRole: String, Codable {
    case system
    case user
    case assistant
}

struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChatChoice]
}

struct OpenAIChatChoice: Decodable {
    let message: OpenAIChatMessage
}
