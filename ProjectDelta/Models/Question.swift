//
//  Question.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/17/23.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore

struct Question: Identifiable, Codable {
    @DocumentID var id: String?
    var correctOptionIndex: Int
    var options: [String]
    var points: Int
    var questionText: String
    var type: String
    var subject: String
    var subtopic: String?
    var hint: String?
    var feedback: String?
    var testId: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "correctOptionIndex": correctOptionIndex,
            "options": options,
            "points": points,
            "questionText": questionText,
            "type": type,
            "subject": subject
        ]

        if let subtopic = subtopic {
            dict["subtopic"] = subtopic
        }
        
        if let hint = hint {
            dict["hint"] = hint
        }
        
        if let feedback = feedback {
            dict["feedback"] = feedback
        }
        
        if let testId = testId {
            dict["testId"] = testId
        }
        
        return dict
    }
}

// MARK: - Block Editor Models & Extensions
// Centralized to prevent module-wide redeclaration errors.

enum QuestionBlockType: String, CaseIterable {
    case text = "Text"
    case math = "Equation"
    case graph = "Graph"
}

enum QuestionGraphType: String, CaseIterable {
    case equation = "Function (y = f(x))"
    case points = "Points Data"
}

struct QuestionBlockModel: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: String
    var content: String
    var graphType: String?
}

extension Question {
    var parsedBlocks: [QuestionBlockModel] {
        if let data = questionText.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([QuestionBlockModel].self, from: data) {
            return decoded
        }
        if questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return [QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: questionText)]
    }
    
    mutating func updateWith(blocks: [QuestionBlockModel]) {
        if let data = try? JSONEncoder().encode(blocks),
           let jsonString = String(data: data, encoding: .utf8) {
            self.questionText = jsonString
        } else {
            self.questionText = blocks.map { $0.content }.joined(separator: "\n")
        }
    }
}

// MARK: - Wrapper to Prevent SwiftUI Index Crashes
/// Wraps a Question with a strict local UUID to allow perfectly safe deletions and ForEach iterations.
struct QuestionWrapper: Identifiable {
    let id = UUID()
    var question: Question
}
