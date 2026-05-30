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
    var subtopic: String?
    var title: String
    var createdAt: Timestamp?
    
    init(id: String? = nil,
         questionAmount: Int,
         subject: String,
         testIdentifier: Int,
         timeLimit: Int,
         subtopic: String? = nil,
         title: String = "",
         createdAt: Timestamp? = nil) {
        self.id = id
        self.questionAmount = questionAmount
        self.subject = subject
        self.testIdentifier = testIdentifier
        self.timeLimit = timeLimit
        self.subtopic = subtopic
        self.title = title
        self.createdAt = createdAt
    }
}

struct PracticeTest: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var questionAmount: Int
    var timeLimit: Int
    var lessonID: String
    var questions: [String]
    var answers: [String]
}
