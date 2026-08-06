//
//  UniversalBlockEditorView.swift
//  ProjectDelta
//

import SwiftUI

struct UniversalBlockEditorView: View {
    @Binding var blocks: [QuestionBlockModel]
    var onSave: (() -> Void)? = nil
    
    @State private var isSaved: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isSaved = true
                    }
                    
                    // Allow the user to register the success feedback before navigating back
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        onSave?()
                        isSaved = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "checkmark.seal.fill" : "square.and.arrow.down.fill")
                        Text(isSaved ? "Page Saved" : "Save Page")
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(isSaved ? Color.green : Color.teal)
                    .cornerRadius(14)
                    .shadow(color: (isSaved ? Color.green : Color.teal).opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: isSaved)
            }
            
            ForEach($blocks) { $block in
                let blockId = block.id
                
                BlockEditCell(block: $block) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        blocks.removeAll { $0.id == blockId }
                    }
                }
                .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
            }
            
            Menu {
                Button(action: { addBlock(type: .text) }) {
                    Label("Add Plain Text", systemImage: "text.alignleft")
                }
                Button(action: { addBlock(type: .math) }) {
                    Label("Add Math Equation", systemImage: "x.squareroot")
                }
                Button(action: { addBlock(type: .graph) }) {
                    Label("Add Interactive Graph", systemImage: "chart.xyaxis.line")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Add Content Block")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.teal.opacity(0.15))
                .foregroundColor(.teal)
                .cornerRadius(16)
            }
        }
    }
    
    private func addBlock(type: QuestionBlockType) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            blocks.append(QuestionBlockModel(type: type.rawValue, content: ""))
        }
    }
}

