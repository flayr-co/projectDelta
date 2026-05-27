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
    
    func fetchSubjectsFromFirestore() async throws -> [String] {
        let snapshot = try await db.collection("Subjects").getDocuments()
        
        let fetchedNames = snapshot.documents.compactMap { doc -> String? in
            if let name = doc.data()["name"] as? String, !name.isEmpty {
                return name
            }
            if doc.documentID.count == 20 { return nil }
            return doc.documentID
        }
        return Array(Set(fetchedNames)).sorted()
    }
    
    func selectAnswer(for questionId: String, optionIndex: Int) {
        userAnswers[questionId] = optionIndex
    }
    
    /// Comprehensively searches both hierarchical "Tests" structures and flat "questions" structures
    /// while strictly ignoring generic parameter filters like "All" to guarantee query execution.
    func fetchSubtopicTest(for subjectName: String, subtopic: String? = nil) {
        Task {
            self.isGeneratingQuiz = true
            self.questions = []
            self.userAnswers = [:]
            self.isQuizComplete = false
            self.currentSnapshot = nil
            
            do {
                var fetchedQuestions: [Question] = []
                let activeSubtopic = (subtopic != nil && subtopic != "All" && subtopic?.isEmpty == false) ? subtopic : nil
                
                // 1. Primary Architecture Check: Hierarchical Tests
                var testQuery: Query = db.collection("Tests").whereField("subject", isEqualTo: subjectName)
                if let lessonFilter = activeSubtopic {
                    testQuery = testQuery.whereField("lesson", isEqualTo: lessonFilter)
                }
                
                let testSnapshot = try? await testQuery.getDocuments()
                if let firstTestDoc = testSnapshot?.documents.first {
                    // Fetch nested questions from this test specifically
                    let nestedQuestionsSnapshot = try await firstTestDoc.reference.collection("Questions").getDocuments()
                    fetchedQuestions = nestedQuestionsSnapshot.documents.compactMap { try? $0.data(as: Question.self) }
                }
                
                // 2. Secondary Architecture Check: Flat Collection Fallback
                if fetchedQuestions.isEmpty {
                    var query: Query = db.collection("questions").whereField("subject", isEqualTo: subjectName)
                    if let subFilter = activeSubtopic {
                        query = query.whereField("subtopic", isEqualTo: subFilter)
                    }
                    
                    let flatSnapshot = try await query.getDocuments()
                    fetchedQuestions = flatSnapshot.documents.compactMap { try? $0.data(as: Question.self) }
                }
                
                fetchedQuestions.sort { ($0.id ?? "") < ($1.id ?? "") }
                
                if fetchedQuestions.isEmpty {
                    print("No questions found for \(subjectName) - \(subtopic ?? "All"). Checked both hierarchical and flat structures.")
                    self.questions = []
                } else {
                    let attemptCount = await fetchAttemptCount(for: subjectName, subtopic: activeSubtopic)
                    let batchSize = 10
                    var batches: [[Question]] = []
                    
                    for i in stride(from: 0, to: fetchedQuestions.count, by: batchSize) {
                        let end = min(i + batchSize, fetchedQuestions.count)
                        batches.append(Array(fetchedQuestions[i..<end]))
                    }
                    
                    if batches.isEmpty {
                        self.questions = []
                    } else {
                        let batchIndex = attemptCount % batches.count
                        self.questions = batches[batchIndex]
                    }
                }
            } catch {
                print("Firestore Data Error: \(error.localizedDescription)")
            }
            self.isGeneratingQuiz = false
        }
    }
    
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
            return aggregation.count.intValue
        } catch {
            return 0
        }
    }
    
    func finishQuiz(subjectId: String, subtopic: String) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        var correctCount = 0
        var results: [QuestionResult] = []
        
        for question in questions {
            let questionId = question.id ?? UUID().uuidString
            let selectedIndex = userAnswers[questionId]
            let isCorrect = (selectedIndex == question.correctOptionIndex)
            
            if isCorrect { correctCount += 1 }
            
            let result = QuestionResult(
                id: UUID().uuidString,
                questionId: questionId,
                questionText: question.questionText,
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
        
        let area: SubjectArea
        let lower = subjectId.lowercased()
        if lower.contains("algebra") { area = .algebra }
        else if lower.contains("advanced") { area = .advancedMath }
        else if lower.contains("problem") || lower.contains("data") { area = .problemSolvingDataAnalysis }
        else { area = .geometryTrigonometry }
        
        if var progressObj = self.userProgress {
            progressObj.questionsAttempted += questions.count
            var subjectProgress = progressObj.progress[area] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
            subjectProgress.questionsAttempted += questions.count
            subjectProgress.questionsCorrect += correctCount
            
            if progressObj.answeredQuestions == nil {
                progressObj.answeredQuestions = [:]
            }
            for res in results {
                progressObj.answeredQuestions?[res.questionId] = res.isCorrect
            }
            
            progressObj.progress[area] = subjectProgress
            self.userProgress = progressObj
            
            let userProgressRef = db.collection("UserProgress").document(userId)
            let progressMapData = progressObj.progress.reduce(into: [String: Any]()) { result, entry in
                result[entry.key.rawValue] = [
                    "questionsAttempted": entry.value.questionsAttempted,
                    "questionsCorrect": entry.value.questionsCorrect
                ]
            }
            
            let firestoreData: [String: Any] = [
                "userId": userId,
                "questionsAttempted": progressObj.questionsAttempted,
                "answeredQuestions": progressObj.answeredQuestions ?? [:],
                "progress": progressMapData
            ]
            
            try? await userProgressRef.setData(firestoreData, merge: true)
        }
        self.isQuizComplete = true
    }
}
