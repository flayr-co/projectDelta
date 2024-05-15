//
//  AuthViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/21/23.
//

// AuthViewModel.swift
import Foundation
import Firebase
import FirebaseFirestoreSwift
import FirebaseStorage
import FirebaseAuth

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: Firebase.User?
    @Published var currentUser: User?  // Assuming you rename your custom User to AppUser
    
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
    
    func createUser(withEmail email: String, password: String, fullname: String) async throws {
        print("user created with email \(email)")
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            let user = User(id: result.user.uid, fullname: fullname, email: email)
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser) // setting the user document in Firestore
            await fetchUser()
        } catch {
            print("Failed to create user with error: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut() // signs out user on backend
            self.userSession = nil // wipes out user session and takes us back to login screen
            self.currentUser = nil // wipes out current user data model
        } catch {
            print("Failed to sign out with error \(error.localizedDescription)")
        }
    }
    
    func deleteUser() {
        
    }
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            DispatchQueue.main.async { [weak self] in
                self?.currentUser = try? snapshot.data(as: User.self)
            }
        } catch {
            print("Error fetching user: \(error)")
        }
    }
    
    func uploadProfileImage(_ image: UIImage, for user: User) {
        // 1. Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        
        // 2. Create a reference to the Firebase Storage location
        let storageRef = Storage.storage().reference().child("profile_images/\(user.id).jpg")
        
        // 3. Upload the image data
        storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            guard let self = self else { return }
            if let error = error {
                print("Error uploading image: \(error)")
                return
            }
            
            // 4. Retrieve the download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error fetching download URL: \(error)")
                    return
                }
                
                if let url = url {
                    // 5. Update user's profile picture URL in Firestore
                    self.updateUserProfilePictureUrl(url.absoluteString, for: user)
                }
            }
        }
    }
    
    func createUserProgress(userId: String) async throws {
        let userProgressRef = db.collection("UserProgress").document(userId)
        
        // Initialize the new UserProgress struct
        let newUserProgress = UserProgress(userId: userId)
        
        // Manually prepare the data for Firestore, since Firestore doesn't understand Swift enums directly
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
            // Set the data to Firestore
            try await userProgressRef.setData(firestoreProgressData)
            print("User progress successfully created for user ID: \(userId)")
        } catch let error {
            print("Error writing user progress to Firestore: \(error)")
            throw error // Propagate the error up to handle it accordingly
        }
    }

    private func updateUserProfilePictureUrl(_ url: String, for user: User) {
        // Update the Firestore user document with the new URL
        let userRef = Firestore.firestore().collection("users").document(user.id)
        userRef.updateData(["profilePictureUrl": url]) { error in
            if let error = error {
                print("Error updating user profile picture URL: \(error)")
            } else {
                // Optionally, update the currentUser in the app
                DispatchQueue.main.async {
                    self.currentUser?.profilePictureUrl = url
                }
            }
        }
    }
    
    func incrementPoints(by value: Int, on day: String) {
        let updatedPoints = max(0, (currentUser?.points ?? 0) + value)
        currentUser?.points = updatedPoints
        
        // Ensure points history for the day doesn't go below 0
        let updatedDayPoints = max(0, (currentUser?.pointsHistory[day] ?? 0) + value)
        currentUser?.pointsHistory[day] = updatedDayPoints
    }
    
    func updateUserPointsInFirestore(newPoints: Int) async {
        guard let userId = self.currentUser?.id else { return }
        
        // Ensure the new points value doesn't go below 0
        let safePoints = max(0, newPoints)
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            try await userRef.updateData(["points": safePoints])
            await fetchUser() // Re-fetch user to update the UI
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
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // or your specific timezone
        let today = dateFormatter.string(from: Date())
        print("Today's date: \(today)")
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        let pointsHistoryField = "pointsHistory.\(today)"
        print("Updating points for: \(pointsHistoryField) with \(pointsGainedToday) points.")
        
        do {
            let pointsHistoryUpdate = [pointsHistoryField: FieldValue.increment(Int64(pointsGainedToday))]
            try await userRef.updateData(pointsHistoryUpdate)
            print("Firestore should now be updated.")
            
            // Fetch the updated points for today to confirm the update
            let document = try await userRef.getDocument()
            if let updatedPoints = document.data()?["pointsHistory"] as? [String: Int], let todaysPoints = updatedPoints[today] {
                print("Confirmed points for today in Firestore: \(todaysPoints)")
            } else {
                print("Failed to confirm points update in Firestore.")
            }
            
            await fetchUser() // Re-fetch user to update the UI
            print("User should now be fetched with new points data.")
        } catch {
            print("Error storing today's points: \(error.localizedDescription)")
        }
    }
    
    // MARK: - BOOKMARKS
    @MainActor
    func toggleBookmark(subjectId: String, lessonId: String, pageId: String) {
        print("toggleBookmark called with lessonId: \(lessonId) and pageId: \(pageId)")
        
        guard var user = currentUser else {
            print("No current user found")
            return
        }

        // Ensure the bookmarks array is initialized
        if user.bookmarks == nil {
            user.bookmarks = []
        }

        if let index = user.bookmarks!.firstIndex(where: { $0.lessonId == lessonId }) {
            if user.bookmarks![index].pageId == pageId {
                user.bookmarks!.remove(at: index)  // Toggle off
                print("Bookmark removed")
            } else {
                user.bookmarks![index].pageId = pageId  // Update page
                print("Bookmark updated to pageId: \(pageId)")
            }
        } else {
            let newBookmark = Bookmark(subjectId: subjectId, lessonId: lessonId, pageId: pageId)
            user.bookmarks!.append(newBookmark)  // New bookmark
            print("New bookmark added: subjectId: \(subjectId), lessonId: \(lessonId), pageId: \(pageId)")
        }

        // Save the modified bookmarks to the database and update the currentUser
        saveBookmark(user: user)
        currentUser = user  // Ensure the current user state is updated
    }

    @MainActor
    func clearPreviousBookmark(subjectId: String, lessonId: String) {
        print("clearPreviousBookmark called with lessonId: \(lessonId)")
        
        guard var user = currentUser else {
            print("No current user found")
            return
        }
        
        // Ensure the bookmarks array is initialized
        if user.bookmarks == nil {
            user.bookmarks = []
        }
        
        if let index = user.bookmarks?.firstIndex(where: { $0.lessonId == lessonId && $0.subjectId == subjectId }) {
            user.bookmarks?.remove(at: index)
            print("Previous bookmark cleared for lessonId: \(lessonId)")
        } else {
            print("No previous bookmark found for lessonId: \(lessonId)")
        }

        // Save the modified bookmarks to the database and update the currentUser
        saveBookmark(user: user)
        currentUser = user  // Ensure the current user state is updated
    }

    @MainActor
    func saveBookmark(user: User) {
        do {
            try db.collection("users").document(user.id).setData(from: user)
            print("User data saved successfully for user id: \(user.id)")
        } catch let error {
            print("Failed to save user: \(error)")
        }
    }

    @MainActor
    func isPageBookmarked(subjectId: String, lessonId: String, pageId: String) -> Bool {
        guard let user = currentUser else { return false }
        let isBookmarked = user.bookmarks?.contains(where: {
            $0.subjectId == subjectId && $0.lessonId == lessonId && $0.pageId == pageId
        }) ?? false
        print("isPageBookmarked called for subjectId: \(subjectId), lessonId: \(lessonId), pageId: \(pageId). Result: \(isBookmarked)")
        return isBookmarked
    }
}
