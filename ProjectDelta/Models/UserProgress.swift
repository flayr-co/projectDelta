//
//  UserProgress.swift
//  ProjectDelta
//

import Foundation

struct UserProgress: Codable {
    var userId: String
    var progress: [String: SubjectProgress] // using String as the key for infinite custom subjects
    var answeredQuestions: [String: Bool]? // QuestionID as key, Bool for correct/incorrect
    var questionsAttempted: Int
    
    // Define the coding keys that correspond to the properties
    enum CodingKeys: String, CodingKey {
        case userId
        case progress
        case answeredQuestions
        case questionsAttempted
    }
    
    // Custom initializer for decoding from a decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        questionsAttempted = try container.decode(Int.self, forKey: .questionsAttempted)
        answeredQuestions = try container.decodeIfPresent([String: Bool].self, forKey: .answeredQuestions)
        
        let progressContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .progress)
        var tempProgress = [String: SubjectProgress]()
        
        for key in progressContainer.allKeys {
            // Dynamically accepts ANY subject string from Firestore
            let subjectProgress = try progressContainer.decode(SubjectProgress.self, forKey: key)
            tempProgress[key.stringValue] = subjectProgress
        }
        progress = tempProgress
    }
    
    // Custom initializer for creating a new instance manually
    init(userId: String) {
        self.userId = userId
        self.progress = [:] // Starts empty, fills dynamically as tests are taken
        self.answeredQuestions = [:]
        self.questionsAttempted = 0
    }
    
    // Encode function to encode the instance to an encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(questionsAttempted, forKey: .questionsAttempted)
        try container.encodeIfPresent(answeredQuestions, forKey: .answeredQuestions)
        
        var progressContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .progress)
        for (key, value) in progress {
            try progressContainer.encode(value, forKey: DynamicCodingKeys(stringValue: key)!)
        }
    }
    
    // DynamicCodingKeys to handle the keys of the 'progress' dictionary
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }
}

struct SubjectProgress: Codable {
    var questionsAttempted: Int
    var questionsCorrect: Int
}
