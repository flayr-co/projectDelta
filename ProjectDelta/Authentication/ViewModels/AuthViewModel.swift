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
        guard let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument() else { return }
        self.currentUser = try? snapshot.data(as: User.self)
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
    
    func updateUserPointsInFirestore(newPoints: Int) async throws {
        guard let userId = self.currentUser?.id else {
            throw NSError(domain: "YourErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User ID is unavailable."])
        }
        
        // Ensure the new points value doesn't go below 0
        let safePoints = max(0, newPoints)
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            try await userRef.updateData(["points": safePoints])
            print("User points successfully updated.")
        } catch {
            print("Error updating user points: \(error.localizedDescription)")
            throw error
        }
    }
    
    func storeTodaysPoints(pointsGainedToday: Int) async throws {
        guard let userId = self.currentUser?.id else {
            throw NSError(domain: "YourErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User ID is unavailable."])
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        // Update Firestore with today's gained points
        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            let pointsHistoryUpdate = ["pointsHistory.\(today)": FieldValue.increment(Int64(pointsGainedToday))]
            try await userRef.updateData(pointsHistoryUpdate)
            print("Today's points successfully stored.")
        } catch {
            print("Error storing today's points: \(error.localizedDescription)")
            throw error
        }
    }
}
