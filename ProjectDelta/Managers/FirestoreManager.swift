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
                hint: "Placeholder Hint"
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
    
    // Function to initialize or update the user's progress for a subject
    func updateUserProgress(userId: String, subjectId: String, questionId: String, isCorrect: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let userProgressRef = db.collection("UserProgress").document(userId)
        let subjectProgressRef = userProgressRef.collection("Subjects").document(subjectId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let subjectProgressDocument: DocumentSnapshot
            do {
                try subjectProgressDocument = transaction.getDocument(subjectProgressRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let newProgress: SubjectProgress
            if let existingData = subjectProgressDocument.data() {
                let currentCorrect = existingData["questionsCorrect"] as? Int ?? 0
                let currentAttempted = existingData["questionsAttempted"] as? Int ?? 0
                newProgress = SubjectProgress(
                    questionsAttempted: currentAttempted + 1,
                    questionsCorrect: isCorrect ? currentCorrect + 1 : currentCorrect
                )
            } else {
                newProgress = SubjectProgress(
                    questionsAttempted: 1,
                    questionsCorrect: isCorrect ? 1 : 0
                )
            }
            
            // Convert newProgress to a dictionary using Firestore.Encoder
            do {
                let data = try Firestore.Encoder().encode(newProgress)
                transaction.setData(data, forDocument: subjectProgressRef)
            } catch let encodeError as NSError {
                errorPointer?.pointee = encodeError
                return nil
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
                completion(.failure(error))
            } else {
                print("Transaction successfully committed!")
                completion(.success(()))
            }
        }
    }
}

