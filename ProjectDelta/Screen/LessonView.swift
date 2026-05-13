//
//  LessonView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI
import FirebaseCore

struct LessonView: View {
    var subjectName: String
    @Environment(LessonViewModel.self) var lessonVM
    @Environment(AuthViewModel.self) var authVM

    @State private var showTableOfContents = false
    @State private var isInteractingWithExplanation: Bool = false
    @State private var showHeader = true
    @State private var lastContentOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.customDarkGray : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showHeader {
                    headerView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if lessonVM.lessonPages.isEmpty {
                    Spacer()
                    ProgressView("Loading lesson content...")
                    Spacer()
                } else {
                    TabView(selection: Bindable(lessonVM).currentPageIndex) {
                        ForEach(lessonVM.lessonPages.indices, id: \.self) { index in
                            LessonContentPage(
                                page: lessonVM.lessonPages[index],
                                isInteractingWithExplanation: $isInteractingWithExplanation
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: lessonVM.currentPageIndex) { oldValue, newPageIndex in
                        if lessonVM.lessonPages.indices.contains(newPageIndex) {
                            let newPageNumber = lessonVM.lessonPages[newPageIndex].pageNumber
                            lessonVM.navigateToPage(lessonName: lessonVM.currentLessonName, pageNumber: newPageNumber, authVM: authVM)
                        }
                    }
                }
            }
            
            if showTableOfContents {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showTableOfContents = false }
                    }
                
                TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName)
                    .frame(width: 300)
                    .background(colorScheme == .dark ? Color.customDarkGray : .white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 10)
                    .transition(.move(edge: .trailing))
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .overlay(alignment: .bottom) {
            if !lessonVM.lessonPages.isEmpty {
                lessonNavigationControls
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            lessonVM.subjectName = subjectName
            await lessonVM.initializeLesson(subjectName: subjectName, authVM: authVM)
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            BackButtonView {
                dismiss()
            }

            Text(lessonVM.currentLessonName)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Button(action: {
                withAnimation(.spring()) {
                    showTableOfContents.toggle()
                    if showTableOfContents {
                        lessonVM.fetchAllLessons(for: subjectName)
                    }
                }
            }) {
                Image(systemName: "list.number")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .mint : .accentColor)
                    .padding(8)
                    .background(showTableOfContents ? Color.secondary.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button(action: {
                lessonVM.toggleBookmark(authVM: authVM)
            }) {
                Image(systemName: lessonVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(lessonVM.isCurrentPageBookmarked ? .accentColor : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(colorScheme == .dark ? Color.customDarkGray : .white)
    }

    private var lessonNavigationControls: some View {
        HStack {
            Button(action: {
                withAnimation {
                    lessonVM.currentPageIndex = max(lessonVM.currentPageIndex - 1, 0)
                }
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(colorScheme == .dark ? .mint : .accentColor)
            }
            .disabled(lessonVM.currentPageIndex == 0)
            .opacity(lessonVM.currentPageIndex == 0 ? 0.3 : 1)

            Spacer()
            
            Text("\(lessonVM.currentPageIndex + 1) of \(lessonVM.lessonPages.count)")
                .font(.footnote.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))

            Spacer()
            
            Button(action: {
                withAnimation {
                    lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
                }
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(colorScheme == .dark ? .mint : .accentColor)
            }
            .disabled(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1)
            .opacity(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1 ? 0.3 : 1)
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 30)
    }
}

// MARK: - LessonContentPage
struct LessonContentPage: View {
    let page: Page
    @Binding var isInteractingWithExplanation: Bool
    
    @State private var isExplanationVisible: Bool = false
    @Environment(LessonViewModel.self) var lessonVM
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TextStylingUtility.styledText(from: page.content)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)

                if let graphData = page.graphData {
                    DynamicGraphView(data: graphData)
                        .frame(height: 250)
                        .padding(.horizontal)
                }

                if let example = page.example, !example.isEmpty {
                    ExampleView(text: example)
                }

                if let explanationText = page.explanation, !explanationText.isEmpty {
                    VStack(spacing: 12) {
                        Button {
                            withAnimation(.spring()) {
                                isExplanationVisible.toggle()
                                isInteractingWithExplanation = isExplanationVisible
                            }
                        } label: {
                            HStack {
                                Image(systemName: isExplanationVisible ? "chevron.up.circle.fill" : "checkmark.seal.fill")
                                Text(isExplanationVisible ? "Hide explanation" : "See explanation")
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.HuluGreen.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .foregroundColor(.HuluGreen)
                        .frame(maxWidth: .infinity)

                        if isExplanationVisible {
                            ExampleView(text: explanationText)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                if page.readyButtonDisplayed {
                    VStack(spacing: 20) {
                        Button(action: {}) {
                            AnimatedActionButton()
                        }

                        NavigationLink {
                            PracticeTestView(
                                practiceTestViewModel: PracticeTestViewModel(authViewModel: AuthViewModel()),
                                lessonID: lessonVM.currentLessonId,
                                practiceTestID: "VYccqY1rjXETQOdMm4ap"
                            )
                        } label: {
                            Text("Go to test")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(colorScheme == .dark ? .cyan : .green)
                        }
                    }
                    .padding(.vertical, 30)
                }
                
                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - ExampleView
struct ExampleView: View {
    var text: String
    @Environment(\.colorScheme) var colorScheme

    var parsedContent: [(String, String)] {
        text.split(separator: "\n").map { line in
            let parts = line.split(separator: "||", maxSplits: 1, omittingEmptySubsequences: false)
            let example = String(parts[0])
            let explanation = parts.count > 1 ? String(parts[1]) : ""
            return (example, explanation)
        }
    }

    private func calculateHeight(for latex: String) -> CGFloat {
        let lineBreaks = latex.components(separatedBy: "\\\\").count - 1
        let hasFraction = latex.contains("\\frac")
        let baseHeight: CGFloat = 60
        let lineBreakHeight: CGFloat = 25 * CGFloat(lineBreaks)
        let fractionHeight: CGFloat = hasFraction ? 30 : 0
        return baseHeight + lineBreakHeight + fractionHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(parsedContent, id: \.0) { (example, explanation) in
                VStack(alignment: .leading, spacing: 8) {
                    if example.contains("$$") {
                        let latex = example
                            .replacingOccurrences(of: "$$", with: "")
                            .replacingOccurrences(of: "\\\\newline", with: "\\\\")
                        
                        let height = calculateHeight(for: latex)
                        
                        LatexView(latex: "$$\n\(latex)\n$$")
                            .frame(minHeight: height)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    } else {
                        TextStylingUtility.styledText(from: example)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }

                    if !explanation.isEmpty {
                        Text(explanation)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    LessonView(subjectName: "Algebra")
        .environment(LessonViewModel())
        .environment(AuthViewModel())
}
