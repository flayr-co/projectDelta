//
//  LessonContentPage.swift
//  ProjectDelta
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

    // Core Parser Engine
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
            VStack(alignment: .leading, spacing: 32) {
                
                // NEW INLINE PARSER RENDERER
                ForEach(parsedBlocks) { block in
                    switch block.type {
                    case .text(let textContent):
                        TextStylingUtility.styledText(from: textContent)
                            .font(.system(size: 21, weight: .regular, design: .serif))
                            .lineSpacing(12)
                            .foregroundColor(.primary.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                    case .math(let latexContent):
                        VStack(spacing: 0) {
                            LatexView(latex: "$$\n\(latexContent)\n$$")
                                .frame(minHeight: calculateHeight(for: latexContent))
                                .padding(24)
                                .frame(maxWidth: .infinity)
                                .background(Color.platformSecondarySystemBackground)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        }
                        
                    case .graph(let graphDataStr):
                        InlineGraphRenderer(graphString: graphDataStr)
                    }
                }

                // LEGACY BACKWARD COMPATIBILITY
                if let graphData = page.graphData {
                    DynamicGraphView(data: graphData)
                        .padding(.vertical, 16)
                }

                if let example = page.example, !example.isEmpty {
                    ExampleView(text: example)
                }

                if let explanationText = page.explanation, !explanationText.isEmpty {
                    VStack(spacing: 16) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isExplanationVisible.toggle()
                                isInteractingWithExplanation = isExplanationVisible
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isExplanationVisible ? "chevron.up.circle.fill" : "lightbulb.fill")
                                    .font(.system(size: 18))
                                Text(isExplanationVisible ? "Hide Breakdown" : "View Step-by-Step Breakdown")
                                    .fontWeight(.bold)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 24)
                            .background(Color.teal.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.teal)
                        .frame(maxWidth: .infinity)

                        if isExplanationVisible {
                            ExampleView(text: explanationText)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.top, 16)
                }

                if page.readyButtonDisplayed {
                    VStack(spacing: 20) {
                        Button(action: {}) {
                            AnimatedActionButton()
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            UniversalTestView(mode: .practice(
                                subject: lessonVM.subjectName,
                                lessonName: lessonVM.currentLessonName,
                                lessonId: lessonVM.currentLessonId
                            ))
                        } label: {
                            Text("Jump to Practice Session")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.teal)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.teal.opacity(0.3), radius: 10, y: 5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
                }
            }
            #if os(macOS)
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
            .frame(maxWidth: 900) // Optimized for readability
            .frame(maxWidth: .infinity, alignment: .center)
            #else
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 120)
            #endif
        }
        .scrollIndicators(.hidden)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onBackgroundTap() }
        )
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
                    .foregroundColor(.teal)
                Text("Function Graph: \(getEquation(from: graphString))")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 250)
            .background(Color.platformSecondarySystemBackground)
            .cornerRadius(16)
        } else {
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.teal)
                    
                    PointMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .foregroundStyle(.teal)
                }
            }
            .frame(height: 250)
            .padding(24)
            .background(Color.platformSecondarySystemBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
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
struct ParsedExampleItem: Identifiable {
    let id = UUID()
    let example: String
    let explanation: String
}

struct ExampleView: View {
    var text: String
    @Environment(\.colorScheme) var colorScheme

    var parsedContent: [ParsedExampleItem] {
        text.split(separator: "\n").map { line in
            let parts = line.split(separator: "||", maxSplits: 1, omittingEmptySubsequences: false)
            let example = String(parts[0])
            let explanation = parts.count > 1 ? String(parts[1]) : ""
            return ParsedExampleItem(example: example, explanation: explanation)
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
        VStack(alignment: .leading, spacing: 20) {
            ForEach(parsedContent) { item in
                VStack(alignment: .leading, spacing: 12) {
                    if item.example.contains("$$") {
                        let latex = item.example
                            .replacingOccurrences(of: "$$", with: "")
                            .replacingOccurrences(of: "\\\\newline", with: "\\\\")
                        
                        let height = calculateHeight(for: latex)
                        
                        LatexView(latex: "$$\n\(latex)\n$$")
                            .frame(minHeight: height)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color.platformSecondarySystemBackground)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                    } else {
                        TextStylingUtility.styledText(from: item.example)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.platformSecondarySystemBackground)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                    }

                    if !item.explanation.isEmpty {
                        Text(item.explanation)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
