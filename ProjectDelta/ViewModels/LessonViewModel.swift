//
//  LessonViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/11/24.
//

import Foundation
import FirebaseFirestore
import Observation
import SwiftUI

@MainActor
@Observable
class LessonViewModel {
    var currentLesson: Lesson?
    var currentLessonName: String = ""
    var currentLessonId: String = ""
    var lessonPages: [Page] = []
    var lessons: [Lesson] = []
    var currentSubjectLessons: [Lesson] = []
    var subjectName: String = ""
    var currentPageIndex: Int = 0
    var currentPageDocumentId: String?
    var isLoading: Bool = true
    var isCurrentPageBookmarked: Bool = false

    func initializeLesson(subjectName: String, authVM: AuthViewModel) async {
        print("Starting to fetch the first incomplete lesson for \(subjectName).")
        let (lessonName, lessonId) = await fetchFirstIncompleteLesson(for: subjectName)
        
        if !lessonName.isEmpty {
            self.currentLessonName = lessonName
            self.currentLessonId = lessonId
            print("First incomplete lesson fetched: \(lessonName) with ID \(lessonId)")
            
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
            guard !subjectQuerySnapshot.isEmpty else {
                print("Subject \(subjectName) not found.")
                return
            }
            
            // Auto-detect the correct legacy document by verifying the presence of a Lessons subcollection
            var targetSubjectID = subjectQuerySnapshot.documents.first!.documentID
            for doc in subjectQuerySnapshot.documents {
                let lessonCheck = try await db.collection("Subjects").document(doc.documentID).collection("Lessons").limit(to: 1).getDocuments()
                if !lessonCheck.isEmpty {
                    targetSubjectID = doc.documentID
                    break
                }
            }
            
            let lessonQuerySnapshot = try await db.collection("Subjects").document(targetSubjectID)
                .collection("Lessons").whereField("name", isEqualTo: lessonName).getDocuments()
            guard let lessonDocument = lessonQuerySnapshot.documents.first else {
                print("Lesson \(lessonName) not found within \(subjectName).")
                return
            }
            
            let pagesQuerySnapshot = try await db.collection("Subjects").document(targetSubjectID)
                .collection("Lessons").document(lessonDocument.documentID)
                .collection("Pages").order(by: "pageNumber").getDocuments()
            
            let fetchedPages = pagesQuerySnapshot.documents.compactMap { document -> Page? in
                do {
                    let page = try document.data(as: Page.self)
                    print("Fetched page: \(page.pageNumber) with ID: \(page.id ?? "N/A")")
                    print("Page graphData: \(page.graphData?.xValues ?? []), \(page.graphData?.yValues ?? [])")
                    return page
                } catch {
                    print("Error decoding page: \(error.localizedDescription)")
                    return nil
                }
            }
            
            self.lessonPages = fetchedPages
            self.currentLesson?.pages = fetchedPages  // Set the pages for the current lesson
            if !fetchedPages.isEmpty {
                print("Fetched \(fetchedPages.count) pages for lesson \(lessonName) within \(subjectName).")
            } else {
                print("No pages found for lesson \(lessonName) within \(subjectName).")
            }
            
        } catch {
            print("Firestore query error: \(error.localizedDescription)")
        }
    }

    func fetchAllLessons(for subjectName: String) {
        print("Fetching all lessons for subject: \(subjectName)")
        Task {
            let db = Firestore.firestore()
            do {
                let subjectSnapshot = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
                guard !subjectSnapshot.isEmpty else {
                    print("Subject \(subjectName) not found")
                    return
                }
                
                var targetSubjectID = subjectSnapshot.documents.first!.documentID
                for doc in subjectSnapshot.documents {
                    let lessonCheck = try await db.collection("Subjects").document(doc.documentID).collection("Lessons").limit(to: 1).getDocuments()
                    if !lessonCheck.isEmpty {
                        targetSubjectID = doc.documentID
                        break
                    }
                }
                
                let lessonSnapshot = try await db.collection("Subjects").document(targetSubjectID).collection("Lessons").getDocuments()
                
                guard !lessonSnapshot.isEmpty else {
                    print("No lessons found for subject \(subjectName)")
                    self.currentSubjectLessons = []
                    return
                }
                
                var lessonsWithPages = [Lesson]()
                
                for document in lessonSnapshot.documents {
                    let lessonID = document.documentID
                    let lessonName = document.data()["name"] as? String ?? ""
                    let lessonNumber = document.data()["lessonNumber"] as? Int ?? 0
                    
                    let pageSnapshot = try? await db.collection("Subjects").document(targetSubjectID).collection("Lessons").document(lessonID).collection("Pages").order(by: "pageNumber").getDocuments()
                    
                    let pages = pageSnapshot?.documents.compactMap { doc -> Page? in
                        guard let content = doc.data()["content"] as? String,
                              let pageNumber = doc.data()["pageNumber"] as? Int,
                              let readyButtonDisplayed = doc.data()["readyButtonDisplayed"] as? Bool else {
                            return nil
                        }
                        return Page(id: doc.documentID, content: content, pageNumber: pageNumber, readyButtonDisplayed: readyButtonDisplayed)
                    } ?? []
                    
                    let lesson = Lesson(id: lessonID,
                                        name: lessonName,
                                        description: document.data()["description"] as? String ?? "",
                                        completed: document.data()["completed"] as? Bool ?? false,
                                        lessonNumber: lessonNumber,
                                        pages: pages)
                    lessonsWithPages.append(lesson)
                }
                
                self.currentSubjectLessons = lessonsWithPages.sorted { $0.lessonNumber < $1.lessonNumber }
                if let firstIncomplete = lessonsWithPages.first(where: { !$0.completed }) {
                    self.currentLesson = firstIncomplete
                    self.currentLessonId = firstIncomplete.id ?? "default_id"
                    self.currentLessonName = firstIncomplete.name
                }
                print("Fetched all lessons and pages for subject \(subjectName)")
                
            } catch {
                print("Error getting lessons for subject \(subjectName): \(error)")
            }
        }
    }

