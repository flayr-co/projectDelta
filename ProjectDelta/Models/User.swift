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
    var bookmarks: [Bookmark]?
    
    var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: fullname) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        
        return ""
    }
}

struct Bookmark: Codable, Hashable {
    var subjectId: String
    var lessonId: String
    var pageId: String
}

extension User {
    static var MOCK_USERS: [User] = {
        var donna = User(id: NSUUID().uuidString, fullname: "Donna Henderson", email: "donna@icloud.com", points: 100) // Assuming Donna starts with 100 points.
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        
        // Generate points history for the last 7 days with non-zero values
        for dayOffset in -6...0 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                let dateKey = dateFormatter.string(from: date)
                donna.pointsHistory[dateKey] = Int.random(in: 1...100) // Random points for each day
            }
        }
        
        // Donna's current points should be the sum of all points history plus starting points.
        donna.points = donna.pointsHistory.values.reduce(0, +) + 100
        
        return [donna]
    }()
}



