//
//  Test.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/14/23.
//

// Test.swift
import Foundation
import FirebaseFirestore

struct Test: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var questionAmount: Int
    var subject: String
    var testIdentifier: Int
    var timeLimit: Int
}

struct PracticeTest: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var questionAmount: Int
    var timeLimit: Int
    var lessonID: String // Ties the practice test to its parent lesson document ID
    var questions: [String]
    var answers: [String]
}