    func fetchFirstIncompleteLesson(for subjectName: String) async -> (name: String, id: String) {
        let db = Firestore.firestore()
        let subjectsRef = db.collection("Subjects")
        
        do {
            let subjectSnapshot = try await subjectsRef.whereField("name", isEqualTo: subjectName).getDocuments()
            guard !subjectSnapshot.isEmpty else {
                print("Subject \(subjectName) not found.")
                return ("", "")
            }
            
            var targetSubjectID = subjectSnapshot.documents.first!.documentID
            for doc in subjectSnapshot.documents {
                let check = try await subjectsRef.document(doc.documentID).collection("Lessons").limit(to: 1).getDocuments()
                if !check.isEmpty {
                    targetSubjectID = doc.documentID
                    break
                }
            }
            
            let lessonsRef = subjectsRef.document(targetSubjectID).collection("Lessons")
            let lessonsSnapshot = try await lessonsRef.order(by: "lessonNumber").whereField("completed", isEqualTo: false).getDocuments()
            guard let firstIncompleteLessonDocument = lessonsSnapshot.documents.first else {
                print("No incomplete lessons found for \(subjectName).")
                return ("", "")
            }
            
            let id = firstIncompleteLessonDocument.documentID
            let name = firstIncompleteLessonDocument.data()["name"] as? String ?? "Unknown Name"
            
            self.currentLesson = Lesson(id: id, name: name, description: "", completed: false, lessonNumber: 0, pages: [])
            self.currentLessonId = id
            self.currentLessonName = name
            
            return (name, id)
        } catch {
            print("Error fetching lessons for \(subjectName): \(error)")
            return ("", "")
        }
    }

    func navigateToPage(lessonName: String, pageNumber: Int, authVM: AuthViewModel) {
        print("navigateToPage called with lessonName: '\(lessonName)', pageNumber: \(pageNumber)")

        if let currentLesson = self.currentLesson, currentLesson.name == lessonName {
            if let pageIndex = currentLesson.pages?.firstIndex(where: { $0.pageNumber == pageNumber }) {
                self.currentPageIndex = pageIndex
                self.currentPageDocumentId = currentLesson.pages?[pageIndex].id
                print("Navigated to page \(pageNumber) of lesson \(lessonName), document ID: \(self.currentPageDocumentId ?? "N/A")")
                self.updateBookmarkStatus(authVM: authVM)
                print("Current page content: \(currentLesson.pages?[pageIndex].content ?? "No content")")
                print("Current page graph data: \(currentLesson.pages?[pageIndex].graphData?.xValues ?? []), \(currentLesson.pages?[pageIndex].graphData?.yValues ?? [])")
            } else {
                print("Page number \(pageNumber) not found in lesson \(lessonName).")
            }
        } else {
            Task {
                await fetchLessonContent(for: self.subjectName, lessonName: lessonName)
                if let newLesson = self.currentSubjectLessons.first(where: { $0.name == lessonName }) {
                    self.currentLesson = newLesson
                    if let pageIndex = newLesson.pages?.firstIndex(where: { $0.pageNumber == pageNumber }) {
                        self.currentPageIndex = pageIndex
                        self.currentPageDocumentId = newLesson.pages?[pageIndex].id
                        print("Navigated to page \(pageNumber) of lesson \(lessonName), document ID: \(self.currentPageDocumentId ?? "N/A")")
                        self.updateBookmarkStatus(authVM: authVM)
                        print("Current page content: \(newLesson.pages?[pageIndex].content ?? "No content")")
                        print("Current page graph data: \(newLesson.pages?[pageIndex].graphData?.xValues ?? []), \(newLesson.pages?[pageIndex].graphData?.yValues ?? [])")
                    } else {
                        print("Page number \(pageNumber) not found in lesson \(lessonName).")
                    }
                }
            }
        }
    }
    
    // MARK: - BOOKMARKS
    func updateBookmarkStatus(authVM: AuthViewModel) {
        if let lessonId = currentLesson?.id, let pageId = currentPageDocumentId {
            self.isCurrentPageBookmarked = authVM.isPageBookmarked(subjectId: self.subjectName, lessonId: lessonId, pageId: pageId)
            print("Updated bookmark status: \(self.isCurrentPageBookmarked)")
        }
    }

    func toggleBookmark(authVM: AuthViewModel) {
        if let lessonId = currentLesson?.id, let pageId = currentPageDocumentId {
            if authVM.isPageBookmarked(subjectId: subjectName, lessonId: lessonId, pageId: pageId) {
                authVM.clearPreviousBookmark(subjectId: subjectName, lessonId: lessonId)
            } else {
                authVM.toggleBookmark(subjectId: subjectName, lessonId: lessonId, pageId: pageId)
            }
            updateBookmarkStatus(authVM: authVM)
        }
    }
}
