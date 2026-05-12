//
//  QuizViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

// QuizViewModel
import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

class QuizViewModel: ObservableObject {
    @Published var subjects: [String] = []
    @Published var testsForSelectedSubject: [Test] = []
    @Published var questions: [Question] = []
    @Published var selectedSubjectDocId: String?
    @Published var userProgress: UserProgress?
    @Published var userProgressBySubject: [String: SubjectProgress] = [:]
    @Published var currentSubject: Subject?
    @Published var currentSubjectArea: String?
    @Published var currentQuestionDocId: String?
    @Published var answeredCorrectly = Set<Int>()
    @Published var score = 0
    
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
            throw NSError(domain: "com.yourdomain.yourapp", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No subjects were fetched from Firestore."])
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
        db.collection("Subjects").whereField("name", isEqualTo: subject).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching document ID for subject \(subject): \(error)")
            } else if let snapshot = snapshot, let document = snapshot.documents.first {
                let subjectDocumentID = document.documentID
                print("Fetched document ID for subject \(subject): \(subjectDocumentID)")
                
                DispatchQueue.main.async {
                    self.selectedSubjectDocId = subjectDocumentID
                }

                self.fetchTestsForSubjectID(subjectDocumentID, subjectName: subject)
            } else {
                print("No document ID found for subject \(subject)")
            }
        }
    }

    private func fetchTestsForSubjectID(_ subjectID: String, subjectName: String) {
        db.collection("Subjects").document(subjectID).collection("Tests").getDocuments(completion: { (testsSnapshot, error) in
            if let error = error {
                print("Error fetching tests for subject \(subjectName): \(error.localizedDescription)")
            } else if let testsSnapshot = testsSnapshot, !testsSnapshot.isEmpty {
                let tests = testsSnapshot.documents
                print("Fetched \(tests.count) tests for subject: \(subjectName)")
                let randomTest = tests.randomElement()

                if let testDocumentID = randomTest?.documentID {
                    print("Random test document ID for subject \(subjectName): \(testDocumentID)")
                    self.fetchQuestions(forTestID: testDocumentID, subjectID: subjectID)
                }
            } else {
                print("No tests found for subject: \(subjectName)")
            }
        })
        
        db.collection("Subjects").document(subjectID).getDocument { [weak self] (subjectSnapshot, error) in
            if let error = error {
                print("Error fetching subject details: \(error.localizedDescription)")
            } else if let subjectSnapshot = subjectSnapshot, subjectSnapshot.exists {
                do {
                    var subject = try subjectSnapshot.data(as: Subject.self)
                    subject.id = subjectSnapshot.documentID
                    self?.currentSubject = subject
                    print("Successfully fetched and decoded subject details: \(subject)")
                } catch {
                    print("Error decoding subject for \(subjectName): \(error.localizedDescription)")
                }
            } else {
                print("Document for subject \(subjectName) does not exist.")
            }
        }
    }
    
    // MARK: - FETCH QUESTIONS
    
    private func fetchQuestions(forTestID testID: String, subjectID: String) {
        db.collection("Subjects").document(subjectID).collection("Tests").document(testID).collection("Questions").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching questions for testID \(testID) and subject \(subjectID): \(error)")
            } else if let snapshot = snapshot {
                self.questions.removeAll()
                for document in snapshot.documents {
                    print("Question document ID: \(document.documentID)")
                    var question = try? document.data(as: Question.self)
                    print("Fetched Question: \(question?.questionText ?? "N/A"), Options: \(question?.options.joined(separator: ", ") ?? "N/A")")
                    if question?.id == nil {
                        question?.id = document.documentID
                    }
                    if let fetchedQuestion = question {
                        print("Fetched question for testID \(testID) and subject \(subjectID): \(fetchedQuestion)")
                        self.questions.append(fetchedQuestion)
                    }
                }
                print("Total questions fetched for testID \(testID) and subject \(subjectID): \(self.questions.count)")
            }
        }
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        guard index >= 0 && index < questions.count else { return }
        DispatchQueue.main.async {
            self.currentQuestionDocId = self.questions[index].id
        }
    }
    
    func checkAnswerAndUpdateScore(userAnswer: Int?, currentQuestionIndex: Int) {
        if let userAnswer = userAnswer,
           userAnswer == questions[currentQuestionIndex].correctOptionIndex {
            score += 1
        }
    }
    
    // MARK: - FETCH QUESTIONS FOR USER

    func fetchQuestionsForUser(forTestID testID: String, subjectID: String, userID: String) {
        self.db.collection("UserProgress").document(userID).getDocument { (progressSnapshot, error) in
            if let error = error {
                print("Error fetching user progress: \(error)")
                return
            }

            guard let progressSnapshot = progressSnapshot else {
                print("Error: DocumentSnapshot is nil or couldn't retrieve data")
                return
            }

            guard let userProgress = try? progressSnapshot.data(as: UserProgress.self) else {
                print("Error decoding user progress")
                return
            }

            DispatchQueue.main.async {
                self.userProgress = userProgress
            }

            self.db.collection("Subjects").document(subjectID).collection("Tests").document(testID).collection("Questions").getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching questions: \(error)")
                    return
                }

                guard let questionDocuments = snapshot?.documents else {
                    print("Error: No questions found or couldn't retrieve documents")
                    return
                }

                self.questions.removeAll()
                for document in questionDocuments {
                    if var question = try? document.data(as: Question.self) {
                        question.id = document.documentID
                        self.questions.append(question)
                    }
                }
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

        let userProgressRef = db.collection("UserProgress").document(userID)
        let answeredQuestionsRef = userProgressRef.collection("answeredQuestions").document(questionID)

        let questionData = [
            "hasUserAttempted": true,
            "hasUserAttemptedCorrectly": answeredCorrectly
        ] as [String: Any]

        return try await withCheckedThrowingContinuation { continuation in
            answeredQuestionsRef.setData(questionData) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func resetUserProgress(userId: String) {
        let userProgressRef = db.collection("UserProgress").document(userId)
        
        let resetData = [
            "Algebra": ["questionsAttempted": 0, "questionsCorrect": 0],
            "Advanced Math": ["questionsAttempted": 0, "questionsCorrect": 0],
            "Problem Solving & Data Analysis": ["questionsAttempted": 0, "questionsCorrect": 0],
            "Geometry & Trigonometry": ["questionsAttempted": 0, "questionsCorrect": 0]
        ]
        
        userProgressRef.updateData(["progress": resetData]) { error in
            if let error = error {
                print("Error resetting user progress: \(error.localizedDescription)")
            } else {
                print("User progress reset successfully.")
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
