//
//  LessonViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/11/24.
//

// LessonViewModel.swift
import Foundation
import Firebase

class LessonViewModel: ObservableObject {
    @Published var currentLesson: Lesson?
    @Published var currentLessonName: String = ""
    @Published var currentLessonId: String = ""
    @Published var lessonPages: [Page] = []
    @Published var lessons: [Lesson] = []
    @Published var currentSubjectLessons: [Lesson] = []
    @Published var subjectName: String = ""
    @Published var currentPageIndex: Int = 0
    @Published var currentPageDocumentId: String?
    @Published var isLoading: Bool = true
    @Published var isCurrentPageBookmarked: Bool = false

    @MainActor
    func initializeLesson(subjectName: String, authVM: AuthViewModel) async {
        print("Starting to fetch the first incomplete lesson for \(subjectName).")
        let (lessonName, lessonId) = await fetchFirstIncompleteLesson(for: subjectName)
        
        // Check for non-empty lesson name and ID to proceed
        if !lessonName.isEmpty {
            DispatchQueue.main.async {
                // Access properties through your view model
                self.currentLessonName = lessonName
                self.currentLessonId = lessonId  // Correctly reference through lessonVM
                print("First incomplete lesson fetched: \(lessonName) with ID \(lessonId)")
            }
            
            print("Starting to fetch lesson content for \(subjectName), lesson \(lessonName).")
            await fetchLessonContent(for: subjectName, lessonName: lessonName)
            print("Content fetching completed for lesson \(lessonName).")
            
            if let initialPageNumber = self.lessonPages.first?.pageNumber {
                self.navigateToPage(lessonName: lessonName, pageNumber: initialPageNumber, authVM: authVM)
            }
        } else {
            print("No incomplete lesson found or fetch failed for subject \(subjectName).")
        }
    }

    func fetchLessonContent(for subjectName: String, lessonName: String) async {
        let db = Firestore.firestore()

        do {
            let subjectQuerySnapshot = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            guard let subjectDocument = subjectQuerySnapshot.documents.first else {
                print("Subject \(subjectName) not found.")
                return
            }

            let lessonQuerySnapshot = try await db.collection("Subjects").document(subjectDocument.documentID)
                .collection("Lessons").whereField("name", isEqualTo: lessonName).getDocuments()
            guard let lessonDocument = lessonQuerySnapshot.documents.first else {
                print("Lesson \(lessonName) not found within \(subjectName).")
                return
            }

            let pagesQuerySnapshot = try await db.collection("Subjects").document(subjectDocument.documentID)
                .collection("Lessons").document(lessonDocument.documentID)
                .collection("Pages").order(by: "pageNumber").getDocuments()
            let fetchedPages = pagesQuerySnapshot.documents.map { document in
                return Page(
                    id: document.documentID,
                    content: document.data()["content"] as? String ?? "",
                    pageNumber: document.data()["pageNumber"] as? Int ?? 0,
                    readyButtonDisplayed: document.data()["readyButtonDisplayed"] as? Bool ?? false,
                    example: document.data()["example"] as? String,
                    explanation: document.data()["explanation"] as? String,
                    graphics: document.data()["graphics"] as? String
                )
            }

            DispatchQueue.main.async {
                self.lessonPages = fetchedPages
                self.currentLesson?.pages = fetchedPages  // Set the pages for the current lesson
                fetchedPages.forEach { page in
                    print("Fetched page: \(page.pageNumber) with ID: \(page.id ?? "N/A")")
                }
                if !fetchedPages.isEmpty {
                    print("Fetched \(fetchedPages.count) pages for lesson \(lessonName) within \(subjectName).")
                } else {
                    print("No pages found for lesson \(lessonName) within \(subjectName).")
                }
            }
        } catch {
            print("Firestore query error: \(error.localizedDescription)")
        }
    }

