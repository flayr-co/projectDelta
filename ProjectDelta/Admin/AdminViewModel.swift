//
//  AdminViewModel.swift
//  ProjectDelta
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
            let fetched = snapshot.documents.compactMap { doc -> Subject? in
                var subject = try? doc.data(as: Subject.self)
                // Explicitly bind the documentID to bypass the custom decoder's @DocumentID failure
                subject?.id = doc.documentID
                return subject
            }
            
            if fetched.isEmpty {
                await seedDefaultSubjects()
            } else {
                self.subjects = fetched.sorted { $0.name < $1.name }
            }
        } catch {
            print("Error fetching subjects: \(error.localizedDescription)")
        }
    }
    
    private func seedDefaultSubjects() async {
        for area in SubjectArea.allCases {
            let newSubject = Subject(
                id: area.rawValue,
                name: area.rawValue,
                description: "Curriculum for \(area.rawValue)",
                difficulty: 1,
                subjectArea: area,
                imageName: "folder",
                subtopics: []
            )
            do {
                try db.collection("Subjects").document(area.rawValue).setData(from: newSubject)
            } catch {
                print("Error seeding subject \(area.rawValue): \(error.localizedDescription)")
            }
        }
        
        do {
            let snapshot = try await db.collection("Subjects").getDocuments()
            self.subjects = snapshot.documents.compactMap { try? $0.data(as: Subject.self) }
                .sorted { $0.name < $1.name }
        } catch {
            print("Error fetching after seed: \(error.localizedDescription)")
        }
    }
    
    func addSubject(name: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        let id = UUID().uuidString
        let mappedArea = SubjectArea(rawValue: name) ?? .algebra
        
        let newSubject = Subject(
            id: id,
            name: name,
            description: "Curriculum for \(name)",
            difficulty: 1,
            subjectArea: mappedArea,
            imageName: "folder",
            subtopics: []
        )
        do {
            try db.collection("Subjects").document(id).setData(from: newSubject)
            await fetchSubjects()
        } catch {
            print("Error adding subject: \(error.localizedDescription)")
        }
    }

    func deleteSubject(id: String) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await db.collection("Subjects").document(id).delete()
            await fetchSubjects()
        } catch {
            print("Error deleting subject: \(error.localizedDescription)")
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
                    fetchedLessons.append(lesson)
                }
            }
            self.lessons = fetchedLessons.sorted { $0.lessonNumber < $1.lessonNumber }
        } catch {
            print("Error fetching lessons: \(error.localizedDescription)")
        }
    }
    
    func addLesson(to subject: Subject, lesson: Lesson) async throws {
        guard let subjectId = subject.id else { return }
        self.isProcessing = true
        defer { self.isProcessing = false }
        
        if let id = lesson.id, !id.isEmpty {
            try db.collection("Subjects").document(subjectId).collection("Lessons").document(id).setData(from: lesson)
        } else {
            _ = try db.collection("Subjects").document(subjectId).collection("Lessons").addDocument(from: lesson)
        }
        await fetchLessons(for: subjectId)
    }
    
    // MARK: - Migrations
    
    func rescueLegacyAlgebraLessons(defaultSubtopic: String = "Linear Equations") async {
        self.isProcessing = true
        defer { self.isProcessing = false }
        
        do {
            // 1. Dynamically query for your legacy Algebra subject by name to get its true auto-generated UUID
            let subjectSnap = try await db.collection("Subjects").whereField("name", isEqualTo: SubjectArea.algebra.rawValue).getDocuments()
            
            guard let subjectDoc = subjectSnap.documents.first else {
                print("Legacy Algebra subject not found.")
                return
            }
            
            let realSubjectId = subjectDoc.documentID
            
            // 2. Target the exact auto-generated document path holding your actual hard work
            let lessonsRef = db.collection("Subjects").document(realSubjectId).collection("Lessons")
            let snapshot = try await lessonsRef.getDocuments()
            
            for document in snapshot.documents {
                try await lessonsRef.document(document.documentID).setData([
                    "subtopic": defaultSubtopic
                ], merge: true)
            }
            
            print("Successfully rescued and migrated \(snapshot.documents.count) Algebra lessons.")
            await fetchLessons(for: realSubjectId)
            
        } catch {
            print("Failed to execute migration script: \(error.localizedDescription)")
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
