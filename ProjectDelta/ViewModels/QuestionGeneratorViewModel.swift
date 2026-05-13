//
//  QuestionGeneratorViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 11/27/23.
//

import Foundation
import FirebaseFirestore
import Observation
import SwiftUI

@MainActor
@Observable
class QuestionGeneratorViewModel {
    struct SubjectItem {
        var id: String
        var name: String
    }
    
    struct TestItem {
        var id: String
        var name: String
    }

    var subjects: [SubjectItem] = []
    var tests: [TestItem] = []
    var selectedSubjectId: String?
    var selectedTestId: String?
    var generatedQuestion: Question? = nil
    var isApprovalViewPresented: Bool = false
    var isGenerating: Bool = false
    
    private var db = Firestore.firestore()
    private let firestoreManager = FirestoreManager()
    
    // MARK: - Fetch Subjects
    
    func fetchSubjects() async {
        do {
            let querySnapshot = try await db.collection("Subjects").getDocuments()
            self.subjects = querySnapshot.documents.map { document in
                let subjectName = document.data()["name"] as? String ?? "Unknown"
                return SubjectItem(id: document.documentID, name: subjectName)
            }
        } catch {
            print("Error getting subjects: \(error)")
        }
    }

    // MARK: - Fetch Tests for Selected Subject

    func fetchTestsForSubject(subjectId: String) async {
        do {
            let querySnapshot = try await db.collection("Subjects").document(subjectId).collection("Tests").getDocuments()
            self.tests = querySnapshot.documents.map { document in
                let testIdentifier = document.data()["testIdentifier"] as? Int ?? 0
                return TestItem(id: document.documentID, name: "\(testIdentifier)")
            }
        } catch {
            print("Error getting tests: \(error)")
        }
    }

    private func fetchTestsForSubjectInternal(subjectID: String) async {
        do {
            let querySnapshot = try await db.collection("Subjects").document(subjectID).collection("Tests").getDocuments()
            self.tests = querySnapshot.documents.map { document in
                let testName = document.data()["name"] as? String ?? "Unknown"
                return TestItem(id: document.documentID, name: testName)
            }
        } catch {
            print("Error getting tests: \(error)")
        }
    }
    
    // MARK: - Question Generation
    
    func generateStrictQuestions(for subject: String, subtopic: String, count: Int = 1) async {
        self.isGenerating = true
        defer { self.isGenerating = false }
        
        let systemPrompt = """
        You are an elite mathematics and educational assessment generator. Your task is to generate \(count) multiple-choice questions for the subject '\(subject)' and subtopic '\(subtopic)'.

        CRITICAL REQUIREMENTS:
        1. Relevance & Rigor: Questions must strictly align with the subtopic and reflect standard testing difficulty.
        2. Absolute Accuracy: The correct answer must be mathematically infallible and thoroughly verified.
        3. High-Quality Distractors: You MUST provide exactly 4 options. The 3 incorrect options (distractors) MUST be highly plausible and based on common student errors (e.g., sign errors, misapplied formulas, partial completion of the problem, or order of operations mistakes). Do not provide obvious, nonsensical, or joke answers under any circumstances.
        4. Feedback & Rationale: Provide a detailed, step-by-step mathematical explanation proving the correct answer and explaining why the common pitfalls leading to the distractors are incorrect.

        Return the result EXCLUSIVELY as a JSON array of objects with the following keys:
        - "questionText": The exact string of the question.
        - "options": An array of 4 strings representing the choices.
        - "correctOptionIndex": The integer index (0-3) of the correct answer in the options array.
        - "feedback": Step-by-step mathematical explanation.
        - "hint": A brief hint to help the user start the problem.
        """
        
        // Execute your LLM network call here passing the systemPrompt.
        // let response = try await NetworkManager.shared.fetchLLMData(prompt: systemPrompt)
        // self.generatedQuestion = try JSONDecoder().decode([Question].self, from: response).first
        // self.isApprovalViewPresented = true
    }
    
    // MARK: - Save Question
    
    func saveQuestion() async {
        guard let question = generatedQuestion,
              let subjectId = selectedSubjectId,
              let testId = selectedTestId else {
            print("Subject or Test is not selected or IDs are empty")
            return
        }
        
        print("Attempting to save question: \(question)")
        
        do {
            try await firestoreManager.saveQuestion(subjectId: subjectId, testId: testId, question: question)
            print("Question added successfully to subjectId: \(subjectId), testId: \(testId)")
            self.generatedQuestion = nil
            self.isApprovalViewPresented = false
        } catch {
            print("Error adding question: \(error.localizedDescription)")
        }
    }
}
