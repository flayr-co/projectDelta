//
//  AuthViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/21/23.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Observation
import UIKit

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
@Observable
class AuthViewModel {
    var userSession: FirebaseAuth.User?
    var currentUser: User?
    
    private var db = Firestore.firestore()
    
    init() {
        self.userSession = Auth.auth().currentUser
        Task {
            await fetchUser()
        }
    }
        
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
        } catch {
            print("Failed to sign in with error \(error.localizedDescription)")
        }
    }
    
    func createUser(withEmail email: String, password: String, fullname: String, role: UserRole) async throws {
        print("User created with email \(email)")
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            let user = User(id: result.user.uid, fullname: fullname, email: email, role: role)
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(user.id!).setData(encodedUser)
            await fetchUser()
        } catch {
            print("Failed to create user with error: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("Failed to sign out with error \(error.localizedDescription)")
        }
    }
    
    func deleteUser() {
        // Implementation for deleting user
    }
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            self.currentUser = try? snapshot.data(as: User.self)
        } catch {
            print("Error fetching user: \(error)")
        }
    }
        
    func fetchUserProgress(forUserID userId: String) async throws -> UserProgress? {
        let userProgressRef = db.collection("UserProgress").document(userId)
        let snapshot = try await userProgressRef.getDocument()
        return try snapshot.data(as: UserProgress.self)
    }

    func uploadProfileImage(_ image: UIImage, for user: User) async {
        guard let userId = user.id else { return }
        
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        let storageRef = Storage.storage().reference().child("profile_images/\(userId).jpg")
        
        do {
            let _ = try await storageRef.putDataAsync(imageData, metadata: nil)
            let url = try await storageRef.downloadURL()
            await updateUserProfilePictureUrl(url.absoluteString, for: user)
        } catch {
            print("Error uploading image: \(error)")
        }
    }

    private func updateUserProfilePictureUrl(_ url: String, for user: User) async {
        guard let userId = user.id else { return }
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            try await userRef.updateData(["profilePictureUrl": url])
            self.currentUser?.profilePictureUrl = url
        } catch {
            print("Error updating user profile picture URL: \(error)")
        }
    }

    /// Updates user metadata and role, reflecting changes immediately in the UI.
    func updateUserDetails(email: String, fullname: String, role: UserRole) async {
        guard var user = currentUser, let userId = user.id else { return }
        
        user.email = email
        user.fullname = fullname
        user.role = role
        
        do {
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(userId).setData(encodedUser)
            // Update the observable state to trigger UI refreshes
            self.currentUser = user
        } catch {
            print("Error updating user details: \(error.localizedDescription)")
        }
    }
    
    func createUserProgress(userId: String) async throws {
        let userProgressRef = db.collection("UserProgress").document(userId)
        
        let newUserProgress = UserProgress(userId: userId)
        let progressData: [String: Any] = newUserProgress.progress.reduce(into: [:]) { result, entry in
            result[entry.key.rawValue] = [
                "questionsAttempted": entry.value.questionsAttempted,
                "questionsCorrect": entry.value.questionsCorrect
            ]
        }
        
        let firestoreProgressData: [String: Any] = [
            "userId": userId,
            "progress": progressData,
            "answeredQuestions": newUserProgress.answeredQuestions ?? [:],
            "questionsAttempted": newUserProgress.questionsAttempted
        ]
        
        do {
            try await userProgressRef.setData(firestoreProgressData)
            print("User progress successfully created for user ID: \(userId)")
        } catch let error {
            print("Error writing user progress to Firestore: \(error)")
            throw error
        }
    }

    func incrementPoints(by value: Int, on day: String) {
        let updatedPoints = max(0, (currentUser?.points ?? 0) + value)
        currentUser?.points = updatedPoints
        
        let updatedDayPoints = max(0, (currentUser?.pointsHistory[day] ?? 0) + value)
        currentUser?.pointsHistory[day] = updatedDayPoints
    }
    
    func updateUserPointsInFirestore(newPoints: Int) async {
        guard let userId = self.currentUser?.id else { return }
        
        let safePoints = max(0, newPoints)
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            try await userRef.updateData(["points": safePoints])
            await fetchUser()
        } catch {
            print("Error updating user points: \(error.localizedDescription)")
        }
    }

    func storeTodaysPoints(pointsGainedToday: Int) async {
        guard let userId = self.currentUser?.id else {
            print("Error: User ID is nil")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let today = dateFormatter.string(from: Date())
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        let pointsHistoryField = "pointsHistory.\(today)"
        
        do {
            let pointsHistoryUpdate = [pointsHistoryField: FieldValue.increment(Int64(pointsGainedToday))]
            try await userRef.updateData(pointsHistoryUpdate)
            
            let document = try await userRef.getDocument()
            if let updatedPoints = document.data()?["pointsHistory"] as? [String: Int], let todaysPoints = updatedPoints[today] {
                print("Confirmed points for today in Firestore: \(todaysPoints)")
            }
            
            await fetchUser()
        } catch {
            print("Error storing today's points: \(error.localizedDescription)")
        }
    }
    
    func toggleBookmark(subjectId: String, lessonId: String, pageId: String) {
        guard var user = currentUser else {
            print("No current user found")
            return
        }

        if user.bookmarks == nil {
            user.bookmarks = []
        }

        if let index = user.bookmarks!.firstIndex(where: { $0.lessonId == lessonId }) {
            if user.bookmarks![index].pageId == pageId {
                user.bookmarks!.remove(at: index)
                print("Bookmark removed")
            } else {
                user.bookmarks![index].pageId = pageId
                print("Bookmark updated to pageId: \(pageId)")
            }
        } else {
            let newBookmark = Bookmark(subjectId: subjectId, lessonId: lessonId, pageId: pageId)
            user.bookmarks!.append(newBookmark)
            print("New bookmark added: subjectId: \(subjectId), lessonId: \(lessonId), pageId: \(pageId)")
        }

        saveBookmark(user: user)
        currentUser = user
    }

    func clearPreviousBookmark(subjectId: String, lessonId: String) {
        guard var user = currentUser else {
            print("No current user found")
            return
        }
        
        if user.bookmarks == nil {
            user.bookmarks = []
        }
        
        if let index = user.bookmarks?.firstIndex(where: { $0.lessonId == lessonId && $0.subjectId == subjectId }) {
            user.bookmarks?.remove(at: index)
            print("Previous bookmark cleared for lessonId: \(lessonId)")
        } else {
            print("No previous bookmark found for lessonId: \(lessonId)")
        }

        saveBookmark(user: user)
        currentUser = user
    }

    func saveBookmark(user: User) {
        guard let userId = user.id else { return }
        
        do {
            try db.collection("users").document(userId).setData(from: user)
            print("User data saved successfully for user id: \(userId)")
        } catch let error {
            print("Failed to save user: \(error)")
        }
    }

    func isPageBookmarked(subjectId: String, lessonId: String, pageId: String) -> Bool {
        guard let user = currentUser else { return false }
        let isBookmarked = user.bookmarks?.contains(where: {
            $0.subjectId == subjectId && $0.lessonId == lessonId && $0.pageId == pageId
        }) ?? false
        print("isPageBookmarked called for subjectId: \(subjectId), lessonId: \(lessonId), pageId: \(pageId). Result: \(isBookmarked)")
        return isBookmarked
    }
}
