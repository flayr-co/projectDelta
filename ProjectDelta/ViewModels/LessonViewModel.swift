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
    @Published var lessonPages: [Page] = []
    @Published var lessons: [Lesson] = []
    @Published var currentSubjectLessons: [Lesson] = []
    @Published var subjectName: String = ""
    @Published var currentPageIndex: Int = 0
    
    init(subjectName: String) {
        self.subjectName = subjectName
        fetchAllLessons(for: subjectName)
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
    
    func fetchFirstIncompleteLesson(for subjectName: String) async -> String {
        let db = Firestore.firestore()
        let subjectsRef = db.collection("Subjects")
        
        do {
            // Attempt to fetch the document ID for the subject
            let subjectSnapshot = try await subjectsRef.whereField("name", isEqualTo: subjectName).getDocuments()
            guard let subjectDocument = subjectSnapshot.documents.first else {
                print("Subject \(subjectName) not found.")
                return ""
            }
            
            // Fetch lessons within the subject
            let lessonsRef = subjectsRef.document(subjectDocument.documentID).collection("Lessons")
            let lessonsSnapshot = try await lessonsRef.whereField("completed", isEqualTo: false).getDocuments()
            
            // Get the first incomplete lesson
            guard let firstIncompleteLessonDocument = lessonsSnapshot.documents.first else {
                print("No incomplete lessons found for \(subjectName).")
                return ""
            }
            
            // Extract the lesson name
            return firstIncompleteLessonDocument.data()["name"] as? String ?? ""
        } catch {
            print("Error fetching lessons for \(subjectName): \(error)")
            return ""
        }
    }
    
    // Custom function to format exponents
    private func formatExponentsInText(_ text: String) -> String {
        // Define a dictionary of exponent mappings
        let exponentMappings: [String: String] = [
            "^2": "²", "^3": "³", // Add more mappings as needed
        ]

        var formattedText = text
        exponentMappings.forEach { exponent, superscript in
            formattedText = formattedText.replacingOccurrences(of: exponent, with: superscript)
        }
        return formattedText
    }
    
    func fetchLessons(for subjectName: String) {
        let db = Firestore.firestore()

        // Find the document ID for the subject named "Pre-Algebra"
        db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments { [weak self] (subjectSnapshot, error) in
            if let error = error {
                print("Error finding subject \(subjectName): \(error)")
                return
            }

            guard let subjectDocument = subjectSnapshot?.documents.first else {
                print("Subject \(subjectName) not found.")
                return
            }

            // Fetch all lessons within the "Pre-Algebra" subject
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

                            // Assuming Lesson is a struct with these properties
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
    
    // MARK: - New function to fetch all lessons for a subject
    func fetchAllLessons(for subjectName: String) {
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

                    // Fetch pages for each lesson and build a complete `Lesson` object including its pages
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
                                    
                                    // Log each page number here for debugging
                                    print("Fetched page number: \(pageNumber) for lesson \(lessonName)")
                                    
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
                        for lesson in lessonsWithPages {
                            // Use nil-coalescing to provide a default value in case pages is nil
                            let pageNumbers = lesson.pages?.map { $0.pageNumber } ?? []
                            print("Lesson: \(lesson.name), Pages: \(pageNumbers)")
                        }
                        guard let strongSelf = self else { return }
                        strongSelf.currentSubjectLessons = lessonsWithPages.sorted { $0.name < $1.name }
                        print("Fetched all lessons and pages for subject \(subjectName)")
                    }
                }
        }
    }
    
    // MARK: -  Function to navigate to a specific page in a lesson
    func navigateToPage(lessonName: String, pageNumber: Int) {
        print("navigateToPage called with lessonName: '\(lessonName)', pageNumber: \(pageNumber)")
        
        let db = Firestore.firestore()
        
        // Do not fetch the pages again if they are already loaded for the current lesson
        if let currentLesson = self.currentLesson, currentLesson.name == lessonName {
            // Use optional chaining and nil-coalescing to safely access pages
            let pageIndex = currentLesson.pages?.firstIndex(where: { $0.pageNumber == pageNumber }) ?? 0
            self.currentPageIndex = pageIndex
            print("Navigated to page \(pageNumber) of lesson \(lessonName)")
        } else {
            // Fetch the subject document based on the current subjectName
            db.collection("Subjects").whereField("name", isEqualTo: self.subjectName).getDocuments { [weak self] (subjectSnapshot, error) in
                guard let self = self else { return }

                if let error = error {
                    print("Error finding subject \(self.subjectName): \(error)")
                    return
                }

                guard let subjectDocument = subjectSnapshot?.documents.first else {
                    print("Subject \(self.subjectName) not found.")
                    return
                }

                // Fetch the lesson document within the subject based on the provided lessonName
                db.collection("Subjects").document(subjectDocument.documentID).collection("Lessons")
                    .whereField("name", isEqualTo: lessonName).getDocuments { [weak self] (lessonSnapshot, error) in
                        if let error = error {
                            print("Error getting lessons for subject \(self?.subjectName ?? ""): \(error)")
                            return
                        }

                        guard let lessonDocument = lessonSnapshot?.documents.first else {
                            print("Lesson \(lessonName) not found within \(self?.subjectName ?? "").")
                            return
                        }

                        // Fetch the pages for the specified lesson
                        db.collection("Subjects").document(subjectDocument.documentID)
                            .collection("Lessons").document(lessonDocument.documentID)
                            .collection("Pages").order(by: "pageNumber")
                            .getDocuments { [weak self] (pageSnapshot, error) in
                                if let error = error {
                                    print("Error getting pages for lesson \(lessonName): \(error)")
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

                                DispatchQueue.main.async {
                                    self?.lessonPages = pages
                                    if pages.isEmpty {
                                        print("No pages found for lesson \(lessonName) within \(self?.subjectName ?? "").")
                                    } else {
                                        print("Fetched \(pages.count) pages for lesson \(lessonName) within \(self?.subjectName ?? "").")
                                    }
                                }
                            }
                    }
            }
        }
    }
}


