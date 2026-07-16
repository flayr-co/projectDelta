//
//  Subject.swift
//  ProjectDelta
//

import Foundation
import Firebase
import FirebaseFirestore

public enum SubjectArea: String, Codable, Comparable, CaseIterable, Identifiable {
    case algebra = "Algebra"
    case advancedMath = "Advanced Math"
    case problemSolvingDataAnalysis = "Problem Solving and Data Analysis"
    case geometryTrigonometry = "Geometry and Trigonometry"

    public var id: String { self.rawValue }

    public static func < (lhs: SubjectArea, rhs: SubjectArea) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct Subject: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var difficulty: Int
    var subjectArea: SubjectArea
    var imageName: String
    var subtopics: [String]
    var orderIndex: Int
    var lessonCount: Int = 0 // Ephemeral UI property, not pushed to Firestore
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, difficulty, subjectArea, imageName, subtopics, orderIndex
    }
    
    init(id: String? = nil, name: String, description: String, difficulty: Int, subjectArea: SubjectArea, imageName: String, subtopics: [String] = [], orderIndex: Int = 0) {
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.subjectArea = subjectArea
        self.imageName = imageName
        self.subtopics = subtopics
        self.orderIndex = orderIndex
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID<String>(wrappedValue: nil)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 1
        
        if let decodedArea = try? container.decode(SubjectArea.self, forKey: .subjectArea) {
            self.subjectArea = decodedArea
        } else {
            self.subjectArea = SubjectArea(rawValue: self.name) ?? .algebra
        }
        
        self.imageName = try container.decodeIfPresent(String.self, forKey: .imageName) ?? "folder"
        self.subtopics = try container.decodeIfPresent([String].self, forKey: .subtopics) ?? []
        self.orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
    }
    
    // Custom encoder enforces strict database schema by stripping the transient lessonCount
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(subjectArea, forKey: .subjectArea)
        try container.encode(imageName, forKey: .imageName)
        try container.encode(subtopics, forKey: .subtopics)
        try container.encode(orderIndex, forKey: .orderIndex)
    }
}
