//
//  QuestionPoolEngine.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/6/26.
//


//
//  QuestionPoolEngine.swift
//  ProjectDelta
//

import Foundation
import FirebaseFirestore

struct QuestionPoolEngine {
    static let shared = QuestionPoolEngine()
    private let db = Firestore.firestore()
    
    /// Generates an intelligent array of questions prioritizing unseen material.
    func generatePracticeSession(subject: String, subtopic: String, requestedCount: Int, seenIds: Set<String>) async throws -> [Question] {
        // 1. Fetch the entire pool for this specific lesson
        let snapshot = try await db.collection("questions")
            .whereField("subject", isEqualTo: subject)
            .whereField("subtopic", isEqualTo: subtopic)
            .getDocuments()
        
        let allQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
        guard !allQuestions.isEmpty else { return [] }
        
        // 2. Segregate the pool into Unseen and Seen
        var unseenQuestions = allQuestions.filter { !seenIds.contains($0.id ?? "") }
        var seenQuestions = allQuestions.filter { seenIds.contains($0.id ?? "") }
        
        // 3. Shuffle both arrays to maintain randomness
        unseenQuestions.shuffle()
        seenQuestions.shuffle()
        
        var finalSession: [Question] = []
        
        // 4. Fill the session with unseen questions first
        let unseenToTake = min(requestedCount, unseenQuestions.count)
        finalSession.append(contentsOf: unseenQuestions.prefix(unseenToTake))
        
        // 5. If we still need more questions to hit the requested count, cycle back to the seen pool
        let remainingSlots = requestedCount - finalSession.count
        if remainingSlots > 0 {
            let seenToTake = min(remainingSlots, seenQuestions.count)
            finalSession.append(contentsOf: seenQuestions.prefix(seenToTake))
        }
        
        return finalSession
    }
    
    /// Call this when a test is graded to append new IDs to the user's progress profile
    func markQuestionsAsSeen(userId: String, newQuestionIds: [String]) async {
        guard !newQuestionIds.isEmpty else { return }
        
        let userRef = db.collection("Users").document(userId)
        do {
            // FieldValue.arrayUnion ensures no duplicate IDs are ever stored
            try await userRef.updateData([
                "seenQuestionIds": FieldValue.arrayUnion(newQuestionIds)
            ])
        } catch {
            print("Failed to sync seen questions: \(error.localizedDescription)")
        }
    }
}