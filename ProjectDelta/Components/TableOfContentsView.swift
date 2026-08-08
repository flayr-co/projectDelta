//
//  TableOfContentsView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 4/2/24.
//

import SwiftUI

struct TableOfContentsView: View {
    var lessonVM: LessonViewModel
    let subjectName: String
    @Binding var isShowing: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(AuthViewModel.self) var authVM

    @State private var selectedTab: Int = 0 // 0 = Curriculum, 1 = Bookmarks

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Table of Contents")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            Picker("View Mode", selection: $selectedTab) {
                Text("Curriculum").tag(0)
                Text("Bookmarks").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            Divider()
            
            List {
                if selectedTab == 0 {
                    curriculumView
                } else {
                    bookmarksView
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            .background(Color(uiColor: .systemGroupedBackground))
            #else
            .listStyle(.sidebar)
            .background(Color.clear)
            #endif
        }
    }
    
    // MARK: - Curriculum View
    
    private var curriculumView: some View {
        ForEach(lessonVM.currentSubjectLessons, id: \.id) { lesson in
            DisclosureGroup {
                if let pages = lesson.pages?.sorted(by: { $0.pageNumber < $1.pageNumber }), !pages.isEmpty {
                    // Safe enumeration masks incorrect pageNumber DB entries with accurate visual indexes
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        pageRow(lesson: lesson, page: page, displayIndex: index + 1)
                    }
                } else {
                    Text("No pages available.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            } label: {
                lessonLabel(lesson: lesson)
            }
#if os(iOS)
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
#else
            .listRowBackground(Color.platformSecondarySystemBackground.opacity(0.8))
#endif
        }
    }
    
    // MARK: - Bookmarks View
    
    private var bookmarksView: some View {
        let bookmarkedLessons = lessonVM.currentSubjectLessons.compactMap { lesson -> Lesson? in
            guard let pages = lesson.pages else { return nil }
            let bPages = pages.filter { page in
                guard let lessonId = lesson.id, let pageId = page.id else { return false }
                return authVM.isPageBookmarked(subjectId: subjectName, lessonId: lessonId, pageId: pageId)
            }
            
            if bPages.isEmpty { return nil }
            
            var modifiedLesson = lesson
            modifiedLesson.pages = bPages
            return modifiedLesson
        }
        
        return Group {
            if bookmarkedLessons.isEmpty {
                Text("No bookmarks saved yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(bookmarkedLessons, id: \.id) { lesson in
                    Section(header: Text(lesson.name).font(.headline)) {
                        if let pages = lesson.pages?.sorted(by: { $0.pageNumber < $1.pageNumber }) {
                            ForEach(pages, id: \.id) { page in
                                // Calculate accurate origin index to maintain display consistency
                                let originalIndex = lesson.pages?.sorted(by: { $0.pageNumber < $1.pageNumber }).firstIndex(where: { $0.id == page.id }) ?? 0
                                pageRow(lesson: lesson, page: page, displayIndex: originalIndex + 1)
                            }
                        }
                    }
                    #if os(iOS)
                    .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
                    #else
                    .listRowBackground(Color.platformSecondarySystemBackground.opacity(0.8))
                    #endif
                }
            }
        }
    }
    
    // MARK: - Helper Views & Methods
    
    private func lessonLabel(lesson: Lesson) -> some View {
        HStack(spacing: 16) {
            Image(systemName: lesson.completed ? "checkmark.circle.fill" : "book.closed.circle")
                .font(.title2)
                .foregroundStyle(lesson.completed ? Color.green.gradient : Color.blue.gradient)
                .symbolEffect(.bounce, value: lesson.completed)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                // Supress rendering of raw JSON payloads
                if !lesson.description.isEmpty && !lesson.description.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[{") {
                    Text(lesson.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        // Allow tapping the lesson header to jump to page 1 directly
        .onTapGesture {
            navigateTo(lesson: lesson, pageNumber: 1)
        }
    }
    
    private func pageRow(lesson: Lesson, page: Page, displayIndex: Int) -> some View {
        let isBookmarked = (lesson.id != nil && page.id != nil) ? authVM.isPageBookmarked(subjectId: subjectName, lessonId: lesson.id!, pageId: page.id!) : false
        
        return Button(action: {
            navigateTo(lesson: lesson, pageNumber: page.pageNumber)
        }) {
            HStack {
                // Force UI to use the enumerated index instead of the corrupted database field
                Text("Page \(displayIndex)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.teal)
                        .font(.subheadline)
                        .transition(.scale)
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, 32) // Indent pages under the lesson
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func navigateTo(lesson: Lesson, pageNumber: Int) {
        Task {
            // Wait for the ViewModel to complete its fetch and state updates for the specific page
            await lessonVM.navigateToPage(lessonName: lesson.name, pageNumber: pageNumber, authVM: authVM)
            
            // Confidently dismiss the Table of Contents
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowing = false
                }
            }
        }
    }
}

#Preview {
    let page1 = Page(content: "Intro", pageNumber: 1, readyButtonDisplayed: false)
    let page2 = Page(content: "Details", pageNumber: 2, readyButtonDisplayed: false)
    let lesson = Lesson(id: "test_id", name: "Linear Equations", description: "", completed: false, lessonNumber: 1, pages: [page1, page2])
    
    let vm = LessonViewModel()
    vm.currentSubjectLessons = [lesson]
    vm.currentLesson = lesson
    vm.currentPageIndex = 0
    
    return TableOfContentsView(lessonVM: vm, subjectName: "Algebra", isShowing: .constant(true))
        .environment(AuthViewModel())
}
