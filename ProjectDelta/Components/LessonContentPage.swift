//
//  LessonContentPage.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI
import Charts

// MARK: - Parsed Content Models
struct ParsedContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType

    enum BlockType {
        case text(String)
        case math(String)
        case graph(String)
    }
}

// MARK: - LessonContentPage
struct LessonContentPage: View {
    let page: Page
    @Binding var isInteractingWithExplanation: Bool
    var onBackgroundTap: () -> Void
    
    @State private var isExplanationVisible: Bool = false
    @Environment(LessonViewModel.self) var lessonVM
    @Environment(\.colorScheme) var colorScheme
    
    // Core Parser Engine: Breaks down the single source-of-truth string into modular SwiftUI views.
    var parsedBlocks: [ParsedContentBlock] {
        var blocks: [ParsedContentBlock] = []
        var remaining = page.content

        while !remaining.isEmpty {
            let mathRange = remaining.range(of: "[MATH]")
            let graphRange = remaining.range(of: "[GRAPH]")

            var nextTagRange: Range<String.Index>?
            var isMath = false

            if let m = mathRange, let g = graphRange {
                if m.lowerBound < g.lowerBound {
                    nextTagRange = m
                    isMath = true
                } else {
                    nextTagRange = g
                    isMath = false
                }
            } else if let m = mathRange {
                nextTagRange = m
                isMath = true
            } else if let g = graphRange {
                nextTagRange = g
                isMath = false
            }

            guard let startTag = nextTagRange else {
                let text = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(ParsedContentBlock(type: .text(text)))
                }
                break
            }

            let textBefore = String(remaining[..<startTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !textBefore.isEmpty {
                blocks.append(ParsedContentBlock(type: .text(textBefore)))
            }

            remaining = String(remaining[startTag.upperBound...])
            let endTagStr = isMath ? "[/MATH]" : "[/GRAPH]"

            if let endTagRange = remaining.range(of: endTagStr) {
                let innerContent = String(remaining[..<endTagRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isMath {
                    blocks.append(ParsedContentBlock(type: .math(innerContent)))
                } else {
                    blocks.append(ParsedContentBlock(type: .graph(innerContent)))
                }
                remaining = String(remaining[endTagRange.upperBound...])
            } else {
                blocks.append(ParsedContentBlock(type: .text(remaining)))
                break
            }
        }
        return blocks
    }
    
    private func calculateHeight(for latex: String) -> CGFloat {
        let lineBreaks = latex.components(separatedBy: "\\\\").count - 1
        let hasFraction = latex.contains("\\frac")
        let baseHeight: CGFloat = 70
        let lineBreakHeight: CGFloat = 30 * CGFloat(lineBreaks)
        let fractionHeight: CGFloat = hasFraction ? 35 : 0
        return baseHeight + lineBreakHeight + fractionHeight
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // NEW INLINE PARSER RENDERER
                ForEach(parsedBlocks) { block in
                    switch block.type {
                    case .text(let textContent):
                        TextStylingUtility.styledText(from: textContent)
                            .font(.system(size: 19, weight: .regular, design: .serif))
                            .lineSpacing(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                    case .math(let latexContent):
                        VStack(spacing: 0) {
                            LatexView(latex: "$$\n\(latexContent)\n$$")
                                .frame(minHeight: calculateHeight(for: latexContent))
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                    case .graph(let graphDataStr):
                        InlineGraphRenderer(graphString: graphDataStr)
                            .frame(height: 250)
                            .padding(.horizontal)
                    }
                }

                // LEGACY BACKWARD COMPATIBILITY
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
            .padding(.top, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                onBackgroundTap()
            }
        }
        .scrollIndicators(.hidden)
    }
}


// MARK: - InlineGraphRenderer
struct InlineGraphPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}

struct InlineGraphRenderer: View {
    let graphString: String
    @Environment(\.colorScheme) var colorScheme
    
    var points: [InlineGraphPoint] {
        var extractedPoints: [InlineGraphPoint] = []
        
        if graphString.contains("type=points"), let pointsStr = graphString.components(separatedBy: "points=").last {
            let pairs = pointsStr.components(separatedBy: ";")
            for pair in pairs {
                let coords = pair.components(separatedBy: ",")
                if coords.count == 2, let x = Double(coords[0]), let y = Double(coords[1]) {
                    extractedPoints.append(InlineGraphPoint(x: x, y: y))
                }
            }
        }
        return extractedPoints
    }
    
    var body: some View {
        if points.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "function")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("Function Graph: \(getEquation(from: graphString))")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Switch graph type to 'Coordinate Points' in Admin to visualize line data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        } else {
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.green)
                    
                    PointMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .foregroundStyle(.green)
                }
            }
            .padding(16)
            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    func getEquation(from string: String) -> String {
        if string.contains("type=equation"), let eqStr = string.components(separatedBy: "equation=").last {
            return eqStr
        }
        return "Unknown"
    }
}


// MARK: - ExampleView (Legacy Support)
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
