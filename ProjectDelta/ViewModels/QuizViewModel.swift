//
//  QuizViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

import Foundation
import FirebaseFirestore
import Observation
import SwiftUI

@MainActor
@Observable
class QuizViewModel {
    var questions: [Question] = []
    var currentSubject: Subject?
    var currentQuestionDocId: String?
    var userProgress: UserProgress?
    var testsForSelectedSubject: [Test] = []
    
    // Restoring the core curriculum subjects directly to state to guarantee the UI populates instantly
    var subjects: [String] = [
        "Algebra",
        "Advanced Math",
        "Problem Solving & Data Analysis",
        "Geometry & Trigonometry"
    ]
    
    var authViewModel: AuthViewModel
    private let db = Firestore.firestore()

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - Random Test Generation
    func fetchRandomTest(for subjectName: String) {
        Task {
            do {
                self.questions = []
                
                let snapshot = try await db.collection("questions")
                    .whereField("subject", isEqualTo: subjectName)
                    .getDocuments()
                
                let fetchedQuestions = snapshot.documents.compactMap { document -> Question? in
                    try? document.data(as: Question.self)
                }
                
                let shuffledQuestions = fetchedQuestions.shuffled()
                self.questions = Array(shuffledQuestions.prefix(10))
                
                print("Successfully generated \(self.questions.count) random questions for \(subjectName).")
                
            } catch {
                print("Failed to fetch questions for random test: \(error.localizedDescription)")
            }
        }
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        if index < questions.count {
            self.currentQuestionDocId = questions[index].id
        }
    }
    
    func updateUserProgressForSubject(userID: String, subjectArea: SubjectArea, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        // Core implementation to persist to Firebase
    }
}
