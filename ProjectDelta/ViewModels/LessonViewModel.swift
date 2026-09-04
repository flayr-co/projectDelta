//
//  LessonViewModel.swift
//  ProjectDelta
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
    
    private let db = Firestore.firestore()
    private var contentListener: ListenerRegistration?
    private var curriculumListener: ListenerRegistration?
    private var pagesListener: ListenerRegistration?
    
    // MARK: - Core Initialization
    
    func initializeLesson(subjectName: String, authVM: AuthViewModel) async {
        self.isLoading = true
        defer { self.isLoading = false }
        
        self.fetchAllLessons(for: subjectName)
        
        print("Starting to fetch the first incomplete lesson for \(subjectName).")
        let (lessonName, lessonId) = await fetchFirstIncompleteLesson(for: subjectName)
        
        if !lessonName.isEmpty {
            self.currentLessonName = lessonName
            self.currentLessonId = lessonId
            print("First lesson fetched: \(lessonName) with ID \(lessonId)")
            
            await fetchLessonContent(for: subjectName, lessonName: lessonName)
            
            if let initialPageNumber = self.lessonPages.first?.pageNumber {
                await self.navigateToPage(lessonName: lessonName, pageNumber: initialPageNumber, authVM: authVM)
            }
        } else {
            print("No lesson found or fetch failed for subject \(subjectName).")
            self.lessonPages = []
        }
    }
    
    // MARK: - Ghost Subject Resolver
    
    private func resolveSubjectId(for subjectName: String) async -> String? {
        var candidates = [String]()
        
        if let doc = try? await db.collection("Subjects").document(subjectName).getDocument(), doc.exists {
            candidates.append(doc.documentID)
        }
        if let querySnap = try? await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments() {
            candidates.append(contentsOf: querySnap.documents.map { $0.documentID })
        }
        
        var uniqueCandidates = [String]()
        for c in candidates where !uniqueCandidates.contains(c) {
            uniqueCandidates.append(c)
        }
        
        for id in uniqueCandidates {
            if let lessonsSnap = try? await db.collection("Subjects").document(id).collection("Lessons").limit(to: 5).getDocuments() {
                for lessonDoc in lessonsSnap.documents {
                    let pages = try? await db.collection("Subjects").document(id).collection("Lessons").document(lessonDoc.documentID).collection("Pages").limit(to: 1).getDocuments()
                    if pages?.isEmpty == false { return id }
                    
                    let lowerPages = try? await db.collection("Subjects").document(id).collection("Lessons").document(lessonDoc.documentID).collection("pages").limit(to: 1).getDocuments()
                    if lowerPages?.isEmpty == false { return id }
                }
            }
        }
        
        for id in uniqueCandidates {
            let lessonsSnap = try? await db.collection("Subjects").document(id).collection("Lessons").limit(to: 1).getDocuments()
            if lessonsSnap?.isEmpty == false { return id }
        }
        
        return uniqueCandidates.first
    }
    
    // MARK: - Fetch Logic
    
    func fetchLessonContent(for subjectName: String, lessonName: String) async {
        guard let subjectId = await resolveSubjectId(for: subjectName) else {
            print("Error: Subject \(subjectName) not found.")
            return
        }
        
        contentListener?.remove()
        
        let query = db.collection("Subjects").document(subjectId).collection("Lessons").whereField("name", isEqualTo: lessonName)
        
        contentListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let lessonDocument = snapshot?.documents.first,
                  var lesson = try? lessonDocument.data(as: Lesson.self) else { return }
            
            lesson.id = lessonDocument.documentID
            
            if let embeddedPages = lesson.pages, !embeddedPages.isEmpty {
                let rawPages = embeddedPages.sorted { $0.pageNumber < $1.pageNumber }
                self.applyCleanedPages(rawPages, to: lesson)
            } else {
                self.pagesListener?.remove()
                self.pagesListener = self.db.collection("Subjects").document(subjectId)
                    .collection("Lessons").document(lessonDocument.documentID)
                    .collection("Pages").order(by: "pageNumber")
                    .addSnapshotListener { pageSnapshot, _ in
                        let rawPages = pageSnapshot?.documents.compactMap { try? $0.data(as: Page.self) } ?? []
                        self.applyCleanedPages(rawPages, to: lesson)
                    }
            }
        }
    }
    
    private func applyCleanedPages(_ rawPages: [Page], to lesson: Lesson) {
        var mutableLesson = lesson
        let cleanedPages = rawPages.enumerated().map { index, page in
            var p = page
            // Retain original ID or use a deterministic string instead of a randomized UUID to prevent SwiftUI layout thrashing
            if p.id == nil { p.id = "page_\(index)" }
            p.pageNumber = index + 1
            return p
        }
        
        self.lessonPages = cleanedPages
        mutableLesson.pages = cleanedPages
        self.currentLesson = mutableLesson
        self.currentLessonId = mutableLesson.id ?? ""
        self.currentLessonName = mutableLesson.name
    }
    
    func fetchAllLessons(for subjectName: String) {
        Task {
            guard let subjectId = await resolveSubjectId(for: subjectName) else { return }
            
            curriculumListener?.remove()
            
            let query = db.collection("Subjects").document(subjectId).collection("Lessons")
            
            curriculumListener = query.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                Task {
                    var lessonsWithPages = [Lesson]()
                    
                    for document in documents {
                        guard var lesson = try? document.data(as: Lesson.self) else { continue }
                        lesson.id = document.documentID
                        var rawPages: [Page] = []
                        
                        if let embeddedPages = lesson.pages, !embeddedPages.isEmpty {
                            rawPages = embeddedPages.sorted { $0.pageNumber < $1.pageNumber }
                        } else {
                            var pageSnapshot = try? await self.db.collection("Subjects").document(subjectId)
                                .collection("Lessons").document(lesson.id!)
                                .collection("Pages").order(by: "pageNumber").getDocuments()
                            
                            if pageSnapshot?.isEmpty == true {
                                pageSnapshot = try? await self.db.collection("Subjects").document(subjectId)
                                    .collection("Lessons").document(lesson.id!)
                                    .collection("pages").order(by: "pageNumber").getDocuments()
                            }
                            
                            rawPages = pageSnapshot?.documents.compactMap { try? $0.data(as: Page.self) } ?? []
                        }
                        
                        lesson.pages = rawPages.enumerated().map { index, page in
                            var p = page
                            if p.id == nil { p.id = "page_\(lesson.id ?? "")_\(index)" }
                            p.pageNumber = index + 1
                            return p
                        }
                        
                        lessonsWithPages.append(lesson)
                    }
                    
                    self.currentSubjectLessons = lessonsWithPages.sorted { $0.lessonNumber < $1.lessonNumber }
                }
            }
        }
    }
    
    func fetchFirstIncompleteLesson(for subjectName: String) async -> (name: String, id: String) {
        do {
            guard let subjectId = await resolveSubjectId(for: subjectName) else { return ("", "") }
            
            let lessonsRef = db.collection("Subjects").document(subjectId).collection("Lessons")
            let lessonsSnapshot = try await lessonsRef.whereField("completed", isEqualTo: false).getDocuments()
            
            let documentToUse: QueryDocumentSnapshot
            
            let sortedIncompleteLessons = lessonsSnapshot.documents.sorted {
                let num1 = $0.data()["lessonNumber"] as? Int ?? Int.max
                let num2 = $1.data()["lessonNumber"] as? Int ?? Int.max
                return num1 < num2
            }
            
            if let firstIncomplete = sortedIncompleteLessons.first {
                documentToUse = firstIncomplete
            } else {
                let fallbackSnapshot = try await lessonsRef.getDocuments()
                let sortedAllLessons = fallbackSnapshot.documents.sorted {
                    let num1 = $0.data()["lessonNumber"] as? Int ?? Int.max
                    let num2 = $1.data()["lessonNumber"] as? Int ?? Int.max
                    return num1 < num2
                }
                guard let fallbackDocument = sortedAllLessons.first else { return ("", "") }
                documentToUse = fallbackDocument
            }
            
            let id = documentToUse.documentID
            let name = documentToUse.data()["name"] as? String ?? "Unknown Name"
            
            self.currentLesson = Lesson(id: id, name: name, description: "", completed: false, lessonNumber: 0, pages: [])
            self.currentLessonId = id
            self.currentLessonName = name
            
            return (name, id)
        } catch {
            return ("", "")
        }
    }
    
    // MARK: - Navigation
    
    @MainActor
    func navigateToPage(lessonName: String, pageNumber: Int, authVM: AuthViewModel) async {
        if let currentLesson = self.currentLesson, currentLesson.name == lessonName {
            if let pageIndex = currentLesson.pages?.firstIndex(where: { $0.pageNumber == pageNumber }) {
                self.currentPageIndex = pageIndex
                self.currentPageDocumentId = currentLesson.pages?[pageIndex].id
                self.updateBookmarkStatus(authVM: authVM)
            }
        } else {
            self.currentLessonName = lessonName
            
            await fetchLessonContent(for: self.subjectName, lessonName: lessonName)
            
            if let pageIndex = self.lessonPages.firstIndex(where: { $0.pageNumber == pageNumber }) {
                self.currentPageIndex = pageIndex
                self.currentPageDocumentId = self.lessonPages[pageIndex].id
                self.updateBookmarkStatus(authVM: authVM)
            } else {
                self.currentPageIndex = 0
                self.currentPageDocumentId = self.lessonPages.first?.id
                self.updateBookmarkStatus(authVM: authVM)
            }
        }
    }
    
    // MARK: - Lesson Progression
    
    @MainActor
    func advanceToNextLesson(authVM: AuthViewModel) async {
        guard let currentIndex = currentSubjectLessons.firstIndex(where: { $0.id == currentLessonId }),
              currentIndex + 1 < currentSubjectLessons.count else { return }
        
        let nextLesson = currentSubjectLessons[currentIndex + 1]
        await navigateToPage(lessonName: nextLesson.name, pageNumber: 1, authVM: authVM)
    }
    
    // MARK: - Bookmarks
    
    func updateBookmarkStatus(authVM: AuthViewModel) {
        if let lessonId = currentLesson?.id, let pageId = currentPageDocumentId {
            self.isCurrentPageBookmarked = authVM.isPageBookmarked(subjectId: self.subjectName, lessonId: lessonId, pageId: pageId)
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
