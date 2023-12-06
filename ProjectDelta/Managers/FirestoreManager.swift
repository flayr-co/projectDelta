//
//  FirestoreManager.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/14/23.
//

// FirestoreManger.swift
import Foundation
import Firebase
import FirebaseFirestoreSwift

class FirestoreManager {
    private var db: Firestore
    
    init() {
        db = Firestore.firestore()
    }
    
    // Updated to save a test under a specific subject
    func saveTest(subjectId: String, test: Test, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            let ref = try db.collection("Subjects").document(subjectId).collection("Tests").addDocument(from: test)
            // Add a placeholder question to the new test's Questions subcollection
            let placeholderQuestion = Question(
                correctOptionIndex: 0,
                options: ["Placeholder Option"],
                points: 0,
                questionText: "Placeholder Question",
                type: "Placeholder Type",
                subject: test.subject,
                hint: "Placeholder Hint",
                hasUserAnswered: false,
                hasUserAnsweredCorrectly: false
            )
            try db.collection("Subjects")
                   .document(subjectId)
                   .collection("Tests")
                   .document(ref.documentID)
                   .collection("Questions")
                   .addDocument(from: placeholderQuestion)
            
            completion(.success(ref.documentID))
        } catch let error {
            completion(.failure(error))
        }
    }
    
    func saveQuestion(subjectId: String, testId: String, question: Question, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let _ = try db.collection("Subjects").document(subjectId).collection("Tests").document(testId).collection("Questions").addDocument(from: question)
            completion(.success(()))
        } catch let error {
            completion(.failure(error))
        }
    }
}

