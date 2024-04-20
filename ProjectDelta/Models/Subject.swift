//
//  Subject.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

// Subject.swift
import Foundation
import Firebase
import FirebaseFirestoreSwift

struct Subject: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var difficulty: Int
    var subjectArea: String // where we determine which of the SAT Subject Areas the Subject belongs to -- Algebra, Advanced Math, Problem Solving and Data Analysis, Geometry and Trigonometry
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


