//
//  Lesson.swift
//  ProjectDelta
//

import Foundation
import Firebase
import FirebaseFirestore

struct Lesson: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var completed: Bool
    var lessonNumber: Int
    var pages: [Page]?
}

struct Page: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var content: String
    var pageNumber: Int
    var readyButtonDisplayed: Bool
    var example: String?
    var explanation: String?
    var graphics: String?
    var graphData: GraphData?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case pageNumber
        case readyButtonDisplayed
        case example
        case explanation
        case graphics
        case graphData
    }
    
    init(id: String? = nil, content: String, pageNumber: Int, readyButtonDisplayed: Bool, example: String? = nil, explanation: String? = nil, graphics: String? = nil, graphData: GraphData? = nil) {
        self.id = id
        self.content = content
        self.pageNumber = pageNumber
        self.readyButtonDisplayed = readyButtonDisplayed
        self.example = example
        self.explanation = explanation
        self.graphics = graphics
        self.graphData = graphData
    }
}

extension Lesson: Hashable {
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
