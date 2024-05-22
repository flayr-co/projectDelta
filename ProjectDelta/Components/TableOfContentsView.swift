//
//  TableOfContentsView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 4/2/24.
//

import SwiftUI

struct TableOfContentsView: View {
    @ObservedObject var lessonVM: LessonViewModel
    let subjectName: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            ForEach(lessonVM.currentSubjectLessons, id: \.id) { lesson in
                DisclosureGroup(lesson.name) {
                    // Use optional chaining with a default empty array to safely access pages
                    ForEach(lesson.pages ?? [], id: \.id) { page in
                        Button(action: {
                            Task {
                                await lessonVM.fetchLessonContent(for: subjectName, lessonName: lesson.name)
                                if let pageIndex = lesson.pages?.firstIndex(where: { $0.pageNumber == page.pageNumber }) {
                                    DispatchQueue.main.async {
                                        lessonVM.currentPageIndex = pageIndex
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Text("Page \(page.pageNumber)")
                                    .foregroundStyle(lessonVM.currentPageIndex == page.pageNumber - 1 ? colorScheme == .dark ? .cyan : .blue : .primary)
                                Spacer()
                                if lessonVM.currentPageIndex == page.pageNumber - 1 {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                                }
                            }
                        }
                        .disabled(lessonVM.currentPageIndex == page.pageNumber - 1)
                    }
                }
                
            }
            .listStyle(GroupedListStyle())
        }
    }
}

#Preview {
    let page1 = Page(id: "1", content: "Page 1 Content", pageNumber: 1, readyButtonDisplayed: false, example: nil, graphics: nil)
    let page2 = Page(id: "2", content: "Page 2 Content", pageNumber: 2, readyButtonDisplayed: false, example: nil, graphics: nil)
    let lesson = Lesson(id: "1", name: "Introduction", description: "", completed: false, lessonNumber: 1, pages: [page1, page2])
    
    let lessonVM = LessonViewModel()
    lessonVM.currentSubjectLessons = [lesson]
    
    return TableOfContentsView(lessonVM: lessonVM, subjectName: "Pre-Algebra")
        .preferredColorScheme(.dark)
}