fileprivate struct BlockEditCell: View {
    @Binding var block: QuestionBlockModel
    var onDelete: () -> Void
    
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Lightweight Non-Live Header Card to prevent performance lag
            HStack(spacing: 12) {
                Image(systemName: iconForType())
                    .font(.title3)
                    .foregroundColor(colorForType())
                    .frame(width: 34, height: 34)
                    .background(colorForType().opacity(0.12))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.type.capitalized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: isEditing ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.platformSystemBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isEditing ? colorForType() : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: isEditing ? 3 : 2, dash: isEditing ? [] : [6])
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isEditing.toggle()
                    if isEditing { isFocused = true }
                }
            }

            // Expanding Editor Controls
            if isEditing {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: iconForType())
                            Text("Editing \(block.type.capitalized)")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(colorForType())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(colorForType().opacity(0.15))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red.opacity(0.8))
                                .padding(10)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEditing = false
                                isFocused = false
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if block.type == QuestionBlockType.text.rawValue {
                        TextField("Enter instructional prose or context...", text: $block.content, axis: .vertical)
                            .lineLimit(4...12)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .padding(16)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(12)
                            .focused($isFocused)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFocused ? colorForType() : Color.clear, lineWidth: 2)
                            )
                    } else if block.type == QuestionBlockType.math.rawValue {
                        buildMathEditor()
                    } else if block.type == QuestionBlockType.graph.rawValue {
                        buildGraphEditor()
                    }
                }
                .padding(20)
                .background(Color.platformSystemBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }

    private var summaryText: String {
        let trimmed = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Empty \(block.type.lowercased()) block"
        }
        return trimmed
    }
    
    // MARK: - Sub-Editors
    
    @ViewBuilder
    private func buildMathEditor() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LaTeX Expression Builder")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
            
            TextField("e.g. \\frac{1}{2}x + 5", text: $block.content, axis: .vertical)
                .lineLimit(2...6)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .padding(16)
                .background(Color.teal.opacity(0.05))
                .cornerRadius(12)
                .focused($isFocused)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.teal : Color.clear, lineWidth: 2)
                )
                .toolbar {
                    #if os(iOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        if isFocused {
                            Spacer()
                            Button("Done") { isFocused = false }
                                .fontWeight(.bold)
                                .foregroundColor(.teal)
                        }
                    }
                    #endif
                }
            
            if isFocused {
                MathKeypadView(text: $block.content)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    @ViewBuilder
    private func buildGraphEditor() -> some View {
        let selectedGraphType = block.graphType ?? QuestionGraphType.equation.rawValue
        let expressions = block.content.isEmpty ? [""] : block.content.components(separatedBy: "\n")
        
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 34, height: 34)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interactive Graph Builder")
                        .font(.headline)
                    Text("Add multiple equations or coordinate sets.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Picker("Graph Mode", selection: Binding(
                get: { selectedGraphType },
                set: { block.graphType = $0 }
            )) {
                Text("Equations").tag(QuestionGraphType.equation.rawValue)
                Text("Points").tag(QuestionGraphType.points.rawValue)
            }
            .pickerStyle(.segmented)
            
            InteractiveGraphBuilderView(
                content: $block.content,
                graphType: selectedGraphType
            )
            .frame(height: 360)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Expressions")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                ForEach(0..<max(1, expressions.count), id: \.self) { index in
                    HStack {
                        TextField(selectedGraphType == QuestionGraphType.equation.rawValue ? "y = x^2 + 3" : "(0, 0), (2, 3)", text: Binding(
                            get: {
                                guard index < expressions.count else { return "" }
                                return expressions[index]
                            },
                            set: { newValue in
                                var newExpressions = expressions
                                if index < newExpressions.count {
                                    newExpressions[index] = newValue
                                } else {
                                    newExpressions.append(newValue)
                                }
                                block.content = newExpressions.joined(separator: "\n")
                            }
                        ))
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .padding(14)
                        .background(Color.purple.opacity(0.06))
                        .cornerRadius(12)
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            isFocused = false
                        }
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        
                        if expressions.count > 1 {
                            Button(action: {
                                var newExpressions = expressions
                                newExpressions.remove(at: index)
                                block.content = newExpressions.joined(separator: "\n")
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Button(action: {
                    var newExpressions = expressions
                    newExpressions.append("")
                    block.content = newExpressions.joined(separator: "\n")
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Expression")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.purple)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Helpers
    private func iconForType() -> String {
        switch block.type {
        case QuestionBlockType.text.rawValue: return "text.alignleft"
        case QuestionBlockType.math.rawValue: return "function"
        case QuestionBlockType.graph.rawValue: return "chart.xyaxis.line"
        default: return "cube"
        }
    }
    
    private func colorForType() -> Color {
        switch block.type {
        case QuestionBlockType.text.rawValue: return .blue
        case QuestionBlockType.math.rawValue: return .teal
        case QuestionBlockType.graph.rawValue: return .purple
        default: return .primary
        }
    }
}

// MARK: - Live Block Rendering Engine
fileprivate struct LiveBlockRenderView: View {
    let block: QuestionBlockModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if block.type == QuestionBlockType.text.rawValue {
            let parsed = parseEditorContent(block.content)
            
            if parsed.isEmpty {
                Text("Empty Text Block")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(parsed) { pBlock in
                        switch pBlock.type {
                        case .text(let text):
                            TextStylingUtility.styledText(from: text)
                                .font(.system(size: 21, weight: .regular, design: .serif))
                                .lineSpacing(12)
                                .foregroundColor(.primary.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        case .math(let latex):
                            LatexView(latex: "$$\n\(latex)\n$$")
                                .padding(24)
                                .frame(maxWidth: .infinity)
                                .background(Color.platformSecondarySystemBackground)
                                .cornerRadius(16)
                        case .graph(let graphStr):
                            InlineGraphRenderer(graphString: graphStr, themeColor: colorScheme == .dark ? .teal : .blue)
                        }
                    }
                }
            }
        } else if block.type == QuestionBlockType.math.rawValue {
            if block.content.isEmpty {
                Text("Empty Math Block")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.platformSecondarySystemBackground)
                    .cornerRadius(12)
            } else {
                LatexView(latex: "$$ " + block.content.parsedMathToLatex + " $$")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.platformSecondarySystemBackground)
                    .cornerRadius(12)
            }
        } else if block.type == QuestionBlockType.graph.rawValue {
            let parsedData = GraphContentParser.graphData(from: block.content, graphType: block.graphType)
            DynamicGraphView(data: parsedData)
                .frame(height: 320)
                .background(Color.platformSecondarySystemBackground)
                .cornerRadius(12)
        }
    }
}

// MARK: - Editor Text Parsing Engine
fileprivate struct EditorParsedContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType

    enum BlockType {
        case text(String)
        case math(String)
        case graph(String)
    }
}

