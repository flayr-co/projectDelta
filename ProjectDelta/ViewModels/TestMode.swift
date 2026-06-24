//
//  TestMode.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 6/17/26.
//


//
//  TestMode.swift
//  ProjectDelta
//

import Foundation
import FirebaseFirestore
import Observation
import SwiftUI

enum TestMode: Equatable {
    case timed(subject: String, subtopic: String?)
    case quick(subject: String, subtopic: String?)
    case practice(subject: String, lessonName: String, lessonId: String)
    
    var subjectName: String {
        switch self {
        case .timed(let s, _), .quick(let s, _), .practice(let s, _, _): return s
        }
    }
    
    var subtopicName: String? {
        switch self {
        case .timed(_, let s), .quick(_, let s): return s
        case .practice(_, let l, _): return l
        }
    }
    
    var isTimed: Bool {
        if case .timed = self { return true }
        return false
    }
}

@MainActor
@Observable
class TestSessionViewModel {
    var questions: [Question] = []
    var isGeneratingQuiz: Bool = false
    
    // Snapshot & Evaluation State
    var userAnswers: [String: Int] = [:]
    var isQuizComplete: Bool = false
    var currentSnapshot: QuizSnapshot?
    var userProgress: UserProgress?
    
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
    
    func fetchTest(mode: TestMode) {
        Task {
            self.isGeneratingQuiz = true
            self.questions = []
            self.userAnswers = [:]
            self.isQuizComplete = false
            self.currentSnapshot = nil
            
            do {
                let subjectName = mode.subjectName
                let activeSubtopic = mode.subtopicName
                var fetchedQuestions: [Question] = []
                
                // 1. Primary Architecture Check: Hierarchical Tests
                let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
                if let subjectDoc = subjectQuery.documents.first {
                    var testQuery: Query = subjectDoc.reference.collection("Tests")
                    
                    if let lessonFilter = activeSubtopic {
                        testQuery = testQuery.whereField("subtopic", isEqualTo: lessonFilter)
                    }
                    
                    let testSnapshot = try? await testQuery.getDocuments()
                    let testDocs = testSnapshot?.documents ?? []
                    
                    if !testDocs.isEmpty {
                        // Intelligent Iteration: Stable sort and sequence based on overall attempt count
                        let sortedTestDocs = testDocs.sorted { $0.documentID < $1.documentID }
                        let attemptCount = await fetchAttemptCount(for: subjectName, subtopic: activeSubtopic)
                        let testIndex = attemptCount % sortedTestDocs.count
                        let selectedTestDoc = sortedTestDocs[testIndex]
                        
                        let nestedQuestionsSnapshot = try await selectedTestDoc.reference.collection("Questions").getDocuments()
                        fetchedQuestions = nestedQuestionsSnapshot.documents.compactMap { try? $0.data(as: Question.self) }
                    }
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
                
                // Stable sort to guarantee consistent batching
                fetchedQuestions.sort { ($0.id ?? "") < ($1.id ?? "") }
                
                for i in 0..<fetchedQuestions.count {
                    if fetchedQuestions[i].id == nil || fetchedQuestions[i].id!.isEmpty {
                        fetchedQuestions[i].id = UUID().uuidString
                    }
                }
                
                if fetchedQuestions.isEmpty {
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
                        // Loop back iteration sequentially based on historic counts
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
    
    func finishTest(mode: TestMode) async {
        guard let userId = authViewModel.currentUser?.id, !questions.isEmpty else { return }
        
        var correctCount = 0
        var results: [QuestionResult] = []
        
        for question in questions {
            let questionId = question.id ?? ""
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
            subjectId: mode.subjectName,
            subtopic: mode.subtopicName ?? "All",
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
        
        await applyPointsAndProgress(mode: mode, correctCount: correctCount, results: results)
        self.isQuizComplete = true
    }
    
    private func applyPointsAndProgress(mode: TestMode, correctCount: Int, results: [QuestionResult]) async {
        // Core Practice Modification: Cease point generation or progress calculation for practice sessions
        if case .practice = mode {
            return
        }
        
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Point allocation mechanics
        let totalPointsChange = correctCount * 10 - (questions.count - correctCount) * 5
        await authViewModel.updateUserPointsInFirestore(newPoints: (authViewModel.currentUser?.points ?? 0) + totalPointsChange)
        await authViewModel.storeTodaysPoints(pointsGainedToday: totalPointsChange)
        
        // Progress mechanics
        let area: SubjectArea
        let lower = mode.subjectName.lowercased()
        if lower.contains("algebra") { area = .algebra }
        else if lower.contains("advanced") { area = .advancedMath }
        else if lower.contains("problem") || lower.contains("data") { area = .problemSolvingDataAnalysis }
        else { area = .geometryTrigonometry }
        
        let userProgressRef = db.collection("UserProgress").document(userId)
        
        do {
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let docSnapshot: DocumentSnapshot
                do {
                    docSnapshot = try transaction.getDocument(userProgressRef)
                } catch {
                    return nil
                }
                
                var totalAttempted = docSnapshot.data()?["questionsAttempted"] as? Int ?? 0
                totalAttempted += self.questions.count
                
                var progressDict = docSnapshot.data()?["progress"] as? [String: [String: Any]] ?? [:]
                var subjectData = progressDict[area.rawValue] ?? ["questionsAttempted": 0, "questionsCorrect": 0]
                
                let subAttempted = (subjectData["questionsAttempted"] as? Int ?? 0) + self.questions.count
                let subCorrect = (subjectData["questionsCorrect"] as? Int ?? 0) + correctCount
                
                subjectData["questionsAttempted"] = subAttempted
                subjectData["questionsCorrect"] = subCorrect
                progressDict[area.rawValue] = subjectData
                
                var answeredMap = docSnapshot.data()?["answeredQuestions"] as? [String: Bool] ?? [:]
                for res in results {
                    answeredMap[res.questionId] = res.isCorrect
                }
                
                transaction.updateData([
                    "questionsAttempted": totalAttempted,
                    "answeredQuestions": answeredMap,
                    "progress": progressDict
                ], forDocument: userProgressRef)
                
                return nil
            }
        } catch {
            print("Transaction error processing progress values: \(error.localizedDescription)")
        }
    }
}
