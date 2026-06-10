//
//  UniversalBlockEditorView.swift
//  ProjectDelta
//

import SwiftUI

struct UniversalBlockEditorView: View {
    @Binding var blocks: [QuestionBlockModel]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach($blocks) { $block in
                BlockEditCell(block: $block) {
                    withAnimation {
                        blocks.removeAll { $0.id == block.id }
                    }
                }
            }
            
            Menu {
                Button(action: { addBlock(type: .text) }) {
                    Label("Add Plain Text", systemImage: "text.alignleft")
                }
                Button(action: { addBlock(type: .math) }) {
                    Label("Add Math Equation", systemImage: "x.squareroot")
                }
                Button(action: { addBlock(type: .graph) }) {
                    Label("Add Graph", systemImage: "chart.xyaxis.line")
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Content Block")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
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
    
    @FocusState private var isMathFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(block.type, systemImage: iconForType())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(colorForType())
                
                Spacer()
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            if block.type == QuestionBlockType.text.rawValue {
                TextField("Enter plain text instruction or context...", text: $block.content, axis: .vertical)
                    .lineLimit(3...10)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    
            } else if block.type == QuestionBlockType.math.rawValue {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Use the keypad below to build simple expressions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Equation or math expression...", text: $block.content, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .focused($isMathFocused)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                if isMathFocused {
                                    Spacer()
                                    Button("Done") {
                                        isMathFocused = false
                                    }
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                    
                    if isMathFocused {
                        MathKeypadView(text: $block.content)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .padding(.top, 4)
                    }
                }
            } else if block.type == QuestionBlockType.graph.rawValue {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Graph Type", selection: Binding(
                        get: { block.graphType ?? QuestionGraphType.equation.rawValue },
                        set: { block.graphType = $0 }
                    )) {
                        ForEach(QuestionGraphType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // The Advanced Interactive Canvas
                    InteractiveGraphBuilderView(
                        content: $block.content,
                        graphType: block.graphType ?? QuestionGraphType.equation.rawValue
                    )
                    
                    let placeholder = block.graphType == QuestionGraphType.equation.rawValue ? "Or enter manual function (e.g., y = 2x + 1)" : "Or enter manual coordinates (e.g., (1,2), (3,4))"
                    
                    TextField(placeholder, text: $block.content, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                        .focused($isMathFocused)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            
            // Live LaTeX Preview
            if !block.content.isEmpty && (block.type == QuestionBlockType.math.rawValue || (block.type == QuestionBlockType.graph.rawValue && block.graphType == QuestionGraphType.equation.rawValue)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Preview:")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.teal)
                    
                    LatexView(latex: "$$ " + block.content.parsedMathToLatex + " $$")
                        .frame(minHeight: 45)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func iconForType() -> String {
        switch block.type {
        case QuestionBlockType.text.rawValue: return "text.alignleft"
        case QuestionBlockType.math.rawValue: return "x.squareroot"
        case QuestionBlockType.graph.rawValue: return "chart.xyaxis.line"
        default: return "cube"
        }
    }
    
    private func colorForType() -> Color {
        switch block.type {
        case QuestionBlockType.text.rawValue: return .blue
        case QuestionBlockType.math.rawValue: return .orange
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
        VStack(spacing: 8) {
            HStack {
                Text(graphType == QuestionGraphType.equation.rawValue ? "Pan, Zoom & Tap 2 points to generate a line" : "Pan, Zoom & Tap to add data points")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !points.isEmpty {
                    Button(action: {
                        points.removeAll()
                        content = ""
                    }) {
                        Text("Clear Canvas")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
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
                                    currentScale = max(5.0, min(newScale, 200.0)) // Clamp zoom limits
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
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .clipped()
            }
            .aspectRatio(1.0, contentMode: .fit)
        }
        .onChange(of: graphType) { _, _ in
            points.removeAll()
        }
    }
    
    // MARK: Adaptive Grid System
    private func calculateGridStep(scale: CGFloat) -> CGFloat {
        let targetSpacing: CGFloat = 60.0 // Target pixels between grid lines
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
        
        // Draw Vertical Lines & X Labels
        var x = floor(minXMath / step) * step
        while x <= maxXMath {
            let sx = origin.x + x * scale
            minorPath.move(to: CGPoint(x: sx, y: 0))
            minorPath.addLine(to: CGPoint(x: sx, y: size.height))
            
            if x != 0 {
                let text = Text(x.cleanMathString).font(.system(size: 10)).foregroundColor(.secondary)
                context.draw(text, at: CGPoint(x: sx, y: origin.y + 12), anchor: .top)
            }
            x += step
        }
        
        // Draw Horizontal Lines & Y Labels
        var y = floor(minYMath / step) * step
        while y <= maxYMath {
            let sy = origin.y - y * scale
            minorPath.move(to: CGPoint(x: 0, y: sy))
            minorPath.addLine(to: CGPoint(x: size.width, y: sy))
            
            if y != 0 {
                let text = Text(y.cleanMathString).font(.system(size: 10)).foregroundColor(.secondary)
                context.draw(text, at: CGPoint(x: origin.x - 6, y: sy), anchor: .trailing)
            }
            y += step
        }
        
        context.stroke(minorPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 1)
        
        // Draw Main Axes
        var axesPath = Path()
        axesPath.move(to: CGPoint(x: origin.x, y: 0))
        axesPath.addLine(to: CGPoint(x: origin.x, y: size.height))
        axesPath.move(to: CGPoint(x: 0, y: origin.y))
        axesPath.addLine(to: CGPoint(x: size.width, y: origin.y))
        
        context.stroke(axesPath, with: .color(Color.primary.opacity(0.6)), lineWidth: 2)
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
        
        context.stroke(linePath, with: .color(.purple), lineWidth: 3)
    }
    
    // MARK: Gestures & Mathematics
    private func handleTap(location: CGPoint, origin: CGPoint, scale: CGFloat, step: CGFloat) {
        let mathX = (location.x - origin.x) / scale
        let mathY = (origin.y - location.y) / scale
        
        // Snap naturally to 1/5th of the dynamic grid step
        let snap = step / 5.0
        let snappedP = CGPoint(x: round(mathX / snap) * snap, y: round(mathY / snap) * snap)
        
        if graphType == QuestionGraphType.equation.rawValue {
            if points.count >= 2 { points.removeAll() }
            points.append(snappedP)
            if points.count == 2 { generateLinearEquation() } else { content = "" }
        } else {
            points.append(snappedP)
            generatePointsString()
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func generateLinearEquation() {
        // Prevent index out of range crash by ensuring both points exist
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
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 2)
                .offset(y: -30) // Keeps the text floating above the user's finger
            
            Circle()
                .fill(Color.purple)
                .frame(width: 24, height: 24) // Slightly larger visual point
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.2), radius: 3)
        }
        .frame(width: 60, height: 60) // Generous invisible touch target
        .contentShape(Rectangle()) // Ensures the entire 60x60 area is draggable
        .position(screenP)
        .highPriorityGesture( // Forces the point's drag to override the canvas's pan gesture
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    if dragInitial == nil { dragInitial = point }
                    let start = dragInitial!
                    
                    let mathDx = val.translation.width / scale
                    let mathDy = -val.translation.height / scale // Invert Y
                    
                    let rawP = CGPoint(x: start.x + mathDx, y: start.y + mathDy)
                    
                    let snap = step / 5.0
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
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    
    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $currentTab) {
                ForEach(KeypadTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 8) {
                switch currentTab {
                case .num:
                    keyButton("7", display: "7")
                    keyButton("8", display: "8")
                    keyButton("9", display: "9")
                    keyButton(" / ", display: "÷", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color(UIColor.systemGray4))
                    
                    keyButton("4", display: "4")
                    keyButton("5", display: "5")
                    keyButton("6", display: "6")
                    keyButton(" * ", display: "×", color: Color(UIColor.systemGray5))
                    keyButton("(", display: "(", color: Color(UIColor.systemGray5))
                    
                    keyButton("1", display: "1")
                    keyButton("2", display: "2")
                    keyButton("3", display: "3")
                    keyButton(" - ", display: "-", color: Color(UIColor.systemGray5))
                    keyButton(")", display: ")", color: Color(UIColor.systemGray5))
                    
                    keyButton("0", display: "0")
                    keyButton(".", display: ".")
                    keyButton(" = ", display: "=", color: Color(UIColor.systemGray5))
                    keyButton(" + ", display: "+", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color(UIColor.systemGray4))
                    
                case .fn:
                    keyButton("sin(", display: "sin")
                    keyButton("cos(", display: "cos")
                    keyButton("tan(", display: "tan")
                    keyButton("ln(", display: "ln")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color(UIColor.systemGray4))
                    
                    keyButton("csc(", display: "csc")
                    keyButton("sec(", display: "sec")
                    keyButton("cot(", display: "cot")
                    keyButton("log(", display: "log")
                    keyButton("^(", display: "xⁿ", color: Color(UIColor.systemGray5))
                    
                    keyButton("x", display: "x", color: Color(UIColor.systemGray5))
                    keyButton("y", display: "y", color: Color(UIColor.systemGray5))
                    keyButton("e^(", display: "eⁿ", color: Color(UIColor.systemGray5))
                    keyButton("}", display: "}", color: Color(UIColor.systemGray5))
                    keyButton("√(", display: "√", color: Color(UIColor.systemGray5))
                    
                    keyButton("a", display: "a", color: Color(UIColor.systemGray5))
                    keyButton("b", display: "b", color: Color(UIColor.systemGray5))
                    keyButton("{", display: "{", color: Color(UIColor.systemGray5))
                    keyButton("}", display: "}", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color(UIColor.systemGray4))
                    
                case .sym:
                    keyButton("π", display: "π")
                    keyButton("θ", display: "θ")
                    keyButton("α", display: "α")
                    keyButton("β", display: "β")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color(UIColor.systemGray4))
                    
                    keyButton(" ≤ ", display: "≤")
                    keyButton(" ≥ ", display: "≥")
                    keyButton(" ≠ ", display: "≠")
                    keyButton(" ≈ ", display: "≈")
                    keyButton(" / ", display: "a/b", color: Color(UIColor.systemGray5))
                    
                    keyButton("∫", display: "∫")
                    keyButton("∑", display: "∑")
                    keyButton("∞", display: "∞")
                    keyButton("°", display: "°")
                    keyButton("^(2)", display: "x²", color: Color(UIColor.systemGray5))
                    
                    keyButton("(", display: "(", color: Color(UIColor.systemGray5))
                    keyButton(")", display: ")", color: Color(UIColor.systemGray5))
                    keyButton("{", display: "{", color: Color(UIColor.systemGray5))
                    keyButton("}", display: "}", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color(UIColor.systemGray4))
                }
            }
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    private func backspace() {
        if !text.isEmpty { text.removeLast() }
    }
    
    @ViewBuilder
    private func keyButton(_ insertString: String, display: String, color: Color = Color(UIColor.systemBackground)) -> some View {
        Button(action: { text.append(insertString) }) {
            Text(display)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func actionButton(systemName: String, action: @escaping () -> Void, color: Color) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                .foregroundColor(.primary)
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