fileprivate func parseEditorContent(_ content: String) -> [EditorParsedContentBlock] {
    var blocks: [EditorParsedContentBlock] = []
    var remaining = content

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
                blocks.append(EditorParsedContentBlock(type: .text(text)))
            }
            break
        }

        let textBefore = String(remaining[..<startTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !textBefore.isEmpty {
            blocks.append(EditorParsedContentBlock(type: .text(textBefore)))
        }

        remaining = String(remaining[startTag.upperBound...])
        let endTagStr = isMath ? "[/MATH]" : "[/GRAPH]"

        if let endTagRange = remaining.range(of: endTagStr) {
            let innerContent = String(remaining[..<endTagRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if isMath {
                blocks.append(EditorParsedContentBlock(type: .math(innerContent)))
            } else {
                blocks.append(EditorParsedContentBlock(type: .graph(innerContent)))
            }
            remaining = String(remaining[endTagRange.upperBound...])
        } else {
            blocks.append(EditorParsedContentBlock(type: .text(remaining)))
            break
        }
    }
    return blocks
}

// MARK: - Advanced Interactive Graph Canvas
fileprivate struct InteractiveGraphBuilderView: View {
    @Binding var content: String
    var graphType: String
    
    @State private var points: [CGPoint] = []
    
    // Viewport and Interaction State
    @State private var currentScale: CGFloat = 30.0
    @State private var lastScale: CGFloat = 30.0
    
    @State private var currentPan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    
    @State private var tapFeedbackTrigger: Int = 0
    
    @Environment(\.colorScheme) var colorScheme
    
    private let lineColors: [Color] = [.purple, .teal, .pink, .orange, .cyan, .green, .red]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(graphType == QuestionGraphType.equation.rawValue ? "Line Builder" : "Point Mapper", systemImage: "hand.draw.fill")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                Spacer()
                
                if !content.isEmpty || !points.isEmpty {
                    Button(action: {
                        withAnimation {
                            points.removeAll()
                            content = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            GeometryReader { geo in
                let size = geo.size
                let safeWidth = max(size.width, 100)
                let safeHeight = max(size.height, 100)
                let origin = CGPoint(x: safeWidth / 2 + currentPan.width, y: safeHeight / 2 + currentPan.height)
                let step = calculateGridStep(scale: currentScale)
                
                ZStack {
                    Canvas { context, canvasSize in
                        let background = Path(roundedRect: CGRect(origin: .zero, size: canvasSize), cornerRadius: 16)
                        context.fill(background, with: .linearGradient(
                            Gradient(colors: [
                                Color.purple.opacity(0.08),
                                Color.blue.opacity(0.04),
                                Color.clear
                            ]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                        ))
                        
                        drawAdaptiveGrid(context: context, size: canvasSize, origin: origin, scale: currentScale, step: step)
                        
                        if graphType == QuestionGraphType.equation.rawValue {
                            let expressions = content.components(separatedBy: "\n")
                            for (index, expr) in expressions.enumerated() {
                                let color = lineColors[index % lineColors.count]
                                
                                if !expr.isEmpty {
                                    drawEquationCurve(context: context, expr: expr, origin: origin, scale: currentScale, canvasSize: canvasSize, color: color)
                                }
                            }
                        }
                    }
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(location: location, origin: origin, scale: currentScale, step: step)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { val in
                                    currentPan = CGSize(width: lastPan.width + val.translation.width, height: lastPan.height + val.translation.height)
                                }
                                .onEnded { _ in
                                    lastPan = currentPan
                                }
                        )
                        .simultaneousGesture(
                            MagnifyGesture()
                                .onChanged { val in
                                    let newScale = lastScale * val.magnification
                                    if newScale.isFinite && newScale > 0 {
                                        currentScale = max(10.0, min(newScale, 150.0))
                                    }
                                }
                                .onEnded { _ in
                                    lastScale = currentScale
                                }
                        )
                    
                    ForEach(points.indices, id: \.self) { index in
                        DraggablePointView(
                            point: Binding(get: {
                                points.indices.contains(index) ? points[index] : .zero
                            }, set: {
                                if points.indices.contains(index) { points[index] = $0 }
                            }),
                            origin: origin,
                            scale: currentScale,
                            step: step,
                            onUpdate: {
                                if graphType == QuestionGraphType.equation.rawValue {
                                    generateLinearEquation()
                                } else {
                                    generatePointsString()
                                }
                            }
                        )
                    }
                    
                    // MARK: - Dynamic Legend Overlay
                    if graphType == QuestionGraphType.equation.rawValue {
                        let activeExpressions = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        
                        if !activeExpressions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(activeExpressions.enumerated()), id: \.offset) { index, expr in
                                    let color = lineColors[index % lineColors.count]
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 8, height: 8)
                                        Text(expr.formatAsMathPower)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(colorScheme == .dark ? color : color.opacity(0.9))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(color.opacity(colorScheme == .dark ? 0.22 : 0.12))
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                        }
                    }
                }
                .background(Color.platformSecondarySystemGroupedBackground)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.purple.opacity(0.4), lineWidth: 1.5))
                .clipped()
                .shadow(color: Color.purple.opacity(0.2), radius: 12, y: 4)
                .sensoryFeedback(.impact(weight: .medium), trigger: tapFeedbackTrigger)
            }
        }
        .onAppear { loadPointsFromContent() }
        .onChange(of: graphType) { _, _ in
            points.removeAll()
            content = ""
        }
    }
    
    // MARK: Adaptive Grid System
    private func calculateGridStep(scale: CGFloat) -> CGFloat {
        let targetSpacing: CGFloat = 85.0 // Widened spacing for clean, uncluttered axes on all screens
        let rawStep = targetSpacing / scale
        let mag = pow(10.0, floor(log10(rawStep)))
        let normalized = rawStep / mag
        
        if normalized < 2.0 { return 1.0 * mag }
        if normalized < 5.0 { return 2.0 * mag }
        return 5.0 * mag
    }
        
    private func drawAdaptiveGrid(context: GraphicsContext, size: CGSize, origin: CGPoint, scale: CGFloat, step: CGFloat) {
        let minXMath = -origin.x / scale
        let maxXMath = (size.width - origin.x) / scale
        let minYMath = (origin.y - size.height) / scale
        let maxYMath = origin.y / scale
        
        var minorPath = Path()
        
        var x = floor(minXMath / step) * step
        while x <= maxXMath {
            let sx = origin.x + x * scale
            minorPath.move(to: CGPoint(x: sx, y: 0))
            minorPath.addLine(to: CGPoint(x: sx, y: size.height))
            
            if abs(x) > 0.0001 { // Prevent drawing 0 here to avoid axis overlap
                let text = Text(x.cleanMathString).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
                context.draw(text, at: CGPoint(x: sx, y: origin.y + 8), anchor: .top)
            }
            x += step
        }
        
        var y = floor(minYMath / step) * step
        while y <= maxYMath {
            let sy = origin.y - y * scale
            minorPath.move(to: CGPoint(x: 0, y: sy))
            minorPath.addLine(to: CGPoint(x: size.width, y: sy))
            
            if abs(y) > 0.0001 {
                let text = Text(y.cleanMathString).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
                context.draw(text, at: CGPoint(x: origin.x - 8, y: sy), anchor: .trailing)
            }
            y += step
        }
        
        context.stroke(minorPath, with: .color(Color.gray.opacity(0.18)), lineWidth: 1)
        
        var axesPath = Path()
        axesPath.move(to: CGPoint(x: origin.x, y: 0))
        axesPath.addLine(to: CGPoint(x: origin.x, y: size.height))
        axesPath.move(to: CGPoint(x: 0, y: origin.y))
        axesPath.addLine(to: CGPoint(x: size.width, y: origin.y))
        
        context.stroke(axesPath, with: .color(Color.primary.opacity(0.55)), lineWidth: 1.5)
        
        // Draw crisp origin zero
        let zeroText = Text("0").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.9))
        context.draw(zeroText, at: CGPoint(x: origin.x - 6, y: origin.y + 6), anchor: .topTrailing)
    }
    
    private func drawLine(context: GraphicsContext, p1: CGPoint, p2: CGPoint, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        guard p1.x.isFinite, p1.y.isFinite, p2.x.isFinite, p2.y.isFinite else { return }

        var linePath = Path()
        
        let sp1 = CGPoint(x: origin.x + p1.x * scale, y: origin.y - p1.y * scale)
        let sp2 = CGPoint(x: origin.x + p2.x * scale, y: origin.y - p2.y * scale)
        
        if sp1.x == sp2.x {
            linePath.move(to: CGPoint(x: sp1.x, y: 0))
            linePath.addLine(to: CGPoint(x: sp1.x, y: canvasSize.height))
        } else {
            let m = (sp2.y - sp1.y) / (sp2.x - sp1.x)
            let b = sp1.y - m * sp1.x
            linePath.move(to: CGPoint(x: 0, y: b))
            linePath.addLine(to: CGPoint(x: canvasSize.width, y: m * canvasSize.width + b))
        }
        
        // Change `path` back to `linePath`
        context.stroke(linePath, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    
    private func drawEquationCurve(context: GraphicsContext, expr: String, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        guard let evaluator = MathEngine.compile(expr) else { return }
        
        var path = Path()
        var isFirst = true
        var previousScreenY: CGFloat? = nil
        
        for screenX in stride(from: 0, through: canvasSize.width, by: 2) {
            let mathX = (screenX - origin.x) / scale
            let mathY = CGFloat(evaluator(mathX))
            
            if mathY.isNaN || mathY.isInfinite {
                isFirst = true
                previousScreenY = nil
                continue
            }
            
            let screenY = origin.y - mathY * scale
            
            if let prevY = previousScreenY, abs(screenY - prevY) > canvasSize.height {
                isFirst = true
            }
            
            let pt = CGPoint(x: screenX, y: screenY)
            
            if screenY >= -500 && screenY <= canvasSize.height + 500 {
                if isFirst {
                    path.move(to: pt)
                    isFirst = false
                } else {
                    path.addLine(to: pt)
                }
                previousScreenY = screenY
            } else {
                isFirst = true
                previousScreenY = nil
            }
        }
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    
    private func handleTap(location: CGPoint, origin: CGPoint, scale: CGFloat, step: CGFloat) {
        let mathX = (location.x - origin.x) / scale
        let mathY = (origin.y - location.y) / scale
        
        let snap = step / 4.0
        let snappedP = CGPoint(x: round(mathX / snap) * snap, y: round(mathY / snap) * snap)
        
        if graphType == QuestionGraphType.equation.rawValue {
            if points.count >= 2 { points.removeAll() }
            points.append(snappedP)
            if points.count == 2 { generateLinearEquation() }
        } else {
            points.append(snappedP)
            generatePointsString()
        }
        
        tapFeedbackTrigger += 1
    }
    
    private func generateLinearEquation() {
        guard points.count == 2 else { return }
        
        let p1 = points[0]
        let p2 = points[1]
        
        var eq = ""
        if p1.x == p2.x {
            eq = "x = \(p1.x.cleanMathString)"
        } else {
            let m = (p2.y - p1.y) / (p2.x - p1.x)
            let b = p1.y - m * p1.x
            
            eq = "y = "
            if m != 0 {
                if m == 1 { eq += "x" }
                else if m == -1 { eq += "-x" }
                else { eq += "\(m.cleanMathString)x" }
            }
            
            if b > 0 {
                eq += (m == 0) ? "\(b.cleanMathString)" : " + \(b.cleanMathString)"
            } else if b < 0 {
                eq += (m == 0) ? "\(b.cleanMathString)" : " - \(abs(b).cleanMathString)"
            } else if m == 0 && b == 0 {
                eq += "0"
            }
        }
        
        var currentExpressions = content.components(separatedBy: "\n")
        if currentExpressions.isEmpty { currentExpressions.append(eq) }
        else { currentExpressions[currentExpressions.count - 1] = eq }
        content = currentExpressions.joined(separator: "\n")
    }
    
    private func generatePointsString() {
        content = points.map { "(\($0.x.cleanMathString), \($0.y.cleanMathString))" }.joined(separator: ", ")
    }
    
    private func loadPointsFromContent() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        // Only load points if the graph is explicitly in "Points" mode
        if graphType == QuestionGraphType.points.rawValue {
            let graphData = GraphContentParser.graphData(from: trimmedContent, graphType: graphType)
            points = zip(graphData.xValues, graphData.yValues)
                .filter { !$0.0.isNaN && !$0.1.isNaN && !$0.0.isInfinite && !$0.1.isInfinite }
                .map { CGPoint(x: $0.0, y: $0.1) }
        }
    }

    private func parseLinearEquation(_ expr: String) -> (m: CGFloat, b: CGFloat)? {
        let clean = expr.replacingOccurrences(of: " ", with: "").lowercased()
        guard clean.hasPrefix("y=") else { return nil }
        let rhs = clean.dropFirst(2)
        if rhs.isEmpty { return nil }

        if !rhs.contains("x") {
            if let b = Double(rhs) { return (0, CGFloat(b)) }
            return nil
        }

        let components = rhs.components(separatedBy: "x")
        let mStr = components[0]
        let bStr = components.count > 1 ? components[1] : ""

        var m: CGFloat = 1
        if mStr == "-" { m = -1 }
        else if mStr == "" || mStr == "+" { m = 1 }
        else {
            if mStr.contains("/") {
                let parts = mStr.components(separatedBy: "/")
                if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
                    m = CGFloat(num / den)
                } else { return nil }
            } else if let parsedM = Double(mStr) {
                m = CGFloat(parsedM)
            } else {
                return nil
            }
        }

        var b: CGFloat = 0
        if !bStr.isEmpty {
            let sanitizedB = bStr.replacingOccurrences(of: "+", with: "")
            if let parsedB = Double(sanitizedB) {
                b = CGFloat(parsedB)
            }
        }
        return (m, b)
    }
}

