//
//  OpenAIAdminViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/5/24.
//

import Foundation
import Firebase
import FirebaseFirestore

class OpenAIAdminViewModel: ObservableObject {
    @Published var subjects: [Subject] = []
    @Published var lessons: [Lesson] = []
    @Published var selectedSubject: Subject?
    @Published var pages: [Page] = []  // Array to hold pages of the current lesson
    @Published var latestPage: Page?  // This will hold only the latest generated page
    @Published var selectedLesson: Lesson? {
        didSet {
            guard oldValue?.id != selectedLesson?.id else { return }
            if let lesson = selectedLesson {
                Task {
                    await fetchPages(forLesson: lesson)
                }
            }
        }
    }

    private let service: OpenAIService = OpenAIService()

    func fetchSubjects() async {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("Subjects").getDocuments()
            if snapshot.documents.isEmpty {
                print("No subjects found.")
                return
            }

            // Ensure updates to published properties are dispatched on the main thread
            DispatchQueue.main.async {
                self.subjects = snapshot.documents.compactMap { document in
                    try? document.data(as: Subject.self)
                }
                print("Fetched \(self.subjects.count) subjects.")
            }
        } catch {
            DispatchQueue.main.async {
                print("Error fetching subjects: \(error)")
            }
        }
    }

    func fetchLessons(forSubject subject: Subject) async {
        let db = Firestore.firestore()
        guard let subjectId = subject.id else {
            print("Invalid subject ID")
            return
        }
        
        do {
            let snapshot = try await db.collection("Subjects").document(subjectId).collection("Lessons").getDocuments()
            if snapshot.documents.isEmpty {
                print("No lessons found for subject \(subject.name).")
                return
            }
            
            DispatchQueue.main.async {
                self.lessons = snapshot.documents.compactMap { document in
                    try? document.data(as: Lesson.self)
                }
            }
        } catch {
            print("Error fetching lessons for subject \(subject.name): \(error)")
        }
    }
    
    func fetchPages(forLesson lesson: Lesson) async {
        guard let lessonId = lesson.id, let subjectId = selectedSubject?.id else {
            print("Invalid subject ID or lesson ID")
            return
        }

        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("Subjects")
                                       .document(subjectId)
                                       .collection("Lessons")
                                       .document(lessonId)
                                       .collection("Pages")
                                       .getDocuments()
            
            print("Querying Firestore for pages at: Subjects/\(subjectId)/Lessons/\(lessonId)/Pages")
            print("Found \(snapshot.documents.count) pages")

            let pages = snapshot.documents.compactMap { doc in
                do {
                    return try doc.data(as: Page.self)
                } catch {
                    print("Error decoding page: \(error)")
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                self.selectedLesson?.pages = pages
                print("Fetched \(pages.count) pages for lesson \(lesson.name)")
            }
        } catch {
            print("Error fetching pages: \(error)")
        }
    }
    
    func addPageToFirestore(newPage: Page, subjectId: String, lessonId: String) {
        let db = Firestore.firestore()
        // Correctly referencing the lesson document by its ID and navigating to its Pages subcollection
        let pagesRef = db.collection("Subjects")
                              .document(subjectId)
                              .collection("Lessons")
                              .document(lessonId)
                              .collection("Pages")

        pagesRef.addDocument(data: [
            "content": newPage.content,
            "pageNumber": newPage.pageNumber,
            "example": newPage.example ?? "",
            "explanation": newPage.explanation ?? "",
            "graphics": newPage.graphics ?? ""
        ]) { error in
            if let error = error {
                print("Error adding page to Firestore: \(error.localizedDescription)")
            } else {
                print("New page added successfully to Firestore.")
            }
        }
    }

    func generateNewPageContent() {
        print("Attempting to generate new page content...")
        print("Currently selected lesson \(String(describing: selectedLesson))")

        guard let selectedLesson = selectedLesson,
              let pages = selectedLesson.pages,
              !pages.isEmpty,
              let selectedSubjectId = selectedSubject?.id,
              let selectedLessonId = selectedLesson.id else {
            print("Generation aborted: No pages available or IDs missing.")
            return
        }

        let sortedPages = pages.sorted { $0.pageNumber < $1.pageNumber }
        let lastPage = sortedPages.last!
        print("Last page content: \(lastPage.content)")

        let prompt = "Given the last page content: '\(lastPage.content)', generate a complete new page that sensibly continues on teaching the lesson of the previous page. Make the content no more than 2-3 sentences of material and provide a reasonable example field as well as an explanation if necessary"
        let chatQuery = ChatQuery(model: .gpt4, messages: [ChatMessage(role: .user, content: prompt)])

        service.sendChatCompletion(query: chatQuery, lastPage: lastPage) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newPage):
                    print("New page generated successfully with content: \(newPage.content)")
                    self?.latestPage = newPage
                    self?.addPageToFirestore(newPage: newPage, subjectId: selectedSubjectId, lessonId: selectedLessonId)
                case .failure(let error):
                    print("Failed to generate new page: \(error.localizedDescription)")
                }
            }
        }
    }
}
