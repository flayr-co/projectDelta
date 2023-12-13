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
    @Published var currentSubjectArea: String?
    
    private var db = Firestore.firestore()
    
    private var openAIService = OpenAIService()
    
    private var authViewModel: AuthViewModel
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - FETCH SUBJECTS

    func fetchSubjectsFromFirestore() {
        db.collection("Subjects").getDocuments() { (querySnapshot, err) in
            if let err = err {
                print("Error getting subjects: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    if let subjectName = document.data()["name"] as? String {
                        self.subjects.append(subjectName)
                        print("Fetched subject: \(subjectName)")
                    }
                }
                print("Total subjects fetched: \(self.subjects.count)")
            }
        }
    }
    
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
                print("Error fetching tests for subject \(subjectName): \(error)")
            } else if let testsSnapshot = testsSnapshot, !testsSnapshot.isEmpty {
                let tests = testsSnapshot.documents
                print("Fetched \(tests.count) tests for subject: \(subjectName)")
                let randomTest = tests.randomElement()

                if let testDocumentID = randomTest?.documentID {
                    print("Random test document ID for subject \(subjectName): \(testDocumentID)")
                    self.fetchQuestions(forTestID: testDocumentID, subjectID: subjectID) // Corrected this line
                }
            } else {
                print("No tests found for subject: \(subjectName)")
            }
        })
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
                        question?.id = document.documentID  // Explicitly set the document ID if it's not set
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
                
                // Existing code to fetch questions
                let fetchedQuestions = questionDocuments.compactMap { document -> Question? in
                    return try? document.data(as: Question.self)
                }
                
                // Filter out questions that have been answered
                self.questions = fetchedQuestions.filter { question in
                    return !(userProgress.answeredQuestions.keys.contains(question.id ?? ""))
                }
            }
        }
    }
    
    // MARK: - FETCH USER PROGRESS
    
    func fetchUserProgress(forUserID userID: String) {
        let userProgressRef = db.collection("UserProgress").document(userID)
        userProgressRef.getDocument { [weak self] documentSnapshot, error in
            guard let self = self, let snapshot = documentSnapshot else {
                print("Error fetching user progress: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            do {
                let userProgress = try snapshot.data(as: UserProgress.self)
                DispatchQueue.main.async {
                    self.userProgress = userProgress
                }
            } catch {
                print("Error decoding user progress: \(error)")
            }
        }
    }
    
    // Now, when you need to access the user's UID, you can do so like this:
    func handleQuestionAnswered(question: Question, answeredCorrectly: Bool) async {
        guard let currentUserID = await authViewModel.userSession?.uid else { return }
        await updateUserProgress(questionID: question.id ?? "", answeredCorrectly: answeredCorrectly, userID: currentUserID)
    }
    
    func updateUserProgress(questionID: String, answeredCorrectly: Bool, userID: String) async {
        // Asynchronous logic to update progress on Firestore goes here
    }
    
    // Add a function in QuizViewModel to update the user's progress for a given subject.
    func updateUserProgressForSubject(userId: String, subjectArea: String, answeredCorrectly: Bool) {
        // Fetch the current user progress
        let userProgressRef = db.collection("UserProgress").document(userId)
        userProgressRef.getDocument { (document, error) in
            if let document = document, document.exists {
                var userProgress = try? document.data(as: UserProgress.self)
                // Update the progress for the specific subject area
                if let progress = userProgress?.progress[subjectArea] {
                    let updatedProgress = SubjectProgress(questionsAttempted: progress.questionsAttempted + 1,
                                                          questionsCorrect: progress.questionsCorrect + (answeredCorrectly ? 1 : 0))
                    userProgress?.progress[subjectArea] = updatedProgress
                } else {
                    // If there's no progress for this subject yet, create a new entry
                    userProgress?.progress[subjectArea] = SubjectProgress(questionsAttempted: 1, questionsCorrect: answeredCorrectly ? 1 : 0)
                }
                // Write the updated progress back to Firestore
                do {
                    try userProgressRef.setData(from: userProgress)
                } catch let error {
                    print("Error updating user progress: \(error)")
                }
            } else {
                print("Document does not exist")
            }
        }
    }
    
    func addDummyDataForUser(userId: String) {
        let dummyProgress = UserProgress(
            userId: userId,
            progress: [
                "Advanced Math": SubjectProgress(questionsAttempted: 5, questionsCorrect: 3),
                "Algebra": SubjectProgress(questionsAttempted: 10, questionsCorrect: 7),
                // Add more subjects as needed
            ],
            answeredQuestions: [:], // Populate with dummy question IDs and true/false values as needed
            questionsAttempted: 0 // This should be calculated based on the sum of questionsAttempted in progress
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
