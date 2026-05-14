//
//  AdminViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/15/24.
//

import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
class AdminViewModel {
    var subjects: [Subject] = []
    var lessons: [Lesson] = []
    var tests: [Test] = []
    var questions: [Question] = []
    
    var isProcessing: Bool = false
    var showSubmissionSuccessAlert: Bool = false
    var migrationMessage: String = ""
    
    private let db = Firestore.firestore()
    
    init() {
        Task {
            // Added isProcessing toggle here so the UI knows data is loading on open
            self.isProcessing = true
            await fetchSubjects()
            await fetchAllQuestions()
            self.isProcessing = false
        }
    }
    
    // MARK: - Subjects
    
    func fetchSubjects() async {
        do {
            let snapshot = try await db.collection("Subjects").getDocuments()
            self.subjects = snapshot.documents.compactMap { try? $0.data(as: Subject.self) }
                .sorted { $0.name < $1.name }
        } catch {
            print("Error fetching subjects: \(error.localizedDescription)")
        }
    }
    
    func addSubject(name: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        let id = UUID().uuidString
        let newSubject = Subject(
            id: id,
            name: name,
            description: "Curriculum for \(name)",
            difficulty: 1,
            subjectArea: .algebra, // Default, can be edited later
            imageName: "folder"
        )
        do {
            try db.collection("Subjects").document(id).setData(from: newSubject)
            await fetchSubjects()
        } catch {
            print("Error adding subject: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Lessons
    
    func fetchLessons(for subjectId: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let snapshot = try await db.collection("Subjects").document(subjectId).collection("Lessons").getDocuments()
            var fetchedLessons: [Lesson] = []
            
            for doc in snapshot.documents {
                if var lesson = try? doc.data(as: Lesson.self) {
                    lesson.id = doc.documentID
                    let pageSnapshot = try await db.collection("Subjects").document(subjectId)
                        .collection("Lessons").document(doc.documentID)
                        .collection("Pages").getDocuments()
                    
                    lesson.pages = pageSnapshot.documents.compactMap { try? $0.data(as: Page.self) }
                        .sorted { $0.pageNumber < $1.pageNumber }
                    fetchedLessons.append(lesson)
                }
            }
            self.lessons = fetchedLessons.sorted { $0.lessonNumber < $1.lessonNumber }
        } catch {
            print("Error fetching lessons: \(error.localizedDescription)")
        }
    }
    
    func addLesson(subjectId: String, name: String, description: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        let lessonId = UUID().uuidString
        let newLesson = Lesson(
            id: lessonId,
            name: name,
            description: description,
            completed: false,
            lessonNumber: (lessons.count + 1),
            pages: []
        )
        do {
            try db.collection("Subjects").document(subjectId).collection("Lessons").document(lessonId).setData(from: newLesson)
            await fetchLessons(for: subjectId)
        } catch {
            print("Error adding lesson: \(error.localizedDescription)")
        }
    }
    
    func savePage(subjectId: String, lessonId: String, page: Page) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try db.collection("Subjects").document(subjectId)
                .collection("Lessons").document(lessonId)
                .collection("Pages").addDocument(from: page)
            showSubmissionSuccessAlert = true
            await fetchLessons(for: subjectId)
        } catch {
            print("Error adding page: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Tests & Questions
    
    func fetchTests(for subjectId: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let snapshot = try await db.collection("Subjects").document(subjectId).collection("Tests").getDocuments()
            self.tests = snapshot.documents.compactMap { doc -> Test? in
                var test = try? doc.data(as: Test.self)
                test?.id = doc.documentID
                return test
            }.sorted { $0.testIdentifier < $1.testIdentifier }
        } catch {
            print("Error fetching tests: \(error.localizedDescription)")
        }
    }
    
    func addTest(subjectId: String, test: Test) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try db.collection("Subjects").document(subjectId).collection("Tests").addDocument(from: test)
            await fetchTests(for: subjectId)
        } catch {
            print("Error adding test: \(error.localizedDescription)")
        }
    }
    
    func fetchAllQuestions() async {
        do {
            let snapshot = try await db.collection("questions").getDocuments()
            self.questions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
        } catch {
            print("Error fetching questions: \(error.localizedDescription)")
        }
    }
    
    func saveQuestion(question: Question) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try db.collection("questions").addDocument(from: question)
            showSubmissionSuccessAlert = true
            await fetchAllQuestions()
        } catch {
            print("Error saving question: \(error.localizedDescription)")
        }
    }
}
