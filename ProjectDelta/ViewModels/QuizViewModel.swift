//
//  QuizViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import Observation
import SwiftUI

@MainActor
@Observable
class QuizViewModel {
    var subjects: [String] = []
    var testsForSelectedSubject: [Test] = []
    var questions: [Question] = []
    var selectedSubjectDocId: String?
    var userProgress: UserProgress?
    var userProgressBySubject: [String: SubjectProgress] = [:]
    var currentSubject: Subject?
    var currentSubjectArea: String?
    var currentQuestionDocId: String?
    var answeredCorrectly = Set<Int>()
    var score = 0
    
    private var db = Firestore.firestore()
    private var authViewModel: AuthViewModel
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - FETCH SUBJECTS

    func fetchSubjectsFromFirestore() async throws -> [String] {
        let subjectsRef = Firestore.firestore().collection("Subjects")
        
        let querySnapshot = try await subjectsRef.getDocuments()
        var fetchedSubjects = [String]()
        
        for document in querySnapshot.documents {
            if let subjectName = document.data()["name"] as? String {
                fetchedSubjects.append(subjectName)
            }
        }
        
        if fetchedSubjects.isEmpty {
            throw NSError(domain: "com.projectdelta.error", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No subjects were fetched from Firestore."])
        }
        
        return fetchedSubjects
    }

    func fetchSubjectArea(for subjectName: String) async throws -> SubjectArea? {
        let subjectsRef = Firestore.firestore().collection("Subjects")
        
        let snapshot = try await subjectsRef.whereField("name", isEqualTo: subjectName).getDocuments()
        guard let document = snapshot.documents.first else {
            print("Subject not found for name: \(subjectName)")
            return nil
        }
        
        let fetchedSubjectName = (document.data()["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "N/A"
        print("Fetched subject name: '\(fetchedSubjectName)'")
        
        guard let subjectArea = SubjectArea(rawValue: fetchedSubjectName) else {
            print("Subject area does not match any known SubjectArea enum case. Fetched subject area: '\(fetchedSubjectName)'")
            return nil
        }
        
        print("Successfully matched subject area to enum case: \(subjectArea.rawValue)")
        return subjectArea
    }
    
    // MARK: - FETCH TESTS

    func fetchRandomTest(for subject: String) {
        Task {
            do {
                let snapshot = try await db.collection("Subjects").whereField("name", isEqualTo: subject).getDocuments()
                if let document = snapshot.documents.first {
                    let subjectDocumentID = document.documentID
                    print("Fetched document ID for subject \(subject): \(subjectDocumentID)")
                    self.selectedSubjectDocId = subjectDocumentID
                    await self.fetchTestsForSubjectID(subjectDocumentID, subjectName: subject)
                } else {
                    print("No document ID found for subject \(subject)")
                }
            } catch {
                print("Error fetching document ID for subject \(subject): \(error)")
            }
        }
    }

    private func fetchTestsForSubjectID(_ subjectID: String, subjectName: String) async {
        do {
            let testsSnapshot = try await db.collection("Subjects").document(subjectID).collection("Tests").getDocuments()
            if !testsSnapshot.isEmpty {
                let tests = testsSnapshot.documents
                print("Fetched \(tests.count) tests for subject: \(subjectName)")
                let randomTest = tests.randomElement()

                if let testDocumentID = randomTest?.documentID {
                    print("Random test document ID for subject \(subjectName): \(testDocumentID)")
                    await self.fetchQuestions(forTestID: testDocumentID, subjectID: subjectID)
                }
            } else {
                print("No tests found for subject: \(subjectName)")
            }
            
            let subjectSnapshot = try await db.collection("Subjects").document(subjectID).getDocument()
            if subjectSnapshot.exists {
                var subject = try subjectSnapshot.data(as: Subject.self)
                subject.id = subjectSnapshot.documentID
                self.currentSubject = subject
                print("Successfully fetched and decoded subject details: \(subject)")
            } else {
                print("Document for subject \(subjectName) does not exist.")
            }
        } catch {
            print("Error fetching tests or subject details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - FETCH QUESTIONS
    
    private func fetchQuestions(forTestID testID: String, subjectID: String) async {
        do {
            let snapshot = try await db.collection("Subjects").document(subjectID).collection("Tests").document(testID).collection("Questions").getDocuments()
            self.questions.removeAll()
            for document in snapshot.documents {
                print("Question document ID: \(document.documentID)")
                var question = try? document.data(as: Question.self)
                if question?.id == nil {
                    question?.id = document.documentID
                }
                if let fetchedQuestion = question {
                    self.questions.append(fetchedQuestion)
                }
            }
            print("Total questions fetched for testID \(testID) and subject \(subjectID): \(self.questions.count)")
        } catch {
            print("Error fetching questions for testID \(testID) and subject \(subjectID): \(error)")
        }
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        guard index >= 0 && index < questions.count else { return }
        self.currentQuestionDocId = self.questions[index].id
    }
    
    func checkAnswerAndUpdateScore(userAnswer: Int?, currentQuestionIndex: Int) {
        if let userAnswer = userAnswer,
           userAnswer == questions[currentQuestionIndex].correctOptionIndex {
            score += 1
        }
    }
    
    // MARK: - FETCH QUESTIONS FOR USER

    func fetchQuestionsForUser(forTestID testID: String, subjectID: String, userID: String) {
        Task {
            do {
                let progressSnapshot = try await db.collection("UserProgress").document(userID).getDocument()
                if let userProgress = try? progressSnapshot.data(as: UserProgress.self) {
                    self.userProgress = userProgress
                } else {
                    print("Error decoding user progress or DocumentSnapshot is nil")
                }

                let snapshot = try await db.collection("Subjects").document(subjectID).collection("Tests").document(testID).collection("Questions").getDocuments()
                self.questions.removeAll()
                
                for document in snapshot.documents {
                    if var question = try? document.data(as: Question.self) {
                        question.id = document.documentID
                        self.questions.append(question)
                    }
                }
            } catch {
                print("Error fetching questions for user: \(error)")
            }
        }
    }
    
    // MARK: - FETCH USER PROGRESS
    
    func fetchUserProgress(forUserID userID: String) async throws -> UserProgress? {
        let userProgressRef = db.collection("UserProgress").document(userID)
        
        do {
            let documentSnapshot = try await userProgressRef.getDocument()
            print("Raw document data: \(documentSnapshot.data() ?? [:])")
            
            guard let userProgress = try? documentSnapshot.data(as: UserProgress.self) else {
                print("Error: User progress data is missing or has an unexpected format.")
                return nil
            }
            return userProgress
        } catch let error as NSError where error.domain == FirestoreErrorDomain {
            print("Firestore error: \(error.localizedDescription), \(error.userInfo)")
        } catch let DecodingError.dataCorrupted(context) {
            print("Decoding error: Data corrupted - \(context.debugDescription)")
        } catch let DecodingError.keyNotFound(key, context) {
            print("Decoding error: Key '\(key.stringValue)' not found - \(context.debugDescription), path: \(context.codingPath)")
        } catch let DecodingError.typeMismatch(type, context) {
            print("Decoding error: Type '\(type)' mismatch - \(context.debugDescription), path: \(context.codingPath)")
        } catch let DecodingError.valueNotFound(value, context) {
            print("Decoding error: Value '\(value)' not found - \(context.debugDescription), path: \(context.codingPath)")
        } catch {
            print("An error occurred: \(error)")
            if let decodingError = error as? DecodingError {
                print(decodingError.localizedDescription)
            }
        }
        return nil
    }
    
    func updateUserProgress(forUserID userID: String, subjectName: String, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        do {
            guard (try await fetchUserProgress(forUserID: userID)) != nil else {
                throw NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "User progress not found."
                ])
            }

            guard let subjectArea = try await fetchSubjectArea(for: subjectName) else {
                throw NSError(domain: "YourErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Subject area not found."])
            }

            try await updateUserProgressForSubject(
                userID: userID,
                subjectArea: subjectArea,
                answeredCorrectly: answeredCorrectly,
                questionDocumentID: questionDocumentID
            )
            
        } catch {
            throw error
        }
    }
    
    // MARK: - UPDATE USER PROGRESS FOR SAT MATH SUBJECT AREA
    func updateUserProgressForSubject(userID: String, subjectArea: SubjectArea, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        let userProgressRef = self.db.collection("UserProgress").document(userID)

        let attemptedKey = "progress.\(subjectArea.rawValue).questionsAttempted"
        let correctKey = "progress.\(subjectArea.rawValue).questionsCorrect"
        let answeredQuestionsKey = "answeredQuestions.\(questionDocumentID)"

        var updateData: [String: Any] = [
            attemptedKey: FieldValue.increment(Int64(1))
        ]

        if answeredCorrectly {
            updateData[correctKey] = FieldValue.increment(Int64(1))
        }
        
        updateData[answeredQuestionsKey] = answeredCorrectly

        try await userProgressRef.updateData(updateData)
    }
    
    func handleQuestionAnswered(question: Question, subject: Subject, answeredCorrectly: Bool) async {
        do {
            try await updateUserAnswerForQuestion(questionID: question.id ?? "", answeredCorrectly: answeredCorrectly, question: question, subject: subject)
        } catch {
            print("Error updating answered question: \(error.localizedDescription)")
        }
    }

    func updateUserAnswerForQuestion(questionID: String, answeredCorrectly: Bool, question: Question, subject: Subject) async throws {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AppError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not found"])
        }

        let answeredQuestionsRef = db.collection("UserProgress").document(userID).collection("answeredQuestions").document(questionID)

        let questionData = [
            "hasUserAttempted": true,
            "hasUserAttemptedCorrectly": answeredCorrectly
        ] as [String: Any]

        try await answeredQuestionsRef.setData(questionData)
    }

    func resetUserProgress(userId: String) {
        Task {
            do {
                let userProgressRef = db.collection("UserProgress").document(userId)
                
                let resetData = [
                    "Algebra": ["questionsAttempted": 0, "questionsCorrect": 0],
                    "Advanced Math": ["questionsAttempted": 0, "questionsCorrect": 0],
                    "Problem Solving & Data Analysis": ["questionsAttempted": 0, "questionsCorrect": 0],
                    "Geometry & Trigonometry": ["questionsAttempted": 0, "questionsCorrect": 0]
                ]
                
                try await userProgressRef.updateData(["progress": resetData])
                print("User progress reset successfully.")
            } catch {
                print("Error resetting user progress: \(error.localizedDescription)")
            }
        }
    }
    
    func addDummyDataForUser(userId: String) {
        let dummyProgress = UserProgress(
            userId: userId
        )

        let userProgressRef = db.collection("UserProgress").document(userId)
        do {
            try userProgressRef.setData(from: dummyProgress)
        } catch let error {
            print("Error writing user progress to Firestore: \(error)")
        }
    }
}
