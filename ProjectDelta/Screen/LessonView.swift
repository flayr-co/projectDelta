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
    @State private var showUIControls = true
    @State private var lastContentOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.customDarkGray : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showUIControls {
                    headerView
                        .transition(.opacity)
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
                                isInteractingWithExplanation: $isInteractingWithExplanation,
                                onBackgroundTap: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showUIControls.toggle()
                                    }
                                }
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTableOfContents = false
                        }
                    }
                
                TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName, isShowing: $showTableOfContents)
                    .frame(width: 320)
                    .background(colorScheme == .dark ? Color.customDarkGray : .white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 10)
                    .transition(.move(edge: .trailing))
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .overlay(alignment: .bottom) {
            if !lessonVM.lessonPages.isEmpty && showUIControls {
                lessonNavigationControls
                    .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            lessonVM.subjectName = subjectName
            await lessonVM.initializeLesson(subjectName: subjectName, authVM: authVM)
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(lessonVM.currentLessonName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showTableOfContents.toggle()
                        if showTableOfContents {
                            lessonVM.fetchAllLessons(for: subjectName)
                        }
                    }
                }) {
                    Image(systemName: "list.number")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .mint : .blue)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    lessonVM.toggleBookmark(authVM: authVM)
                }) {
                    Image(systemName: lessonVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(lessonVM.isCurrentPageBookmarked ? .blue : .secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(colorScheme == .dark ? Color.customDarkGray : .white)
    }

    private var lessonNavigationControls: some View {
        VStack {
            if lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1 {
                NavigationLink(destination: TestView(subject: subjectName)) {
                    Text("Take Quiz")
                        .font(.headline)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.cyan : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack {
                Button(action: {
                    withAnimation {
                        lessonVM.currentPageIndex = max(lessonVM.currentPageIndex - 1, 0)
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(lessonVM.currentPageIndex == 0)
                .opacity(lessonVM.currentPageIndex == 0 ? 0.3 : 1)

                Spacer()
                
                Text("\(lessonVM.currentPageIndex + 1) of \(lessonVM.lessonPages.count)")
                    .font(.footnote.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                Spacer()
                
                Button(action: {
                    withAnimation {
                        lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1)
                .opacity(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1 ? 0.3 : 1)
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 30)
        }
    }
}

struct LessonContentPage: View {
    let page: Page
    @Binding var isInteractingWithExplanation: Bool
    var onBackgroundTap: () -> Void
    
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
                        .buttonStyle(.plain)
                        .foregroundColor(.HuluGreen)
                        .frame(maxWidth: .infinity)

                        if isExplanationVisible {
                            ExampleView(text: explanationText)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                
                Spacer(minLength: 120)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onBackgroundTap()
            }
        }
        .scrollIndicators(.hidden)
    }
}

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
