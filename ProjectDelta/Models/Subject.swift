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
    var subjectArea: SubjectArea // Using the enum for type safety
    var imageName: String // Added to support your Admin logic
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
