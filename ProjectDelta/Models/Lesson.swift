//
//  Lesson.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/15/24.
//

import Foundation
import Firebase
import FirebaseFirestore

struct Lesson: Identifiable, Codable { // Changed to Codable for full CRUD
    @DocumentID var id: String?
    var name: String
    var description: String
    var completed: Bool
    var lessonNumber: Int
    var pages: [Page]?
}

struct Page: Codable, Identifiable, Equatable { // Changed to Codable
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.pageNumber = try container.decode(Int.self, forKey: .pageNumber)
        self.readyButtonDisplayed = try container.decode(Bool.self, forKey: .readyButtonDisplayed)
        self.example = try container.decodeIfPresent(String.self, forKey: .example)
        self.explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        self.graphics = try container.decodeIfPresent(String.self, forKey: .graphics)
        self.graphData = try container.decodeIfPresent(GraphData.self, forKey: .graphData)
    }
}

struct GraphData: Codable, Equatable { // Changed to Codable
    var xValues: [Double]
    var yValues: [Double]
    var secondaryYValues: [Double]?
    var inequality: Inequality?
    
    struct Inequality: Codable, Equatable { // Changed to Codable
        var slope: Double
        var intercept: Double
        var shadeAbove: Bool
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
