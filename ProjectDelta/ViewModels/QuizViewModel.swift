//
//  QuizViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

// QuizViewModel
import Foundation
import Firebase
import SwiftUI

class QuizViewModel: ObservableObject {
    @Published var subjects: [String] = []
    @Published var testsForSelectedSubject: [Test] = []
    @Published var questions: [Question] = []
    @Published var selectedSubjectDocId: String?
    
    private var db = Firestore.firestore()
    
    private var openAIService = OpenAIService()
    
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
