//
//  QuizGeneratorViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 11/27/23.
//

// QuizGeneratorViewModel.swift
import Foundation
import Firebase

class QuestionGeneratorViewModel: ObservableObject {
    struct SubjectItem {
        var id: String
        var name: String
    }
    
    struct TestItem {
        var id: String
        var name: String
    }

    @Published var subjects: [SubjectItem] = []
    @Published var tests: [TestItem] = []
    @Published var selectedSubjectId: String?
    @Published var selectedTestId: String?
    @Published var generatedQuestion: Question? = nil
    @Published var isApprovalViewPresented: Bool = false
    
    private var db = Firestore.firestore()
    private var openAIService = OpenAIService()
    
    // MARK: - Fetch Subjects
    
    func fetchSubjects() {
        db.collection("Subjects").getDocuments() { [weak self] (querySnapshot, err) in
            if let err = err {
                print("Error getting subjects: \(err)")
            } else {
                var fetchedSubjects = [SubjectItem]()
                for document in querySnapshot!.documents {
                    let subjectName = document.data()["name"] as? String ?? "Unknown"
                    let subjectId = document.documentID
                    fetchedSubjects.append(SubjectItem(id: subjectId, name: subjectName))
                }
                DispatchQueue.main.async {
                    self?.subjects = fetchedSubjects
                }
            }
        }
    }

    // MARK: - Fetch Tests for Selected Subject

    func fetchTestsForSubject(subjectId: String) {
        db.collection("Subjects").document(subjectId).collection("Tests").getDocuments() { [weak self] (querySnapshot, err) in
            if let err = err {
                print("Error getting tests: \(err)")
            } else {
                var fetchedTests = [TestItem]()
                for document in querySnapshot!.documents {
                    let testId = document.documentID
                    let testIdentifier = document.data()["testIdentifier"] as? Int ?? 0 // Assuming it's an Int, use the correct type here
                    fetchedTests.append(TestItem(id: testId, name: "\(testIdentifier)")) // Now using testIdentifier as the name
                }
                DispatchQueue.main.async {
                    self?.tests = fetchedTests
                }
            }
        }
    }

    private func fetchTestsForSubject(subjectID: String) {
        db.collection("Subjects").document(subjectID).collection("Tests").getDocuments() { [weak self] (querySnapshot, err) in
            if let err = err {
                print("Error getting tests: \(err)")
            } else {
                var fetchedTests = [TestItem]()
                for document in querySnapshot!.documents {
                    let testName = document.data()["name"] as? String ?? "Unknown"
                    let testId = document.documentID
                    fetchedTests.append(TestItem(id: testId, name: testName))
                }
                DispatchQueue.main.async {
                    self?.tests = fetchedTests
                }
            }
        }
    }
    
    // MARK: - Generate Question

    func generateQuestion(subjectId: String, testId: String) {
        let subjectName = subjects.first(where: { $0.id == subjectId })?.name ?? "Unknown"
        let prompt = "Generate a multiple-choice math question for the subject \(subjectName) along with four options, do not indicate the correct answer. Do not start the question with 'Question:', just get straight to it."
        
        openAIService.generateQuestion(prompt: prompt) { [weak self] result in
            switch result {
            case .success(let questionText):
                DispatchQueue.main.async {
                    let question = Question(
                        correctOptionIndex: 0, // Placeholder value
                        options: ["Option 1", "Option 2", "Option 3", "Option 4"], // Placeholder values
                        points: 1,
                        questionText: questionText,
                        type: "Multiple Choice",
                        subject: subjectName,
                        hint: ""
                    )
                    self?.generatedQuestion = question
                    self?.isApprovalViewPresented = true
                }
            case .failure(let error):
                print("Error generating question: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper function to create a prompt from subjectId (this is just an example)
    private func createPromptFromSubjectId(_ subjectId: String) -> String {
        // Implement your logic here to create a prompt based on the subjectId
        return "What are the important concepts in subject with ID \(subjectId)?"
    }
    
    // MARK: - Save Question
    
    func saveQuestion(completion: @escaping () -> Void) { // Add a completion handler
        guard let question = generatedQuestion,
              let subjectId = selectedSubjectId,
              let testId = selectedTestId else {
            print("Subject or Test is not selected or IDs are empty")
            return
        }
        
        print("Attempting to save question: \(question)")
        let firestoreManager = FirestoreManager()
        firestoreManager.saveQuestion(subjectId: subjectId, testId: testId, question: question) { [weak self] result in
            switch result {
            case .success():
                print("Question added successfully to subjectId: \(subjectId), testId: \(testId)")
                // Clear the generated question and hide the approval view upon success
                DispatchQueue.main.async {
                    self?.generatedQuestion = nil
                    self?.isApprovalViewPresented = false
                    completion() // Call the completion handler
                }
            case .failure(let error):
                print("Error adding question: \(error.localizedDescription)")
            }
        }
    }
}

