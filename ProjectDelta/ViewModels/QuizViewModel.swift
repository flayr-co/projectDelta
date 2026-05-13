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
    var isGeneratingQuiz: Bool = false
    
    // Snapshot & Evaluation State
    var userAnswers: [String: Int] = [:] // Maps Question ID to selected option index
    var isQuizComplete: Bool = false
    var currentSnapshot: QuizSnapshot?
    
    var subjects: [String] = [
        "Algebra",
        "Advanced Math",
        "Problem Solving & Data Analysis",
        "Geometry & Trigonometry"
    ]
    
    var authViewModel: AuthViewModel
    private let db = Firestore.firestore()
    private let firestoreManager = FirestoreManager()

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    /// Records the user's selected option index for a specific question.
    func selectAnswer(for questionId: String, optionIndex: Int) {
        userAnswers[questionId] = optionIndex
    }
    
    /// Fetches questions in segmented chunks of 10 and rotates through batches based on user attempts.
    func fetchSubtopicTest(for subjectName: String, subtopic: String? = nil) {
        Task {
            self.isGeneratingQuiz = true
            self.questions = []
            self.userAnswers = [:]
            self.isQuizComplete = false
            self.currentSnapshot = nil
            
            do {
                var query: Query = db.collection("questions").whereField("subject", isEqualTo: subjectName)
                
                if let subtopic = subtopic, !subtopic.isEmpty {
                    query = query.whereField("subtopic", isEqualTo: subtopic)
                }
                
                let snapshot = try await query.getDocuments()
                var fetchedQuestions = snapshot.documents.compactMap { document -> Question? in
                    try? document.data(as: Question.self)
                }
                
                // Sort questions strictly by ID to ensure consistency in batch layout
                fetchedQuestions.sort { ($0.id ?? "") < ($1.id ?? "") }
                
                if fetchedQuestions.isEmpty {
                    print("No questions found for \(subjectName) - \(subtopic ?? "All").")
                    self.questions = []
                } else {
                    let attemptCount = await fetchAttemptCount(for: subjectName, subtopic: subtopic)
                    
                    let batchSize = 10
                    var batches: [[Question]] = []
                    
                    // Slice the fetched array into sub-arrays of size 10
                    for i in stride(from: 0, to: fetchedQuestions.count, by: batchSize) {
                        let end = min(i + batchSize, fetchedQuestions.count)
                        batches.append(Array(fetchedQuestions[i..<end]))
                    }
                    
                    if batches.isEmpty {
                        self.questions = []
                    } else {
                        // Modulo operator continuously loops the user through available batches
                        let batchIndex = attemptCount % batches.count
                        self.questions = batches[batchIndex]
                    }
                }
            } catch {
                print("Firestore Error: \(error.localizedDescription)")
            }
            
            self.isGeneratingQuiz = false
        }
    }
    
    /// Evaluates the user's progression specifically for finding rotating batch intervals
    private func fetchAttemptCount(for subject: String, subtopic: String?) async -> Int {
        guard let userId = authViewModel.currentUser?.id else { return 0 }
        do {
            var query: Query = db.collection("quizSnapshots")
                .whereField("userId", isEqualTo: userId)
                .whereField("subjectId", isEqualTo: subject)
            
            if let subtopic = subtopic, !subtopic.isEmpty {
                query = query.whereField("subtopic", isEqualTo: subtopic)
            }
            
            let aggregation = try await query.count.getAggregation(source: .server)
            return Int(truncating: aggregation.count)
        } catch {
            return 0
        }
    }
    
    /// Evaluates all recorded answers, builds the immutable snapshot, and persists progress.
    func finishQuiz(subjectId: String, subtopic: String) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        var correctCount = 0
        var results: [QuestionResult] = []
        
        for question in questions {
            let questionId = question.id ?? UUID().uuidString
            let selectedIndex = userAnswers[questionId]
            let isCorrect = (selectedIndex == question.correctOptionIndex)
            
            if isCorrect {
                correctCount += 1
            }
            
            let result = QuestionResult(
                id: UUID().uuidString,
                questionId: questionId,
                questionText: question.questionText ?? "",
                options: question.options,
                correctOptionIndex: question.correctOptionIndex,
                userSelectedOptionIndex: selectedIndex,
                isCorrect: isCorrect,
                feedback: question.feedback ?? ""
            )
            results.append(result)
        }
        
        let snapshot = QuizSnapshot(
            id: UUID().uuidString,
            userId: userId,
            subjectId: subjectId,
            subtopic: subtopic,
            score: correctCount,
            totalQuestions: questions.count,
            dateTaken: Date(),
            questionResults: results
        )
        
        self.currentSnapshot = snapshot
        
        do {
            try db.collection("quizSnapshots").document(snapshot.id ?? UUID().uuidString).setData(from: snapshot)
        } catch {
            print("Failed to save snapshot: \(error.localizedDescription)")
        }
        
        self.isQuizComplete = true
    }
}
