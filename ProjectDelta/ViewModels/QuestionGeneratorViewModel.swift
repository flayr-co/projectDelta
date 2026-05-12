//
//  QuestionGeneratorViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 11/27/23.
//

import Foundation
import FirebaseFirestore

@MainActor
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
    
    // MARK: - Fetch Subjects
    
    func fetchSubjects() async {
        do {
            let querySnapshot = try await db.collection("Subjects").getDocuments()
            self.subjects = querySnapshot.documents.map { document in
                let subjectName = document.data()["name"] as? String ?? "Unknown"
                return SubjectItem(id: document.documentID, name: subjectName)
            }
        } catch {
            print("Error getting subjects: \(error)")
        }
    }

    // MARK: - Fetch Tests for Selected Subject

    func fetchTestsForSubject(subjectId: String) async {
        do {
            let querySnapshot = try await db.collection("Subjects").document(subjectId).collection("Tests").getDocuments()
            self.tests = querySnapshot.documents.map { document in
                let testIdentifier = document.data()["testIdentifier"] as? Int ?? 0
                return TestItem(id: document.documentID, name: "\(testIdentifier)")
            }
        } catch {
            print("Error getting tests: \(error)")
        }
    }

    private func fetchTestsForSubject(subjectID: String) async {
        do {
            let querySnapshot = try await db.collection("Subjects").document(subjectID).collection("Tests").getDocuments()
            self.tests = querySnapshot.documents.map { document in
                let testName = document.data()["name"] as? String ?? "Unknown"
                return TestItem(id: document.documentID, name: testName)
            }
        } catch {
            print("Error getting tests: \(error)")
        }
    }
    
    // MARK: - Save Question
    
    func saveQuestion(completion: @escaping () -> Void) {
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
                Task { @MainActor in
                    self?.generatedQuestion = nil
                    self?.isApprovalViewPresented = false
                    completion()
                }
            case .failure(let error):
                print("Error adding question: \(error.localizedDescription)")
            }
        }
    }
}
