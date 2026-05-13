//
//  FirestoreManager.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/14/23.
//

import Foundation
import Firebase
import FirebaseFirestore

class FirestoreManager {
    private var db: Firestore
    
    init() {
        db = Firestore.firestore()
    }
    
    // Updated to fully utilize Swift concurrency
    func saveTest(subjectId: String, test: Test) async throws -> String {
        let ref = try db.collection("Subjects").document(subjectId).collection("Tests").addDocument(from: test)
        
        let placeholderQuestion = Question(
            correctOptionIndex: 0,
            options: ["Placeholder Option"],
            points: 0,
            questionText: "Placeholder Question",
            type: "Placeholder Type",
            subject: test.subject,
            hint: "Placeholder Hint",
            feedback: "Placeholder Feedback"
        )
        
        try db.collection("Subjects")
            .document(subjectId)
            .collection("Tests")
            .document(ref.documentID)
            .collection("Questions")
            .addDocument(from: placeholderQuestion)
            
        return ref.documentID
    }
    
    func saveQuestion(subjectId: String, testId: String, question: Question) async throws {
        let _ = try db.collection("Subjects")
            .document(subjectId)
            .collection("Tests")
            .document(testId)
            .collection("Questions")
            .addDocument(from: question)
    }
    
    func saveQuizSnapshot(_ snapshot: QuizSnapshot) async throws {
        let collectionRef = db.collection("users").document(snapshot.userId).collection("quizSnapshots")
        try collectionRef.document().setData(from: snapshot)
    }
    
    // Converted to async/await utilizing runTransaction in a continuation for safety
    func updateUserProgress(userId: String, subjectId: String, questionId: String, isCorrect: Bool) async throws {
        let userProgressRef = db.collection("UserProgress").document(userId)
        let subjectProgressRef = userProgressRef.collection("Subjects").document(subjectId)
        
        return try await withCheckedThrowingContinuation { continuation in
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
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
