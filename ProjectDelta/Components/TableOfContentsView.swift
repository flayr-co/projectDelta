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
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: {
                                expandedStates[lesson.id ?? ""] ?? (lessonVM.currentLesson?.id == lesson.id)
                            },
                            set: { newValue in
                                expandedStates[lesson.id ?? ""] = newValue
                            }
                        )
                    ) {
                        ForEach(lesson.pages ?? [], id: \.id) { page in
                            Button(action: {
                                Task {
                                    await lessonVM.fetchLessonContent(for: subjectName, lessonName: lesson.name)
                                    if let pageIndex = lesson.pages?.firstIndex(where: { $0.pageNumber == page.pageNumber }) {
                                        await MainActor.run {
                                            lessonVM.currentPageIndex = pageIndex
                                            lessonVM.currentLesson = lesson
                                            lessonVM.currentLessonName = lesson.name
                                            lessonVM.currentLessonId = lesson.id ?? ""
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                isShowing = false
                                            }
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Text("Page \(page.pageNumber)")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(isCurrentPage(lesson: lesson, page: page) ? (colorScheme == .dark ? .cyan : .blue) : .primary)
                                        .fontWeight(isCurrentPage(lesson: lesson, page: page) ? .semibold : .regular)
                                    Spacer()
                                    if isCurrentPage(lesson: lesson, page: page) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isCurrentPage(lesson: lesson, page: page))
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
    
    private func isCurrentPage(lesson: Lesson, page: Page) -> Bool {
        return lessonVM.currentLesson?.id == lesson.id && lessonVM.currentPageIndex == page.pageNumber - 1
    }
}

#Preview {
    let page1 = Page(id: "1", content: "Page 1 Content", pageNumber: 1, readyButtonDisplayed: false, example: nil, graphics: nil)
    let page2 = Page(id: "2", content: "Page 2 Content", pageNumber: 2, readyButtonDisplayed: false, example: nil, graphics: nil)
    let lesson = Lesson(id: "1", name: "Introduction", description: "", completed: false, lessonNumber: 1, pages: [page1, page2])
    
    let lessonVM = LessonViewModel()
    lessonVM.currentSubjectLessons = [lesson]
    lessonVM.currentLesson = lesson
    lessonVM.currentPageIndex = 0
    
    return TableOfContentsView(lessonVM: lessonVM, subjectName: "Pre-Algebra", isShowing: .constant(true))
}