// MARK: - Draggable Labeled Point Subview
fileprivate struct DraggablePointView: View {
    @Binding var point: CGPoint
    let origin: CGPoint
    let scale: CGFloat
    let step: CGFloat
    let onUpdate: () -> Void
    
    @State private var dragInitial: CGPoint? = nil
    
    var body: some View {
        let screenP = CGPoint(x: origin.x + point.x * scale, y: origin.y - point.y * scale)
        
        ZStack(alignment: .bottom) {
            Text("(\(point.x.cleanMathString), \(point.y.cleanMathString))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.85))
                .cornerRadius(6)
                .offset(y: -35)
            
            Circle()
                .fill(Color.purple)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.4), radius: 6)
        }
        .frame(width: 60, height: 60)
        .contentShape(Rectangle())
        .position(screenP)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    if dragInitial == nil { dragInitial = point }
                    let start = dragInitial!
                    
                    let mathDx = val.translation.width / scale
                    let mathDy = -val.translation.height / scale
                    
                    let rawP = CGPoint(x: start.x + mathDx, y: start.y + mathDy)
                    
                    let snap = step / 4.0
                    point = CGPoint(x: round(rawP.x / snap) * snap, y: round(rawP.y / snap) * snap)
                    onUpdate()
                }
                .onEnded { _ in
                    dragInitial = nil
                }
        )
    }
}

