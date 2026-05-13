//
//  PracticeTestViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 6/1/24.
//

import Foundation
import FirebaseFirestore

@MainActor
class PracticeTestViewModel: ObservableObject {
    @Published var questions: [Question] = []
    @Published var currentSubject: Subject?
    @Published var currentQuestionDocId: String?
    
    private var db = Firestore.firestore()
    private var authViewModel: AuthViewModel
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    func fetchPracticeTest(for lessonID: String, practiceTestID: String) async {
        do {
            let snapshot = try await db.collection("Lessons")
                .document(lessonID)
                .collection("PracticeTests")
                .document(practiceTestID)
                .collection("Questions")
                .getDocuments()
                
            self.questions = snapshot.documents.compactMap { queryDocumentSnapshot -> Question? in
                return try? queryDocumentSnapshot.data(as: Question.self)
            }
        } catch {
            print("Error fetching practice test: \(error.localizedDescription)")
        }
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        if index < questions.count {
            currentQuestionDocId = questions[index].id
        }
    }
    
    func updateUserProgressForSubject(userID: String, subjectArea: SubjectArea, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        // Your implementation for updating user progress
    }
}