    func fetchAllLessons(for subjectName: String) {
        print("Fetching all lessons for subject: \(subjectName)")
        let db = Firestore.firestore()
        db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments { [weak self] (subjectSnapshot, error) in
            guard let self = self, let subjectDocument = subjectSnapshot?.documents.first else {
                print("Subject \(subjectName) not found or error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            db.collection("Subjects").document(subjectDocument.documentID).collection("Lessons")
                .getDocuments { [weak self] (lessonSnapshot, error) in
                    if let error = error {
                        print("Error getting lessons for subject \(subjectName): \(error)")
                        return
                    }

                    guard let documents = lessonSnapshot?.documents, !documents.isEmpty else {
                        print("No lessons found for subject \(subjectName)")
                        DispatchQueue.main.async {
                            self?.currentSubjectLessons = []
                        }
                        return
                    }

                    let group = DispatchGroup()
                    var lessonsWithPages = [Lesson]()

                    for document in documents {
                        group.enter()
                        let lessonID = document.documentID
                        let lessonName = document.data()["name"] as? String ?? ""
                        db.collection("Subjects").document(subjectDocument.documentID).collection("Lessons").document(lessonID)
                            .collection("Pages").order(by: "pageNumber").getDocuments { (pageSnapshot, error) in
                                if let error = error {
                                    print("Error getting pages for lesson \(lessonName): \(error)")
                                    group.leave()
                                    return
                                }

                                let pages = pageSnapshot?.documents.compactMap { document -> Page? in
                                    guard let content = document.data()["content"] as? String,
                                          let pageNumber = document.data()["pageNumber"] as? Int,
                                          let readyButtonDisplayed = document.data()["readyButtonDisplayed"] as? Bool,
                                          let example = document.data()["example"] as? String,
                                          let graphics = document.data()["graphics"] as? String else {
                                        return nil
                                    }

                                    return Page(id: document.documentID, content: content, pageNumber: pageNumber, readyButtonDisplayed: readyButtonDisplayed, example: example, graphics: graphics)
                                } ?? []

                                let lesson = Lesson(id: lessonID,
                                                    name: lessonName,
                                                    description: document.data()["description"] as? String ?? "",
                                                    completed: document.data()["completed"] as? Bool ?? false,
                                                    lessonNumber: document.data()["lessonNumber"] as? Int ?? 1,
                                                    pages: pages)
                                lessonsWithPages.append(lesson)
                                group.leave()
                            }
                    }

                    group.notify(queue: .main) {
                        guard let strongSelf = self else {
                            print("ViewModel has been deallocated")
                            return
                        }

                        strongSelf.currentSubjectLessons = lessonsWithPages.sorted { $0.name < $1.name }
                        if let firstIncomplete = lessonsWithPages.first(where: { !$0.completed }) {
                            DispatchQueue.main.async {
                                strongSelf.currentLesson = firstIncomplete
                                strongSelf.currentLessonId = firstIncomplete.id ?? "default_id"  // Provide a default value
                                strongSelf.currentLessonName = firstIncomplete.name
                            }
                        }
                        print("Fetched all lessons and pages for subject \(strongSelf.subjectName)")
                    }
                }
        }
    }

    func fetchFirstIncompleteLesson(for subjectName: String) async -> (name: String, id: String) {
        let db = Firestore.firestore()
        let subjectsRef = db.collection("Subjects")

        do {
            let subjectSnapshot = try await subjectsRef.whereField("name", isEqualTo: subjectName).getDocuments()
            guard let subjectDocument = subjectSnapshot.documents.first else {
                print("Subject \(subjectName) not found.")
                return ("", "") // Return empty strings if the subject is not found
            }

            let lessonsRef = subjectsRef.document(subjectDocument.documentID).collection("Lessons")
            let lessonsSnapshot = try await lessonsRef.whereField("completed", isEqualTo: false).getDocuments()
            guard let firstIncompleteLessonDocument = lessonsSnapshot.documents.first else {
                print("No incomplete lessons found for \(subjectName).")
                return ("", "") // Return empty strings if no incomplete lesson is found
            }

            let id = firstIncompleteLessonDocument.documentID
            let name = firstIncompleteLessonDocument.data()["name"] as? String ?? "Unknown Name"

            DispatchQueue.main.async {
                self.currentLesson = Lesson(id: id, name: name, description: "", completed: false, lessonNumber: 0, pages: [])
                self.currentLessonId = id
                self.currentLessonName = name
            }

            return (name, id) // Return both name and id
        } catch {
            print("Error fetching lessons for \(subjectName): \(error)")
            return ("", "") // Return empty strings in case of an error
        }
    }

    // Custom function to format exponents
    private func formatExponentsInText(_ text: String) -> String {
        let exponentMappings: [String: String] = [
            "^2": "²", "^3": "³",
        ]

        var formattedText = text
        exponentMappings.forEach { exponent, superscript in
            formattedText = formattedText.replacingOccurrences(of: exponent, with: superscript)
        }
        return formattedText
    }

    func fetchLessons(for subjectName: String) {
        let db = Firestore.firestore()

        db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments { [weak self] (subjectSnapshot, error) in
            if let error = error {
                print("Error finding subject \(subjectName): \(error)")
                return
            }

            guard let subjectDocument = subjectSnapshot?.documents.first else {
                print("Subject \(subjectName) not found.")
                return
            }

            db.collection("Subjects").document(subjectDocument.documentID).collection("Lessons")
                .getDocuments { [weak self] (lessonsSnapshot, error) in
                    if let error = error {
                        print("Error getting lessons for subject \(subjectName): \(error)")
                        return
                    }

                    DispatchQueue.main.async {
                        self?.lessons = lessonsSnapshot?.documents.compactMap { document -> Lesson in
                            let name = document.data()["name"] as? String ?? ""
                            let description = document.data()["description"] as? String ?? ""
                            let completed = document.data()["completed"] as? Bool ?? false
                            let lessonNumber = document.data()["lessonNumber"] as? Int ?? 1
                            let id = document.documentID

                            return Lesson(id: id,
                                          name: name,
                                          description: description,
                                          completed: completed,
                                          lessonNumber: lessonNumber)
                        } ?? []

                        if let lessons = self?.lessons, !lessons.isEmpty {
                            print("Fetched \(lessons.count) lessons for subject \(subjectName)")
                        } else {
                            print("No lessons found for subject \(subjectName)")
                        }
                    }
                }
        }
    }
    
    @MainActor
    func navigateToPage(lessonName: String, pageNumber: Int, authVM: AuthViewModel) {
        print("navigateToPage called with lessonName: '\(lessonName)', pageNumber: \(pageNumber)")
        
        if let currentLesson = self.currentLesson, currentLesson.name == lessonName {
            print("Current lesson pages: \(currentLesson.pages?.map { $0.pageNumber } ?? [])")
            if let pageIndex = currentLesson.pages?.firstIndex(where: { $0.pageNumber == pageNumber }) {
                DispatchQueue.main.async {
                    self.currentPageIndex = pageIndex
                    self.currentPageDocumentId = currentLesson.pages?[pageIndex].id
                    print("Navigated to page \(pageNumber) of lesson \(lessonName), document ID: \(self.currentPageDocumentId ?? "N/A")")
                    self.updateBookmarkStatus(authVM: authVM)
                }
            } else {
                print("Page number \(pageNumber) not found in lesson \(lessonName).")
            }
        } else {
            print("Current lesson is not set or lesson name mismatch.")
        }
    }
    
    @MainActor
    func updateBookmarkStatus(authVM: AuthViewModel) {
        if let lessonId = currentLesson?.id, let pageId = currentPageDocumentId {
            self.isCurrentPageBookmarked = authVM.isPageBookmarked(subjectId: self.subjectName, lessonId: lessonId, pageId: pageId)
            print("Updated bookmark status: \(self.isCurrentPageBookmarked)")
        }
    }

    @MainActor
    func toggleBookmark(authVM: AuthViewModel) {
        if let lessonId = currentLesson?.id, let pageId = currentPageDocumentId {
            // Check if the current page is already bookmarked
            if authVM.isPageBookmarked(subjectId: subjectName, lessonId: lessonId, pageId: pageId) {
                // If bookmarked, clear the bookmark
                authVM.clearPreviousBookmark(subjectId: subjectName, lessonId: lessonId)
            } else {
                // Toggle the new bookmark
                authVM.toggleBookmark(subjectId: subjectName, lessonId: lessonId, pageId: pageId)
            }
            // Update the bookmark status
            updateBookmarkStatus(authVM: authVM)
        }
    }
}


