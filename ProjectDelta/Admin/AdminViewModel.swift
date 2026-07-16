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
                subject?.id = doc.documentID
                return subject
            }
            
            if fetched.isEmpty {
                await seedDefaultSubjects()
            } else {
                var processedSubjects = fetched.sorted { $0.orderIndex < $1.orderIndex }
                
                // Establish exact aggregation counts for UI representation
                for i in 0..<processedSubjects.count {
                    guard let subjectId = processedSubjects[i].id else { continue }
                    do {
                        let countQuery = try await db.collection("Subjects").document(subjectId).collection("Lessons").count.getAggregation(source: .server)
                        processedSubjects[i].lessonCount = Int(truncating: countQuery.count)
                    } catch {
                        processedSubjects[i].lessonCount = 0
                    }
                }
                self.subjects = processedSubjects
            }
        } catch {
            print("Error fetching subjects: \(error.localizedDescription)")
        }
    }
    
    private func seedDefaultSubjects() async {
        var index = 0
        for area in SubjectArea.allCases {
            let newSubject = Subject(
                id: area.rawValue,
                name: area.rawValue,
                description: "Curriculum for \(area.rawValue)",
                difficulty: 1,
                subjectArea: area,
                imageName: "folder",
                subtopics: [],
                orderIndex: index
            )
            do {
                try await db.collection("Subjects").document(area.rawValue).setData(from: newSubject)
                index += 1
            } catch {
                print("Error seeding subject \(area.rawValue): \(error.localizedDescription)")
            }
        }
        await fetchSubjects()
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
            subtopics: [],
            orderIndex: subjects.count
        )
        do {
            try await db.collection("Subjects").document(id).setData(from: newSubject)
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
    
    func updateSubjectOrder(from source: IndexSet, to destination: Int) {
        subjects.move(fromOffsets: source, toOffset: destination)
        
        Task {
            let batch = db.batch()
            for (index, subject) in subjects.enumerated() {
                guard let id = subject.id else { continue }
                
                // 1. Force the local model to sync with the new visual index
                subjects[index].orderIndex = index
                
                let ref = db.collection("Subjects").document(id)
                // 2. Use setData with merge to aggressively inject the field into legacy documents
                batch.setData(["orderIndex": index], forDocument: ref, merge: true)
            }
            do {
                try await batch.commit()
            } catch {
                print("Failed to apply subject batch sequence update: \(error.localizedDescription)")
            }
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
                    
                    if let embeddedPages = lesson.pages, !embeddedPages.isEmpty {
                        lesson.pages = embeddedPages.map { page in
                            var p = page
                            if p.id == nil { p.id = "page_\(p.pageNumber)" }
                            return p
                        }
                    } else {
                        var pageSnapshot = try? await db.collection("Subjects").document(subjectId)
                            .collection("Lessons").document(lesson.id!)
                            .collection("Pages").order(by: "pageNumber").getDocuments()
                        
                        if pageSnapshot?.isEmpty == true {
                            pageSnapshot = try? await db.collection("Subjects").document(subjectId)
                                .collection("Lessons").document(lesson.id!)
                                .collection("pages").order(by: "pageNumber").getDocuments()
                        }
                        
                        let legacyPages = pageSnapshot?.documents.compactMap { doc -> Page? in
                            return try? doc.data(as: Page.self)
                        } ?? []
                        
                        lesson.pages = legacyPages
                    }
                    
                    if (lesson.pages?.isEmpty ?? true) && !lesson.description.isEmpty {
                        lesson.pages = [Page(id: "page_1", content: lesson.description, pageNumber: 1, readyButtonDisplayed: true)]
                    }
                    
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
        isProcessing = true
        defer { isProcessing = false }
        
        if let id = lesson.id, !id.isEmpty {
            try await db.collection("Subjects").document(subjectId).collection("Lessons").document(id).setData(from: lesson)
        } else {
            let _ = try await db.collection("Subjects").document(subjectId).collection("Lessons").addDocument(from: lesson)
        }
        await fetchLessons(for: subjectId)
    }

    func deleteLesson(subjectId: String, lessonId: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await db.collection("Subjects").document(subjectId).collection("Lessons").document(lessonId).delete()
            await fetchLessons(for: subjectId)
        } catch {
            print("Error deleting lesson: \(error.localizedDescription)")
        }
    }
    
    func updateLessonOrder(subjectId: String, from source: IndexSet, to destination: Int) {
        lessons.move(fromOffsets: source, toOffset: destination)
        
        Task {
            let batch = db.batch()
            for (index, lesson) in lessons.enumerated() {
                guard let id = lesson.id else { continue }
                
                // 1. Force the local model to sync with the new visual index
                lessons[index].lessonNumber = index + 1
                
                let ref = db.collection("Subjects").document(subjectId).collection("Lessons").document(id)
                // 2. Use setData with merge to aggressively inject the field into legacy documents
                batch.setData(["lessonNumber": index + 1], forDocument: ref, merge: true)
            }
            do {
                try await batch.commit()
            } catch {
                print("Failed to apply lesson batch sequence update: \(error.localizedDescription)")
            }
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
            let _ = try await db.collection("Subjects").document(subjectId).collection("Tests").addDocument(from: test)
            await fetchTests(for: subjectId)
        } catch {
            print("Error adding test: \(error.localizedDescription)")
        }
    }

    func deleteTest(subjectId: String, testId: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await db.collection("Subjects").document(subjectId).collection("Tests").document(testId).delete()
            await fetchTests(for: subjectId)
        } catch {
            print("Error deleting test: \(error.localizedDescription)")
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
            let _ = try await db.collection("questions").addDocument(from: question)
            showSubmissionSuccessAlert = true
            await fetchAllQuestions()
        } catch {
            print("Error saving question: \(error.localizedDescription)")
        }
    }

    func saveQuestionToTest(subjectId: String, testId: String, question: Question) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let docRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId).collection("Questions").document()
            var targetedQuestion = question
            targetedQuestion.id = docRef.documentID
            
            try await docRef.setData(from: targetedQuestion)
            
            try await db.collection("questions").document(docRef.documentID).setData(from: targetedQuestion)
            
            showSubmissionSuccessAlert = true
            await fetchAllQuestions()
        } catch {
            print("Error strictly saving targeted question: \(error.localizedDescription)")
        }
    }

    // MARK: - Migrations
    
    func rescueLegacyAlgebraLessons(defaultSubtopic: String = "Linear Equations") async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let subjectSnap = try await db.collection("Subjects").whereField("name", isEqualTo: SubjectArea.algebra.rawValue).getDocuments()
            
            guard let subjectDoc = subjectSnap.documents.first else {
                print("Legacy Algebra subject not found.")
                return
            }
            
            let realSubjectId = subjectDoc.documentID
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
}
