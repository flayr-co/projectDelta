//
//  UniversalBlockEditorView.swift
//  ProjectDelta
//

import SwiftUI

struct UniversalBlockEditorView: View {
    @Binding var blocks: [QuestionBlockModel]
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach($blocks) { $block in
                BlockEditCell(block: $block) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        blocks.removeAll { $0.id == block.id }
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
                        .font(.title3)
                    Text("Add Content Block")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.teal.opacity(0.15))
                .foregroundColor(.teal)
                .cornerRadius(14)
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
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label(block.type.capitalized, systemImage: iconForType())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(colorForType())
                
                Spacer()
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Content Editor Based on Type
            if block.type == QuestionBlockType.text.rawValue {
                TextField("Enter instruction or context...", text: $block.content, axis: .vertical)
                    .lineLimit(3...10)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .focused($isFocused)
                    
            } else if block.type == QuestionBlockType.math.rawValue {
                buildMathEditor()
            } else if block.type == QuestionBlockType.graph.rawValue {
                buildGraphEditor()
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Sub-Editors
    
    @ViewBuilder
    private func buildMathEditor() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LaTeX Expression Builder")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Input Field
            TextField("e.g. \\frac{1}{2}x + 5", text: $block.content, axis: .vertical)
                .lineLimit(2...6)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color.teal.opacity(0.05))
                .cornerRadius(10)
                .focused($isFocused)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? Color.teal : Color.clear, lineWidth: 2)
                )
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if isFocused {
                            Spacer()
                            Button("Done") { isFocused = false }
                                .fontWeight(.bold)
                                .foregroundColor(.teal)
                        }
                    }
                }
            
            // WebAssign Style Live Preview
            if !block.content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Render")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.teal)
                        .textCase(.uppercase)
                    
                    LatexView(latex: "$$ " + block.content.parsedMathToLatex + " $$")
                        .frame(minHeight: 50)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                }
            }
            
            // Smart Keypad
            if isFocused {
                MathKeypadView(text: $block.content)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    @ViewBuilder
    private func buildGraphEditor() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Mode", selection: Binding(
                get: { block.graphType ?? QuestionGraphType.equation.rawValue },
                set: { block.graphType = $0 }
            )) {
                ForEach(QuestionGraphType.allCases, id: \.rawValue) { type in
                    Text(type.rawValue.capitalized).tag(type.rawValue)
                }
            }
            .pickerStyle(.segmented)
            
            InteractiveGraphBuilderView(
                content: $block.content,
                graphType: block.graphType ?? QuestionGraphType.equation.rawValue
            )
            
            let placeholder = block.graphType == QuestionGraphType.equation.rawValue ? "Generated Equation (e.g., y = 2x + 1)" : "Generated Coordinates"
            
            VStack(alignment: .leading, spacing: 6) {
                Text(placeholder)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Data...", text: $block.content, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
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
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "hand.draw.fill")
                    .foregroundColor(.teal)
                Text(graphType == QuestionGraphType.equation.rawValue ? "Plot 2 points to define the line" : "Tap to place coordinate points")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !points.isEmpty {
                    Button(action: {
                        withAnimation {
                            points.removeAll()
                            content = ""
                        }
                    }) {
                        Text("Clear")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
            
            GeometryReader { geo in
                let size = geo.size
                let origin = CGPoint(x: size.width / 2 + currentPan.width, y: size.height / 2 + currentPan.height)
                let step = calculateGridStep(scale: currentScale)
                
                ZStack {
                    // Background & Adaptive Grid
                    Canvas { context, canvasSize in
                        drawAdaptiveGrid(context: context, size: canvasSize, origin: origin, scale: currentScale, step: step)
                        
                        if graphType == QuestionGraphType.equation.rawValue, points.count == 2 {
                            drawLine(context: context, p1: points[0], p2: points[1], origin: origin, scale: currentScale, canvasSize: canvasSize)
                        }
                    }
                    
                    // Interaction Layer
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
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
                                    currentScale = max(10.0, min(newScale, 150.0))
                                }
                                .onEnded { _ in
                                    lastScale = currentScale
                                }
                        )
                        .onTapGesture { location in
                            handleTap(location: location, origin: origin, scale: currentScale, step: step)
                        }
                    
                    // Draggable Points
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
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.teal.opacity(0.3), lineWidth: 2))
                .clipped()
            }
            .aspectRatio(1.0, contentMode: .fit)
        }
        .onChange(of: graphType) { _, _ in
            points.removeAll()
            content = ""
        }
    }
    
    // MARK: Adaptive Grid System
    private func calculateGridStep(scale: CGFloat) -> CGFloat {
        let targetSpacing: CGFloat = 60.0
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
            
            if x != 0 {
                let text = Text(x.cleanMathString).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                context.draw(text, at: CGPoint(x: sx, y: origin.y + 6), anchor: .top)
            }
            x += step
        }
        
        var y = floor(minYMath / step) * step
        while y <= maxYMath {
            let sy = origin.y - y * scale
            minorPath.move(to: CGPoint(x: 0, y: sy))
            minorPath.addLine(to: CGPoint(x: size.width, y: sy))
            
            if y != 0 {
                let text = Text(y.cleanMathString).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                context.draw(text, at: CGPoint(x: origin.x - 6, y: sy), anchor: .trailing)
            }
            y += step
        }
        
        context.stroke(minorPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 1)
        
        var axesPath = Path()
        axesPath.move(to: CGPoint(x: origin.x, y: 0))
        axesPath.addLine(to: CGPoint(x: origin.x, y: size.height))
        axesPath.move(to: CGPoint(x: 0, y: origin.y))
        axesPath.addLine(to: CGPoint(x: size.width, y: origin.y))
        
        context.stroke(axesPath, with: .color(Color.primary.opacity(0.8)), lineWidth: 2)
    }
    
    private func drawLine(context: GraphicsContext, p1: CGPoint, p2: CGPoint, origin: CGPoint, scale: CGFloat, canvasSize: CGSize) {
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
        
        context.stroke(linePath, with: .color(.teal), lineWidth: 3)
    }
    
    private func handleTap(location: CGPoint, origin: CGPoint, scale: CGFloat, step: CGFloat) {
        let mathX = (location.x - origin.x) / scale
        let mathY = (origin.y - location.y) / scale
        
        let snap = step / 4.0
        let snappedP = CGPoint(x: round(mathX / snap) * snap, y: round(mathY / snap) * snap)
        
        if graphType == QuestionGraphType.equation.rawValue {
            if points.count >= 2 { points.removeAll() }
            points.append(snappedP)
            if points.count == 2 { generateLinearEquation() } else { content = "" }
        } else {
            points.append(snappedP)
            generatePointsString()
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func generateLinearEquation() {
        guard points.count == 2 else {
            content = ""
            return
        }
        
        let p1 = points[0]
        let p2 = points[1]
        
        if p1.x == p2.x {
            content = "x = \(p1.x.cleanMathString)"
            return
        }
        
        let m = (p2.y - p1.y) / (p2.x - p1.x)
        let b = p1.y - m * p1.x
        
        var eq = "y = "
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
        content = eq
    }
    
    private func generatePointsString() {
        content = points.map { "(\($0.x.cleanMathString), \($0.y.cleanMathString))" }.joined(separator: ", ")
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
                .background(Color.black.opacity(0.75))
                .cornerRadius(6)
                .offset(y: -35)
            
            Circle()
                .fill(Color.teal)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.3), radius: 4)
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
        VStack(spacing: 12) {
            Picker("", selection: $currentTab) {
                ForEach(KeypadTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            
            LazyVGrid(columns: columns, spacing: 8) {
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
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    private func backspace() {
        if !text.isEmpty { text.removeLast() }
    }
    
    @ViewBuilder
    private func keyButton(_ insertString: String, display: String, color: Color = Color(UIColor.tertiarySystemBackground)) -> some View {
        Button(action: { text.append(insertString) }) {
            Text(display)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func actionButton(systemName: String, action: @escaping () -> Void, color: Color, textColor: Color = .primary) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
                .foregroundColor(textColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Math Formatter Extension
fileprivate extension CGFloat {
    var cleanMathString: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(format: "%.2f", self)
    }
}
