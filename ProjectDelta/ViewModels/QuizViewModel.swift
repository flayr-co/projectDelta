//
//  QuizViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

// QuizViewModel
import Foundation
import Firebase
import FirebaseFirestoreSwift
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
//    @Published var answeredCorrectly: Bool?
    @Published var answeredCorrectly = Set<Int>()
    @Published var score = 0
    
    private var db = Firestore.firestore()
    
    private var openAIService = OpenAIService()
    
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
    
//    func fetchSubjectArea(for subjectName: String) async throws -> String {
//        let subjectsRef = Firestore.firestore().collection("Subjects")
//        let snapshot = try await subjectsRef.whereField("name", isEqualTo: subjectName).getDocuments()
//
//        guard let document = snapshot.documents.first,
//              let subjectArea = document.data()["subjectArea"] as? String else {
//            throw NSError(domain: "AppErrorDomain", code: -1, userInfo: [
//                NSLocalizedDescriptionKey: "Subject area for subject \(subjectName) not found."
//            ])
//        }
//        
//        return subjectArea
//    }
    
    // MARK: - FETCH TESTS

    func fetchRandomTest(for subject: String) {
        // Step 1: Fetch the document ID of the specified subject
        db.collection("Subjects").whereField("name", isEqualTo: subject).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching document ID for subject \(subject): \(error)")
            } else if let snapshot = snapshot, let document = snapshot.documents.first {
                let subjectDocumentID = document.documentID
                print("Fetched document ID for subject \(subject): \(subjectDocumentID)")
                
                // Save the subject document ID to the ViewModel
                DispatchQueue.main.async {
                    self.selectedSubjectDocId = subjectDocumentID
                }

                // Step 2: Fetch tests using the obtained document ID
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
                    subject.id = subjectSnapshot.documentID // Manually set the id here
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
                self.questions.removeAll() // Clear existing questions
                for document in snapshot.documents {
                    print("Question document ID: \(document.documentID)")
                    // Create a Question instance from the document data
                    var question = try? document.data(as: Question.self)
                    print("Fetched Question: \(question?.questionText ?? "N/A"), Options: \(question?.options.joined(separator: ", ") ?? "N/A")")
                    if question?.id == nil {
                        question?.id = document.documentID // Explicitly set the document ID if it's not set
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
    
    
    
    // This function would be called when the user navigates to a different question, for example:
    // setCurrentQuestionDocId(for: currentIndex + 1) // for next question
    // setCurrentQuestionDocId(for: currentIndex - 1) // for previous question
    
    func setCurrentQuestionDocId(for index: Int) {
        guard index >= 0 && index < questions.count else { return }
        DispatchQueue.main.async {
            self.currentQuestionDocId = self.questions[index].id
        }
    }
    
    func checkAnswerAndUpdateScore(userAnswer: Int?, currentQuestionIndex: Int) {
        if let userAnswer = userAnswer,
           userAnswer == questions[currentQuestionIndex].correctOptionIndex {
            // Increment score if the answer is correct
            score += 1
        }
    }
    
    
    
    // MARK: - FETCH QUESTIONS FOR USER

    func fetchQuestionsForUser(forTestID testID: String, subjectID: String, userID: String) {
        // Fetch UserProgress first to determine which questions have been answered
        self.db.collection("UserProgress").document(userID).getDocument { (progressSnapshot, error) in
            if let error = error {
                print("Error fetching user progress: \(error)")
                return
            }

            guard let progressSnapshot = progressSnapshot else {
                print("Error: DocumentSnapshot is nil or couldn't retrieve data")
                return
            }

            // Decode the UserProgress
            guard let userProgress = try? progressSnapshot.data(as: UserProgress.self) else {
                print("Error decoding user progress")
                return
            }

            // Set the fetched user progress to the published property
            DispatchQueue.main.async {
                self.userProgress = userProgress
            }

            // Then fetch questions excluding the ones already answered
            self.db.collection("Subjects").document(subjectID).collection("Tests").document(testID).collection("Questions").getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching questions: \(error)")
                    return
                }

                guard let questionDocuments = snapshot?.documents else {
                    print("Error: No questions found or couldn't retrieve documents")
                    return
                }

                // Fetch questions
                self.questions.removeAll() // Clear existing questions
                for document in questionDocuments {
                    // Create a Question instance from the document data
                    if var question = try? document.data(as: Question.self) {
                        question.id = document.documentID  // Explicitly set the document ID
                        self.questions.append(question)
                    }
                }

                // Now `self.questions` array contains all questions with their document IDs set
                // You can now use these document IDs in your UI code as needed
            }
        }
    }
    
    // MARK: - FETCH USER PROGRESS
    
    func fetchUserProgress(forUserID userID: String) async throws -> UserProgress? {
        let userProgressRef = db.collection("UserProgress").document(userID)
        
        do {
            let documentSnapshot = try await userProgressRef.getDocument()
            // Log the raw data for debugging purposes
            print("Raw document data: \(documentSnapshot.data() ?? [:])")
            
            // Attempt to decode the document data into a UserProgress object
            guard let userProgress = try? documentSnapshot.data(as: UserProgress.self) else {
                print("Error: User progress data is missing or has an unexpected format.")
                return nil
            }
            return userProgress
        } catch let error as NSError where error.domain == FirestoreErrorDomain {
            // Handle Firestore-specific errors
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
            // Handle any other errors more verbosely
            print("An error occurred: \(error)")
            // If you have a debug description available, print that as well
            if let decodingError = error as? DecodingError {
                print(decodingError.localizedDescription)
            }
        }
        return nil
    }
    
    func updateUserProgress(forUserID userID: String, subjectName: String, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        do {
            // Fetch the user progress
            guard (try await fetchUserProgress(forUserID: userID)) != nil else {
                throw NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "User progress not found."
                ])
            }

            // Fetch the subject area using the subject name
            guard let subjectArea = try await fetchSubjectArea(for: subjectName) else {
                // Handle the error, maybe throw a custom error or return early
                throw NSError(domain: "YourErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Subject area not found."])
            }

            // Update the user progress for the subject
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

        // Firestore supports dot notation for accessing nested fields within a document.
        // Define the keys for the nested fields you want to update.
        let attemptedKey = "progress.\(subjectArea.rawValue).questionsAttempted"
        let correctKey = "progress.\(subjectArea.rawValue).questionsCorrect"
        let answeredQuestionsKey = "answeredQuestions.\(questionDocumentID)"

        // Create the update data for incrementing the attempted questions
        var updateData: [String: Any] = [
            attemptedKey: FieldValue.increment(Int64(1))
        ]

        // If the question was answered correctly, also increment the correct questions count
        if answeredCorrectly {
            updateData[correctKey] = FieldValue.increment(Int64(1))
        }
        
        // Update the answeredQuestions map with the question document ID and correctness
        updateData[answeredQuestionsKey] = answeredCorrectly

        // Perform the update with the constructed data
        try await userProgressRef.updateData(updateData)
    }
    
    // Now, when you need to access the user's UID, you can do so like this:
    // This function no longer needs the 'userID' parameter since it's fetched within the function.
    func handleQuestionAnswered(question: Question, subject: Subject, answeredCorrectly: Bool) async {
        do {
            try await updateUserAnswerForQuestion(questionID: question.id ?? "", answeredCorrectly: answeredCorrectly, question: question, subject: subject)
        } catch {
            print("Error updating answered question: \(error.localizedDescription)")
        }
    }

    // Update the function signature to match the parameters being passed.
    func updateUserAnswerForQuestion(questionID: String, answeredCorrectly: Bool, question: Question, subject: Subject) async throws {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AppError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not found"])
        }

        let userProgressRef = db.collection("UserProgress").document(userID)
        let answeredQuestionsRef = userProgressRef.collection("answeredQuestions").document(questionID)

        let questionData = [
            "hasUserAttempted": true,
            "hasUserAttemptedCorrectly": answeredCorrectly,
            // Add more fields here if needed, like subject or subjectArea
        ] as [String: Any]

        // Use a Task to handle the completion-based method call
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

    // JUST IN CASE A USER NEEDS PROGRESS RESET
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

    // MARK: - GET HINT FOR QUESTION
    
    func getHintForQuestion(questionText: String, completion: @escaping (Result<String, Error>) -> Void) {
        openAIService.generateHint(forQuestion: questionText, completion: completion)
    }

    // MARK: - FOR LESSON VIEW OPENAI API USAGE

    func generateLessonContent(for subject: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Assuming 'subject' is the name of the subject selected by the user
        let prompts = [
            "Explain the basics of \(subject).",
            "Provide an example problem in \(subject).",
            "Summarize key points in \(subject)."
        ]
        
        var lessonContents: [String] = []
        var fetchErrors: [Error] = [] // To store any errors encountered during fetch operations
        let dispatchGroup = DispatchGroup()
        
        for prompt in prompts {
            dispatchGroup.enter()
            openAIService.generateQuestion(prompt: prompt) { result in
                defer { dispatchGroup.leave() }
                switch result {
                case .success(let content):
                    lessonContents.append(content)
                case .failure(let error):
                    fetchErrors.append(error) // Append the error to the list of encountered errors
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if !fetchErrors.isEmpty {
                // If there are any errors, return the first one encountered
                completion(.failure(fetchErrors.first!))
            } else {
                // If there were no errors, return the array of lesson contents
                completion(.success(lessonContents))
            }
        }
    }
}






//    func fetchQuestions(for subject: String, test: String) {
//        let testRef = db.collection("Subjects").document(subject).collection("Tests").document(test)
//        testRef.collection("Questions").getDocuments() { (snapshot, error) in
//            if let error = error {
//                print("Error fetching questions: \(error.localizedDescription)")
//                return
//            }
//
//            self.questions = snapshot?.documents.compactMap {
//                let question = try? $0.data(as: Question.self)
//                if let fetchedQuestion = question {
//                    print("Fetched question: \(fetchedQuestion)")
//                }
//                return question
//            } ?? []
//        }
//    }
