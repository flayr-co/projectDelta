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
    @State private var expandedStates: [String: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Table of Contents")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            Divider()
            
            List {
                ForEach(lessonVM.currentSubjectLessons, id: \.id) { lesson in
                    let lessonId = lesson.id ?? ""
                    
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedStates[lessonId] ?? (lessonVM.currentLesson?.id == lesson.id) },
                            set: { val in expandedStates[lessonId] = val }
                        )
                    ) {
                        if let pages = lesson.pages {
                            ForEach(pages, id: \.pageNumber) { page in
                                pageRow(lesson: lesson, page: page)
                            }
                        }
                    } label: {
                        Text(lesson.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .tint(colorScheme == .dark ? .cyan : .blue)
                }
            }
            .listStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func pageRow(lesson: Lesson, page: Page) -> some View {
        let isActive = isCurrentPage(lesson: lesson, page: page)
        
        Button(action: {
            navigateToPage(lesson: lesson, page: page)
        }) {
            HStack {
                Text("Page \(page.pageNumber)")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(isActive ? (colorScheme == .dark ? .cyan : .blue) : .primary)
                    .fontWeight(isActive ? .semibold : .regular)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isActive)
    }
    
    private func navigateToPage(lesson: Lesson, page: Page) {
        Task {
            await MainActor.run {
                lessonVM.navigateToPage(lessonName: lesson.name, pageNumber: page.pageNumber, authVM: authVM)
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowing = false
                }
            }
        }
    }
    
    private func isCurrentPage(lesson: Lesson, page: Page) -> Bool {
        guard let current = lessonVM.currentLesson else { return false }
        return current.id == lesson.id && lessonVM.currentPageIndex == (page.pageNumber - 1)
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
