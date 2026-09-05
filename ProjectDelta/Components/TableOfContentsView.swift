//
//  TableOfContentsView.swift
//  ProjectDelta
//

import SwiftUI

struct TableOfContentsView: View {
    var lessonVM: LessonViewModel
    let subjectName: String
    @Binding var isShowing: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(AuthViewModel.self) var authVM

    @State private var selectedTab: Int = 0 // 0 = Curriculum, 1 = Bookmarks
    @State private var searchText: String = ""

    // MARK: - Dynamic Theme Mapping
    private var themeColor: Color {
        let lowerName = subjectName.lowercased()
        if lowerName.contains("geometry") || lowerName.contains("trigonometry") {
            return .purple
        } else if lowerName.contains("advanced") {
            return .orange
        } else if lowerName.contains("problem") || lowerName.contains("data") || lowerName.contains("statistics") {
            return .pink
        } else if lowerName.contains("arithmetic") {
            return .cyan
        } else {
            return .teal
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
                .opacity(0.5)
            
            List {
                if selectedTab == 0 {
                    curriculumView
                } else {
                    bookmarksView
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            #endif
        }
        #if os(macOS)
        .background(.thinMaterial)
        #endif
    }
    
    // MARK: - Header View
        
    private var headerView: some View {
        VStack(spacing: 24) {
            // Top Bar: Titles and Close Button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TABLE OF CONTENTS")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .tracking(1.5)
                    
                    Text(subjectName)
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(themeColor.gradient)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                Button(action: { isShowing = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
            // Controls: Picker and Search
            VStack(spacing: 16) {
                Picker("View Mode", selection: $selectedTab) {
                    Text("Curriculum").tag(0)
                    Text("Bookmarks").tag(1)
                }
                .pickerStyle(.segmented)
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField("Search lessons and pages...", text: $searchText)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation(.spring) { searchText = "" }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
#if os(iOS)
        .background(Color(uiColor: .systemGroupedBackground))
#else
        .background(Color.clear)
#endif
    }
    
    // MARK: - Curriculum View
    
    private var curriculumView: some View {
        let enumerated = Array(zip(lessonVM.currentSubjectLessons.indices, lessonVM.currentSubjectLessons))
        let filtered = filteredEnumeratedLessons(from: enumerated)
        
        return ForEach(filtered, id: \.1.id) { index, lesson in
            DisclosureGroup {
                if let pages = lesson.pages, !pages.isEmpty {
                    ForEach(pages, id: \.id) { page in
                        pageRow(lesson: lesson, page: page)
                    }
                } else {
                    Text("No pages available.")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                }
            } label: {
                lessonLabel(lesson: lesson, index: index)
            }
            .tint(.primary)
            .listRowSeparator(.hidden)
            #if os(iOS)
            .listRowBackground(Color.clear)
            #endif
        }
    }
    
    // MARK: - Bookmarks View
    
    private var bookmarksView: some View {
        let filteredBookmarks = filteredEnumeratedLessons(from: computedBookmarkedLessons)
        
        return Group {
            if filteredBookmarks.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Bookmarks" : "No Results",
                    systemImage: searchText.isEmpty ? "bookmark.slash" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Pages you bookmark will appear here." : "Check the spelling or try a new search.")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredBookmarks, id: \.1.id) { index, lesson in
                    Section {
                        if let pages = lesson.pages {
                            ForEach(pages, id: \.id) { page in
                                pageRow(lesson: lesson, page: page)
                            }
                        }
                    } header: {
                        lessonLabel(lesson: lesson, index: index)
                            .textCase(nil)
                            .padding(.top, 8)
                    }
                    .listRowSeparator(.hidden)
                    #if os(iOS)
                    .listRowBackground(Color.clear)
                    #endif
                }
            }
        }
    }
    
    // MARK: - Computed Properties for Efficiency
    
    /// Pre-calculates bookmarked lessons while retaining their absolute curriculum index
    private var computedBookmarkedLessons: [(Int, Lesson)] {
        let enumerated = Array(zip(lessonVM.currentSubjectLessons.indices, lessonVM.currentSubjectLessons))
        
        return enumerated.compactMap { index, lesson -> (Int, Lesson)? in
            guard let pages = lesson.pages else { return nil }
            
            let bPages = pages.filter { page in
                guard let lessonId = lesson.id, let pageId = page.id else { return false }
                return authVM.isPageBookmarked(subjectId: subjectName, lessonId: lessonId, pageId: pageId)
            }
            
            if bPages.isEmpty { return nil }
            var modifiedLesson = lesson
            modifiedLesson.pages = bPages
            return (index, modifiedLesson)
        }
    }
    
    // MARK: - Helper Views & Methods
        
    private func lessonLabel(lesson: Lesson, index: Int) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // Premium Rounded Rectangle Badge
            Text("\(index + 1)")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(lesson.completed ? .white : themeColor)
                .frame(width: 44, height: 44)
                .background(
                    lesson.completed ? Color.green.gradient : themeColor.opacity(0.12).gradient,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(lesson.completed ? Color.clear : themeColor.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: lesson.completed ? Color.green.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                // Fixed wrap alignment for dynamic text to never truncate
                Text(lesson.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor) // Inherits subject color
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !lesson.description.isEmpty && !lesson.description.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[{") {
                    Text(lesson.description)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.9))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            
            // Status Icon / Navigation Chevron
            if lesson.completed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(Color.green.gradient)
                    .symbolEffect(.bounce, value: lesson.completed)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            navigateTo(lesson: lesson, pageNumber: 1)
        }
    }
    
    private func pageRow(lesson: Lesson, page: Page) -> some View {
        let isBookmarked = (lesson.id != nil && page.id != nil) ? authVM.isPageBookmarked(subjectId: subjectName, lessonId: lesson.id!, pageId: page.id!) : false
        
        return Button(action: {
            navigateTo(lesson: lesson, pageNumber: page.pageNumber)
        }) {
            HStack(spacing: 14) {
                Image(systemName: "doc.plaintext.fill")
                    .foregroundStyle(themeColor.opacity(0.6))
                    .font(.body)
                
                Text("Page \(page.pageNumber)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(themeColor.opacity(0.9))
                
                Spacer()
                
                if isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(themeColor.gradient)
                        .font(.body)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Logic
    
    private func filteredEnumeratedLessons(from enumeratedLessons: [(Int, Lesson)]) -> [(Int, Lesson)] {
        guard !searchText.isEmpty else { return enumeratedLessons }
        
        return enumeratedLessons.filter { _, lesson in
            lesson.name.localizedCaseInsensitiveContains(searchText) ||
            lesson.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func navigateTo(lesson: Lesson, pageNumber: Int) {
        Task {
            await lessonVM.navigateToPage(lessonName: lesson.name, pageNumber: pageNumber, authVM: authVM)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowing = false
                }
            }
        }
    }
}
