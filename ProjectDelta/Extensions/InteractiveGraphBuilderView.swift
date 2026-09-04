//
//  InteractiveGraphBuilderView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/4/26.
//


//
//  InteractiveGraphBuilderView.swift
//  ProjectDelta
//

import SwiftUI

struct InteractiveGraphBuilderView: View {
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
        let targetSpacing: CGFloat = 85.0
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
            
            if abs(x) > 0.0001 {
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
        
        if graphType == QuestionGraphType.points.rawValue {
            let graphData = GraphContentParser.graphData(from: trimmedContent, graphType: graphType)
            points = zip(graphData.xValues, graphData.yValues)
                .filter { !$0.0.isNaN && !$0.1.isNaN && !$0.0.isInfinite && !$0.1.isInfinite }
                .map { CGPoint(x: $0.0, y: $0.1) }
        }
    }
}

// MARK: - Draggable Labeled Point Subview
struct DraggablePointView: View {
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