//
//  Question.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/17/23.
//

// Question.swift
import Foundation
import SwiftUI
import Firebase
import FirebaseFirestoreSwift

struct Question: Identifiable, Codable {
    @DocumentID var id: String?
    var correctOptionIndex: Int
    var options: [String]
    var points: Int
    var questionText: String
    var type: String
    var subject: String
    var hint: String
    var hasUserAnswered: Bool
    var hasUserAnsweredCorrectly: Bool
    
    // Computed property to convert Question to dictionary
    var dictionary: [String: Any] {
        return [
            "correctOptionIndex": correctOptionIndex,
            "options": options,
            "points": points,
            "questionText": questionText,
            "subject": subject,
            "type": type,
            "hint": hint,
            "hasUserAnswered": hasUserAnswered,
            "hasUserAnsweredCorrectly": hasUserAnsweredCorrectly
        ]
    }
}
