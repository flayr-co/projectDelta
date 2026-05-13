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
    var questions: [Question] = []
    
    var selectedSubjectId: String? = nil
    var selectedLessonId: String? = nil
    
    var isProcessing: Bool = false
    var showSubmissionSuccessAlert: Bool = false
    var showingPageExistsWarning: Bool = false
    var migrationMessage: String = ""
    
    private let db = Firestore.firestore()
    
    init() {
        Task {
            await fetchSubjects()
            await fetchAllQuestions()
        }
    }
    
    // MARK: - Fetching Logic
    
    func fetchSubjects() async {
        do {
            let snapshot = try await db.collection("Subjects").getDocuments()
            self.subjects = snapshot.documents.compactMap { try? $0.data(as: Subject.self) }
                .sorted { $0.name < $1.name }
        } catch {
            print("Error fetching subjects: \(error)")
        }
    }
    
    func fetchLessons(for subjectId: String) async {
        self.selectedSubjectId = subjectId
        self.lessons = []
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
            self.lessons = fetchedLessons.sorted { $0.name < $1.name }
        } catch {
            print("Error fetching lessons: \(error)")
        }
    }
    
    func fetchAllQuestions() async {
        do {
            let snapshot = try await db.collection("questions").getDocuments()
            self.questions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
        } catch {
            print("Error fetching questions: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func addSubject(name: String) async {
        let id = UUID().uuidString
        // Fixed: Included missing required parameters for Subject model
        let newSubject = Subject(
            id: id,
            name: name,
            description: "Default description for \(name)",
            difficulty: 1,
            subjectArea: .algebra,
            imageName: "folder"
        )
        do {
            try db.collection("Subjects").document(id).setData(from: newSubject)
            await fetchSubjects()
        } catch {
            print("Error adding subject: \(error)")
        }
    }
    
    func deleteSubject(id: String) async {
        do {
            try await db.collection("Subjects").document(id).delete()
            await fetchSubjects()
        } catch {
            print("Error deleting subject: \(error)")
        }
    }
    
    func addLesson(subjectId: String, name: String) async {
        let lessonId = UUID().uuidString
        let newLesson = Lesson(
            id: lessonId,
            name: name,
            description: "New Lesson",
            completed: false,
            lessonNumber: (lessons.count + 1),
            pages: []
        )
        do {
            try db.collection("Subjects").document(subjectId).collection("Lessons").document(lessonId).setData(from: newLesson)
            await fetchLessons(for: subjectId)
        } catch {
            print("Error adding lesson: \(error)")
        }
    }
    
    func addPageToFirestore(subjectId: String, lessonId: String, page: Page) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let existing = try await db.collection("Subjects").document(subjectId)
                .collection("Lessons").document(lessonId)
                .collection("Pages")
                .whereField("pageNumber", isEqualTo: page.pageNumber)
                .getDocuments()
            
            if !existing.documents.isEmpty {
                showingPageExistsWarning = true
                return
            }
            
            // Fixed: This now works because Page is Encodable
            try db.collection("Subjects").document(subjectId)
                .collection("Lessons").document(lessonId)
                .collection("Pages").addDocument(from: page)
            
            showSubmissionSuccessAlert = true
            await fetchLessons(for: subjectId)
        } catch {
            print("Error adding page: \(error.localizedDescription)")
        }
    }
    
    func deleteQuestion(id: String) async {
        do {
            try await db.collection("questions").document(id).delete()
            await fetchAllQuestions()
        } catch {
            print("Error deleting question: \(error)")
        }
    }
    
    // MARK: - Migration Tools
    
    func migrateAlgebraSubtopics() async {
        isProcessing = true
        migrationMessage = "Running migration..."
        
        do {
            let snapshot = try await db.collection("questions")
                .whereField("subject", isEqualTo: "Algebra")
                .getDocuments()
            
            let batch = db.batch()
            var count = 0
            
            for doc in snapshot.documents {
                if doc.data()["subtopic"] == nil {
                    batch.updateData(["subtopic": "Linear Equations"], forDocument: doc.reference)
                    count += 1
                }
            }
            
            try await batch.commit()
            migrationMessage = "Successfully updated \(count) documents."
            await fetchAllQuestions()
        } catch {
            migrationMessage = "Migration failed: \(error.localizedDescription)"
        }
        isProcessing = false
    }
}
