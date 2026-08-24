//
//  PracticeTestViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 6/1/24.
//

import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
class PracticeTestViewModel {
    var questions: [Question] = []
    var currentSubject: Subject?
    var currentQuestionDocId: String?
    var isGeneratingQuiz: Bool = false
    
    // Core Session Tracking State
    var userAnswers: [String: Int] = [:] // Maps Question ID to chosen selection option index
    var isQuizComplete: Bool = false
    var currentSnapshot: QuizSnapshot?
    
    private var db = Firestore.firestore()
    private var authViewModel: AuthViewModel
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    /// Fetches a dynamic lesson practice test, automatically calculating the active 10-quiz rotation sequence.
    func fetchPracticeTest(for lessonID: String, practiceTestID: String, subjectName: String) async {
        self.isGeneratingQuiz = true
        self.questions = []
        self.userAnswers = [:]
        self.isQuizComplete = false
        self.currentSnapshot = nil
        
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            
            if let subjectDoc = subjectQuery.documents.first {
                let subjectID = subjectDoc.documentID
                let lessonDoc = try await db.collection("Subjects").document(subjectID).collection("Lessons").document(lessonID).getDocument()
                let lessonName = lessonDoc.data()?["name"] as? String ?? ""
                
                await fetchPracticeTestCore(for: lessonID, practiceTestID: subjectID, subjectID: subjectID, subjectName: subjectName, lessonName: lessonName)
            } else {
                self.isGeneratingQuiz = false
            }
        } catch {
            print("Error mapping lesson contextual fields for practice tests: \(error.localizedDescription)")
            self.isGeneratingQuiz = false
        }
    }
    
    private func fetchPracticeTestCore(for lessonID: String, practiceTestID: String, subjectID: String, subjectName: String, lessonName: String) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Determine total historic completions to step loop forward sequentially
            let snapshotQuery = db.collection("quizSnapshots")
                .whereField("userId", isEqualTo: userId)
                .whereField("subjectId", isEqualTo: subjectName)
                .whereField("subtopic", isEqualTo: lessonName)
            
            let countSnap = try await snapshotQuery.count.getAggregation(source: .server)
            let attemptCount = countSnap.count.intValue
            
            // Strategy A: Evaluate specific Subject Tests explicitly built in Admin panel
            let testsSnap = try await db.collection("Subjects")
                .document(subjectID)
                .collection("Tests")
                .whereField("subtopic", isEqualTo: lessonName)
                .getDocuments()
            
            if !testsSnap.documents.isEmpty {
                let sortedTests = testsSnap.documents.sorted { $0.documentID < $1.documentID }
                let testIndex = attemptCount % sortedTests.count
                let selectedTestDoc = sortedTests[testIndex]
                
                let questionsSnap = try await selectedTestDoc.reference.collection("Questions").getDocuments()
                var fetched = questionsSnap.documents.compactMap { try? $0.data(as: Question.self) }
                
                if fetched.isEmpty {
                    if let questionIDs = selectedTestDoc.data()["questions"] as? [String], !questionIDs.isEmpty {
                        for qID in questionIDs {
                            if let qDoc = try? await db.collection("questions").document(qID).getDocument(),
                               let question = try? qDoc.data(as: Question.self) {
                                fetched.append(question)
                            }
                        }
                    }
                }
                
                for i in 0..<fetched.count {
                    if fetched[i].id == nil || fetched[i].id!.isEmpty {
                        fetched[i].id = UUID().uuidString
                    }
                }
                
                self.questions = fetched
            } else {
                // Strategy B: General Subject Question-Pool slicing fallback (Guarantees 10 unique iterations)
                let questionsQuery = db.collection("questions")
                    .whereField("subject", isEqualTo: subjectName)
                
                let qSnapshot = try await questionsQuery.getDocuments()
                let allQuestions = qSnapshot.documents.compactMap { try? $0.data(as: Question.self) }
                
                let filtered = allQuestions.filter {
                    $0.subtopic?.lowercased() == lessonName.lowercased() ||
                    $0.feedback?.lowercased().contains(lessonName.lowercased()) == true
                }
                
                let sourcePool = filtered.isEmpty ? allQuestions : filtered
                let sortedPool = sourcePool.sorted { ($0.id ?? "") < ($1.id ?? "") }
                
                if !sortedPool.isEmpty {
                    let rotationOffset = attemptCount % 10
                    var uniqueBatch: [Question] = []
                    
                    for i in 0..<min(10, sortedPool.count) {
                        let targetIndex = (rotationOffset * 3 + i) % sortedPool.count
                        let selectedQ = sortedPool[targetIndex]
                        if !uniqueBatch.contains(where: { $0.id == selectedQ.id }) {
                            uniqueBatch.append(selectedQ)
                        }
                    }
                    
                    if uniqueBatch.isEmpty {
                        uniqueBatch = Array(sortedPool.prefix(10))
                    }
                    
                    for i in 0..<uniqueBatch.count {
                        if uniqueBatch[i].id == nil || uniqueBatch[i].id!.isEmpty {
                            uniqueBatch[i].id = UUID().uuidString
                        }
                    }
                    
                    self.questions = uniqueBatch
                }
            }
        } catch {
            print("Error iterating unique lesson test sequence: \(error.localizedDescription)")
        }
        self.isGeneratingQuiz = false
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        if index < questions.count {
            currentQuestionDocId = questions[index].id
        }
    }
    
    /// Commits exam metrics to historic ledger archives and securely updates overall UserProgress.
    func finishPracticeTest(subjectName: String, lessonName: String) async {
        guard let userId = authViewModel.currentUser?.id, !questions.isEmpty else { return }
        
        var correctCount = 0
        var results: [QuestionResult] = []
        
        for question in questions {
            let questionId = question.id ?? ""
            let selectedIndex = userAnswers[questionId]
            let isCorrect = (selectedIndex == question.correctOptionIndex)
            
            if isCorrect {
                correctCount += 1
            }
            
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
            subjectId: subjectName,
            subtopic: lessonName,
            score: correctCount,
            totalQuestions: questions.count,
            dateTaken: Date(),
            questionResults: results
        )
        
        self.currentSnapshot = snapshot
        
        do {
            try db.collection("quizSnapshots").document(snapshot.id ?? UUID().uuidString).setData(from: snapshot)
        } catch {
            print("Failed to store snapshot: \(error.localizedDescription)")
        }
        
        // Transactional Progress Commitment Execution Block
        let subjectKey = subjectName
        
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
                var subjectData = progressDict[subjectKey] ?? ["questionsAttempted": 0, "questionsCorrect": 0]
                
                let subAttempted = (subjectData["questionsAttempted"] as? Int ?? 0) + self.questions.count
                let subCorrect = (subjectData["questionsCorrect"] as? Int ?? 0) + correctCount
                
                subjectData["questionsAttempted"] = subAttempted
                subjectData["questionsCorrect"] = subCorrect
                progressDict[subjectKey] = subjectData
                
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
        
        self.isQuizComplete = true
    }
    
    func updateUserProgressForSubject(userID: String, subjectName: String, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        // Handled dynamically within the unified transactional atomic block in finishPracticeTest
    }
}
