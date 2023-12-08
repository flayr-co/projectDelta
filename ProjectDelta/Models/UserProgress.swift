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
    var progress: [String: SubjectProgress] // using SubjectArea as the key
}

struct SubjectProgress: Codable {
    var questionsAttempted: Int
    var questionsCorrect: Int
}
