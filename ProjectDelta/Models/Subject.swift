//
//  Subject.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

import Foundation
import Firebase
import FirebaseFirestore

struct Subject: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var difficulty: Int
    var subjectArea: SubjectArea
    var imageName: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, difficulty, subjectArea, imageName
    }
    
    init(id: String? = nil, name: String, description: String, difficulty: Int, subjectArea: SubjectArea, imageName: String) {
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.subjectArea = subjectArea
        self.imageName = imageName
    }
    
    // Custom decoder allows legacy documents lacking newer fields to decode flawlessly
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID<String>(wrappedValue: nil)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 1
        
        // Graceful fallback to the original string name if the strict enum is missing
        if let decodedArea = try? container.decode(SubjectArea.self, forKey: .subjectArea) {
            self.subjectArea = decodedArea
        } else {
            self.subjectArea = SubjectArea(rawValue: self.name) ?? .algebra
        }
        
        // Default to your standard "folder" icon if the image field is absent
        self.imageName = try container.decodeIfPresent(String.self, forKey: .imageName) ?? "folder"
    }
}

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
