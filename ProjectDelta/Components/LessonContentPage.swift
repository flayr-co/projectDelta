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
        case graph(content: String, graphType: String?)
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
    
    // Dynamic Theme Logic
    var themeColor: Color {
        colorScheme == .dark ? .teal : .blue
    }
    
    var secondaryThemeColor: Color {
        colorScheme == .dark ? .orange : .red
    }

    // Core Parser Engine
    var parsedBlocks: [ParsedContentBlock] {
        if let modernBlocks = decodeModernBlocks(from: page.content) {
            return modernBlocks
        }

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
                    blocks.append(ParsedContentBlock(type: .graph(content: GraphContentParser.graphContent(from: innerContent), graphType: GraphContentParser.graphType(from: innerContent))))
                }
                remaining = String(remaining[endTagRange.upperBound...])
            } else {
                blocks.append(ParsedContentBlock(type: .text(remaining)))
                break
            }
        }
        return blocks
    }

    private func decodeModernBlocks(from content: String) -> [ParsedContentBlock]? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmedContent.data(using: .utf8),
              let decodedBlocks = try? JSONDecoder().decode([QuestionBlockModel].self, from: data) else {
            return nil
        }

        return decodedBlocks.compactMap { block in
            let trimmedBlockContent = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBlockContent.isEmpty else { return nil }

            switch block.type {
            case QuestionBlockType.math.rawValue:
                return ParsedContentBlock(type: .math(trimmedBlockContent))
            case QuestionBlockType.graph.rawValue:
                return ParsedContentBlock(type: .graph(content: trimmedBlockContent, graphType: block.graphType))
            default:
                return ParsedContentBlock(type: .text(trimmedBlockContent))
            }
        }
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
                        
                    case .graph(let graphContent, let graphType):
                        DynamicGraphView(data: GraphContentParser.graphData(from: graphContent, graphType: graphType))
                            .padding(.vertical, 16)
                    }
                }

                if let graphData = page.graphData {
                    DynamicGraphView(data: graphData)
                        .padding(.vertical, 16)
                }

                if let example = page.example, !example.isEmpty {
                    ExampleView(text: example, themeColor: themeColor)
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
                                Image(systemName: isExplanationVisible ? "chevron.up.circle.fill" : "checkmark.seal.fill")
                                    .font(.system(size: 18))
                                Text(isExplanationVisible ? "Hide Breakdown" : "View Step-by-Step Breakdown")
                                    .fontWeight(.bold)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 24)
                            .background(themeColor.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(themeColor)
                        .frame(maxWidth: .infinity)

                        if isExplanationVisible {
                            ExampleView(text: explanationText, themeColor: themeColor)
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
                                .background(themeColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: themeColor.opacity(0.3), radius: 10, y: 5)
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
            .frame(maxWidth: 900)
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
    let themeColor: Color
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
                    .foregroundColor(themeColor)
                Text("Function Graph: \(getEquation(from: graphString))")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 250)
            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        } else {
            Chart {
                ForEach(points) { point in
                    LineMark(x: .value("X", point.x), y: .value("Y", point.y))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(themeColor)
                    PointMark(x: .value("X", point.x), y: .value("Y", point.y))
                        .foregroundStyle(themeColor)
                }
            }
            .frame(height: 250)
            .padding(16)
            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    func getEquation(from string: String) -> String {
        string.contains("type=equation") ? (string.components(separatedBy: "equation=").last ?? "Unknown") : "Unknown"
    }
}

// MARK: - ExampleView
struct ParsedExampleItem: Identifiable {
    let id = UUID()
    let example: String
    let explanation: String
}

struct ExampleView: View {
    var text: String
    var themeColor: Color
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
        VStack(alignment: .leading, spacing: 16) {
            ForEach(parsedContent) { item in
                VStack(alignment: .leading, spacing: 12) {
                    if item.example.contains("$$") {
                        let latex = item.example.replacingOccurrences(of: "$$", with: "").replacingOccurrences(of: "\\\\newline", with: "\\\\")
                        LatexView(latex: "$$\n\(latex)\n$$")
                            .frame(minHeight: calculateHeight(for: latex))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    } else {
                        TextStylingUtility.styledText(from: item.example)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    if !item.explanation.isEmpty {
                        Text(item.explanation)
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
