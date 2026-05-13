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
    
    /// The powerhouse of the test system: Fetches 10 random questions filtered by Subject and Subtopic
    func fetchSubtopicTest(for subjectName: String, subtopic: String? = nil) {
        Task {
            self.isGeneratingQuiz = true
            // IMPORTANT: Clear current questions to prevent index out of range crashes during TabView transitions
            self.questions = []
            
            do {
                var query: Query = db.collection("questions").whereField("subject", isEqualTo: subjectName)
                
                if let subtopic = subtopic, !subtopic.isEmpty {
                    query = query.whereField("subtopic", isEqualTo: subtopic)
                }
                
                let snapshot = try await query.getDocuments()
                let fetchedQuestions = snapshot.documents.compactMap { document -> Question? in
                    try? document.data(as: Question.self)
                }
                
                if fetchedQuestions.isEmpty {
                    print("No questions found for \(subjectName) - \(subtopic ?? "All"). Using fallback data.")
                    self.questions = generateMockQuestions(for: subjectName)
                } else {
                    self.questions = Array(fetchedQuestions.shuffled().prefix(10))
                }
                
            } catch {
                print("Firestore Error: \(error.localizedDescription)")
                self.questions = generateMockQuestions(for: subjectName)
            }
            
            self.isGeneratingQuiz = false
        }
    }
    
    func finishQuiz(score: Int) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Logical Point System: 10 per correct answer.
        // Syncs to UserProgress which HomeView observes.
        let pointsGained = score * 10
        let currentPoints = authViewModel.currentUser?.points ?? 0
        let newTotal = currentPoints + pointsGained
        
        await authViewModel.updateUserPointsInFirestore(newPoints: newTotal)
        await authViewModel.storeTodaysPoints(pointsGainedToday: pointsGained)
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        if index >= 0 && index < questions.count {
            self.currentQuestionDocId = questions[index].id
        }
    }
    
    func updateUserProgressForSubject(userID: String, subjectArea: SubjectArea, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        let userProgressRef = db.collection("user_progress").document(userID)
        let subjectKey = subjectArea.rawValue
        
        let updateData: [String: Any] = [
            "subjects.\(subjectKey).questionsAttempted": FieldValue.increment(Int64(1)),
            "subjects.\(subjectKey).questionsCorrect": answeredCorrectly ? FieldValue.increment(Int64(1)) : FieldValue.increment(Int64(0)),
            "lastAttempted": Timestamp(date: Date())
        ]
        
        try await userProgressRef.updateData(updateData)
    }
    
    private func generateMockQuestions(for subject: String) -> [Question] {
        return [
            Question(id: UUID().uuidString, correctOptionIndex: 1, options: ["Option A", "Option B", "Option C", "Option D"], points: 10, questionText: "Calculated \(subject) Question: Solve for x if 2x + 5 = 15.", type: "multipleChoice", subject: subject, hint: "Subtract 5 from both sides first."),
            Question(id: UUID().uuidString, correctOptionIndex: 2, options: ["12", "24", "48", "96"], points: 10, questionText: "Advanced \(subject) Logic: What is the area of a circle with radius 4?", type: "multipleChoice", subject: subject, hint: "Formula is πr²."),
            Question(id: UUID().uuidString, correctOptionIndex: 0, options: ["True", "False"], points: 10, questionText: "Fundamental Theory: Is the square root of 144 equal to 12?", type: "trueFalse", subject: subject, hint: "Multiply 12 by itself.")
        ]
    }
}
