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

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    
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
    
    func incrementPoints(by value: Int, on day: String) {
        currentUser?.points += value
        currentUser?.pointsHistory[day, default: 0] += value
    }
    
    func updateUserPointsInFirestore(newPoints: Int) async throws {
        guard let userId = self.currentUser?.id else {
            throw NSError(domain: "YourErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User ID is unavailable."])
        }
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            try await userRef.updateData(["points": newPoints])
            print("User points successfully updated.")
        } catch {
            print("Error updating user points: \(error.localizedDescription)")
            throw error
        }
    }
    
    func storeTodaysPoints() async throws {
        guard let userId = self.currentUser?.id else {
            throw NSError(domain: "YourErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User ID is unavailable."])
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // ISO 8601 format
        let today = dateFormatter.string(from: Date())
        
        let currentPoints = self.currentUser?.points ?? 0
        self.currentUser?.pointsHistory[today] = currentPoints
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            // Prepare the update for Firestore
            let pointsHistoryUpdate = ["pointsHistory.\(today)": currentPoints]
            try await userRef.updateData(pointsHistoryUpdate)
            print("Today's points successfully stored.")
        } catch {
            print("Error storing today's points: \(error.localizedDescription)")
            throw error
        }
    }
}
