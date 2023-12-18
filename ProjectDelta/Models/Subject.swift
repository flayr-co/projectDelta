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
    var id: String
    var name: String
    var description: String
    var difficulty: Int
    var subjectArea: String // where we determine which of the SAT Subject Areas the Subject belongs to -- Algebra, Advanced Math, Problem Solving & Data Analysis, Geometry & Trigonometry
}

enum SubjectArea: String, Codable {
    case algebra = "Algebra"
    case advancedMath = "Advanced Math"
    case problemSolvingDataAnalysis = "Problem Solving & Data Analysis"
    case geometryTrigonometry = "Geometry & Trigonometry"
}
