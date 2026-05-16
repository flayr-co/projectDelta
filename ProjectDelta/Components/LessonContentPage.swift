//
//  LessonContentPage.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI

// MARK: - LessonContentPage
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
                            .background(Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(red: 0.18, green: 0.80, blue: 0.44))
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
                        .buttonStyle(.plain)

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
                                .foregroundStyle(colorScheme == .dark ? .cyan : Color(red: 0.18, green: 0.80, blue: 0.44))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 30)
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
