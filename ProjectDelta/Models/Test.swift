//
//  Test.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/14/23.
//

import Foundation
import FirebaseFirestore

struct Test: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var questionAmount: Int
    var subject: String
    var testIdentifier: Int
    var timeLimit: Int
    var subtopic: String? // Added to resolve the missing member error
    
    // Explicit initializer to handle the new subtopic field and ensure smooth Codable operations
    init(id: String? = nil, questionAmount: Int, subject: String, testIdentifier: Int, timeLimit: Int, subtopic: String? = nil) {
        self.id = id
        self.questionAmount = questionAmount
        self.subject = subject
        self.testIdentifier = testIdentifier
        self.timeLimit = timeLimit
        self.subtopic = subtopic
    }
}

struct PracticeTest: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var questionAmount: Int
    var timeLimit: Int
    var lessonID: String // Ties the practice test to its parent lesson document ID
    var questions: [String]
    var answers: [String]
}
