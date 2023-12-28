//
//  UserProgress.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 12/7/23.
//

// UserProgress.swift
import Foundation

struct UserProgress: Codable {
    var userId: String
    var progress: [SubjectArea: SubjectProgress] // using SubjectArea as the key
    var answeredQuestions: [String: Bool]? // QuestionID as key, Bool for correct/incorrect
    var questionsAttempted: Int
    
    // Initialize progress with each subject area starting at 0 attempts and correct answers
    init(userId: String) {
        self.userId = userId
        self.progress = [
            .algebra: SubjectProgress(questionsAttempted: 0, questionsCorrect: 0),
            .advancedMath: SubjectProgress(questionsAttempted: 0, questionsCorrect: 0),
            .problemSolvingDataAnalysis: SubjectProgress(questionsAttempted: 0, questionsCorrect: 0),
            .geometryTrigonometry: SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
        ]
        self.answeredQuestions = [:]
        self.questionsAttempted = 0
    }
}

struct SubjectProgress: Codable {
    var questionsAttempted: Int
    var questionsCorrect: Int
}
