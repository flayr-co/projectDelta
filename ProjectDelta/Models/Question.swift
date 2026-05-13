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
import FirebaseFirestore

struct Question: Identifiable, Codable {
    @DocumentID var id: String?
    var correctOptionIndex: Int
    var options: [String]
    var points: Int
    var questionText: String
    var type: String
    var subject: String
    var hint: String?
    var feedback: String?

    // Computed property to convert Question to dictionary
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "correctOptionIndex": correctOptionIndex,
            "options": options,
            "points": points,
            "questionText": questionText,
            "type": type,
            "subject": subject
        ]

        if let hint = hint {
            dict["hint"] = hint
        }
        
        if let feedback = feedback {
            dict["feedback"] = feedback
        }
        
        return dict
    }
}
