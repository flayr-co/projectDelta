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
}
