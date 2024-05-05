//
//  Lesson.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/15/24.
//

import Foundation
import Firebase 
import FirebaseFirestoreSwift

struct Lesson: Identifiable, Decodable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var completed: Bool
    var lessonNumber: Int  // Use a separate property for "Lesson1", "Lesson2", etc.
    var pages: [Page]?
}

struct Page: Decodable, Equatable {
    var id: String
    var content: String
    var pageNumber: Int
    var readyButtonDisplayed: Bool
    var example: String?
    var explanation: String?
    var graphics: String?
}

extension Lesson: Hashable {
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

