//
//  QuizSnapshot.swift
//  ProjectDelta
//
//  Created by Jake Meissner.
//

import Foundation
import FirebaseFirestore

struct QuizSnapshot: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let subjectId: String
    let subtopic: String
    let score: Int
    let totalQuestions: Int
    let dateTaken: Date
    let questionResults: [QuestionResult]
}

struct QuestionResult: Codable, Identifiable {
    var id: String = UUID().uuidString
    let questionId: String
    let questionText: String
    let options: [String]
    let correctOptionIndex: Int
    let userSelectedOptionIndex: Int?
    let isCorrect: Bool
    let feedback: String
}
