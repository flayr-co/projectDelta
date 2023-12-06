//
//  Test.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/14/23.
//

// Test.swift
import Foundation
import FirebaseFirestoreSwift

struct Test: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var questionAmount: Int
    var subject: String
    var testIdentifier: Int
    var timeLimit: Int
}
