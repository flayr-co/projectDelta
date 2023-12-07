//
//  User.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/21/23.
//

// User.swift
import Foundation

struct User: Identifiable, Hashable, Codable {
    let id: String
    let fullname: String
    let email: String
    var points: Int = 0
    var pointsHistory: [String: Int] = [:]
    var profilePictureUrl: String?
    
    var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: fullname) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        
        return ""
    }
}

extension User {
    static var MOCK_USERS: [User] = [
        .init(id: NSUUID().uuidString, fullname: "Donna Henderson", email: "donna@icloud.com", points: 0)
    ]
}