// MARK: - Advanced WebAssign Math Keypad
fileprivate enum KeypadTab: String, CaseIterable {
    case num = "123"
    case fn = "ƒ(x)"
    case sym = "αβγ"
}

fileprivate struct MathKeypadView: View {
    @Binding var text: String
    @State private var currentTab: KeypadTab = .num
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $currentTab) {
                ForEach(KeypadTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            
            LazyVGrid(columns: columns, spacing: 10) {
                switch currentTab {
                case .num:
                    keyButton("7", display: "7")
                    keyButton("8", display: "8")
                    keyButton("9", display: "9")
                    keyButton("\\div", display: "÷", color: Color.teal.opacity(0.15))
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color.red.opacity(0.15), textColor: .red)
                    
                    keyButton("4", display: "4")
                    keyButton("5", display: "5")
                    keyButton("6", display: "6")
                    keyButton("\\times", display: "×", color: Color.teal.opacity(0.15))
                    keyButton("\\frac{ }{ }", display: "a/b", color: Color.teal.opacity(0.15))
                    
                    keyButton("1", display: "1")
                    keyButton("2", display: "2")
                    keyButton("3", display: "3")
                    keyButton("-", display: "-", color: Color.teal.opacity(0.15))
                    keyButton("^{2}", display: "x²", color: Color.teal.opacity(0.15))
                    
                    keyButton("0", display: "0")
                    keyButton(".", display: ".")
                    keyButton("=", display: "=", color: Color.teal.opacity(0.15))
                    keyButton("+", display: "+", color: Color.teal.opacity(0.15))
                    keyButton("^{ }", display: "xⁿ", color: Color.teal.opacity(0.15))
                    
                case .fn:
                    keyButton("\\sin()", display: "sin")
                    keyButton("\\cos()", display: "cos")
                    keyButton("\\tan()", display: "tan")
                    keyButton("\\ln()", display: "ln")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color.red.opacity(0.15), textColor: .red)
                    
                    keyButton("\\csc()", display: "csc")
                    keyButton("\\sec()", display: "sec")
                    keyButton("\\cot()", display: "cot")
                    keyButton("\\log_{10}()", display: "log")
                    keyButton("\\sqrt{ }", display: "√", color: Color.teal.opacity(0.15))
                    
                    keyButton("x", display: "x", color: Color.teal.opacity(0.15))
                    keyButton("y", display: "y", color: Color.teal.opacity(0.15))
                    keyButton("e^{}", display: "eⁿ", color: Color.teal.opacity(0.15))
                    keyButton("(", display: "(", color: Color.teal.opacity(0.15))
                    keyButton(")", display: ")", color: Color.teal.opacity(0.15))
                    
                    keyButton("a", display: "a", color: Color.teal.opacity(0.15))
                    keyButton("b", display: "b", color: Color.teal.opacity(0.15))
                    keyButton("c", display: "c", color: Color.teal.opacity(0.15))
                    keyButton("[", display: "[", color: Color.teal.opacity(0.15))
                    keyButton("]", display: "]", color: Color.teal.opacity(0.15))
                    
                case .sym:
                    keyButton("\\pi", display: "π")
                    keyButton("\\theta", display: "θ")
                    keyButton("\\alpha", display: "α")
                    keyButton("\\beta", display: "β")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color.red.opacity(0.15), textColor: .red)
                    
                    keyButton("\\leq", display: "≤")
                    keyButton("\\geq", display: "≥")
                    keyButton("\\neq", display: "≠")
                    keyButton("\\approx", display: "≈")
                    keyButton("\\pm", display: "±", color: Color.teal.opacity(0.15))
                    
                    keyButton("\\int", display: "∫")
                    keyButton("\\sum", display: "∑")
                    keyButton("\\infty", display: "∞")
                    keyButton("^{\\circ}", display: "°")
                    keyButton("\\Delta", display: "Δ", color: Color.teal.opacity(0.15))
                    
                    keyButton("\\{", display: "{", color: Color.teal.opacity(0.15))
                    keyButton("\\}", display: "}", color: Color.teal.opacity(0.15))
                    keyButton("<", display: "<", color: Color.teal.opacity(0.15))
                    keyButton(">", display: ">", color: Color.teal.opacity(0.15))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color.teal.opacity(0.15))
                }
            }
        }
        .padding(16)
        .background(Color.platformSecondarySystemGroupedBackground)
        .cornerRadius(16)
    }
    
    private func backspace() {
        if !text.isEmpty { text.removeLast() }
    }
    
    @ViewBuilder
    private func keyButton(_ insertString: String, display: String, color: Color = Color.platformSystemBackground) -> some View {
        Button(action: { text.append(insertString) }) {
            Text(display)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(color)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 2)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func actionButton(systemName: String, action: @escaping () -> Void, color: Color, textColor: Color = .primary) -> some View {
        Button(action: action) {
            Image(systemName: nameForSystem(systemName))
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(color)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 2)
                .foregroundColor(textColor)
        }
        .buttonStyle(.plain)
    }
    
    private func nameForSystem(_ name: String) -> String {
        return name == "space" ? "spacebar" : name
    }
}

// MARK: - Preview
#Preview {
    UniversalBlockEditorView(blocks: .constant([
        QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: "Identify the slope in the following equation:"),
        QuestionBlockModel(type: QuestionBlockType.math.rawValue, content: "\\frac{1}{2}x + 5 = y")
    ]))
    .padding()
}
