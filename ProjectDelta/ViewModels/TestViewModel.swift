//
//  TestViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/26/23.
//

import Foundation
import Firebase
import FirebaseFirestoreSwift

@MainActor
class TestViewModel: ObservableObject {
    
    // Array of questions
    @Published var questions: [Question] = []
    
    // Current question index
    @Published var currentQuestionIndex: Int = 0
    
    // User's answers
    @Published var userAnswers: [String] = []
    
    // Firestore reference
    private var db = Firestore.firestore()

    init() async {
        await fetchQuestions()
    }
    
    // Fetches the questions from Firestore
    func fetchQuestions() async {
        do {
            let querySnapshot = try await db.collection("questions").getDocuments()
            self.questions = querySnapshot.documents.compactMap { document in
                try? document.data(as: Question.self)
            }
        } catch {
            print("Error fetching questions: \(error.localizedDescription)")
        }
    }
    
    // Move to the next question
    func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            // All questions answered. You might want to handle the completion here.
        }
    }
    
    // Store user's answer
    func storeAnswer(answer: String) {
        if currentQuestionIndex < userAnswers.count {
            userAnswers[currentQuestionIndex] = answer
        } else {
            userAnswers.append(answer)
        }
    }
    
    // Submit answers for evaluation
    func submitAnswers() {
        // Implement your grading logic here or send to a server for evaluation
    }
    
    // Reset the test
    func resetTest() async {
        currentQuestionIndex = 0
        userAnswers = []
        await fetchQuestions()
    }
}

