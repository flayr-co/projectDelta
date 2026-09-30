//
//  QuestionNote.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/16/26.
//


import Foundation
import FirebaseFirestore

struct QuestionNote: Identifiable, Codable {
    @DocumentID var id: String? // Matches the specific Question ID
    var content: String // The JSON string exported from MathScratchpadViewModel
    var subject: String
    var subtopic: String
    var lastEdited: Date
}