//
//  DynamicGraphView.swift
//  ProjectDelta
//

import Foundation
import SwiftUI
import Charts

// MARK: - GraphData Model
public struct GraphData: Codable, Equatable {
    public struct Series: Codable, Equatable {
        public var label: String
        public var xValues: [Double]
        public var yValues: [Double]
        
        public init(label: String, xValues: [Double], yValues: [Double]) {
            self.label = label
            self.xValues = xValues
            self.yValues = yValues
        }
    }
    
    public var xValues: [Double]
    public var yValues: [Double]
    public var secondaryYValues: [Double]?
    public var inequality: Inequality?
    public var series: [Series]?
    
    public struct Inequality: Codable, Equatable {
        public var slope: Double
        public var intercept: Double
        public var shadeAbove: Bool
        
        public init(slope: Double, intercept: Double, shadeAbove: Bool) {
            self.slope = slope
            self.intercept = intercept
            self.shadeAbove = shadeAbove
        }
    }
    
    public init(xValues: [Double], yValues: [Double], secondaryYValues: [Double]? = nil, inequality: Inequality? = nil, series: [Series]? = nil) {
        self.xValues = xValues
        self.yValues = yValues
        self.secondaryYValues = secondaryYValues
        self.inequality = inequality
        self.series = series
    }
}

// Sample data for the graph
let sampleData = GraphData(
    xValues: [1.0, 2.0, 3.0, 4.0, 5.0],
    yValues: [5.0, 7.0, 9.0, 11.0, 13.0],  // y = 2x + 3
    secondaryYValues: [4.0, 3.0, 2.0, 1.0, 0.0]  // y = -x + 5
)

struct DynamicGraphView: View {
    var data: GraphData
    @Environment(\.colorScheme) var colorScheme

    // Viewport and Interaction State
    @State private var currentScale: CGFloat = 30.0
    @State private var lastScale: CGFloat = 30.0
    
    @State private var currentPan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    
    // Tap and Hold Probe State
    @State private var probeLocation: CGPoint? = nil

    var primaryColor: Color { colorScheme == .dark ? .teal : .blue }
    var secondaryColor: Color { colorScheme == .dark ? .orange : .purple }
    private var seriesColors: [Color] {
        colorScheme == .dark
        ? [.teal, .orange, .pink, .cyan, .mint, .yellow]
        : [.blue, .purple, .teal, .orange, .pink, .indigo]
    }
    
    var primaryEquation: String {
        if let firstSeries = activeSeries.first {
            return firstSeries.label
        }
        
        if let regressionLine = linearRegression(x: data.xValues, y: data.yValues) {
            let slope = String(format: (regressionLine.slope.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.slope)
            let intercept = String(format: (regressionLine.intercept.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.intercept)
            if abs(regressionLine.slope) < 0.0001 {
                return "y = \(intercept)"
            }
            return "y = \(slope)x \(regressionLine.intercept >= 0 ? "+" : "-") \(abs(Double(intercept) ?? 0).cleanGraphString)"
        } else {
            return "Primary Line"
        }
    }

    var secondaryEquation: String {
        if let secondaryYValues = data.secondaryYValues,
           let regressionLine = linearRegression(x: data.xValues, y: secondaryYValues) {
            let slope = String(format: (regressionLine.slope.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.slope)
            let intercept = String(format: (regressionLine.intercept.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.intercept)
            if abs(regressionLine.slope) < 0.0001 {
                return "y = \(intercept)"
            }
            return "y = \(slope)x \(regressionLine.intercept >= 0 ? "+" : "-") \(abs(Double(intercept) ?? 0).cleanGraphString)"
        } else {
            return "Secondary Line"
        }
    }

    private var activeSeries: [GraphData.Series] {
        if let series = data.series, !series.isEmpty {
            return series
        }
        
        var legacySeries = [GraphData.Series(label: primaryEquationFromRegression, xValues: data.xValues, yValues: data.yValues)]
        if let secondaryYValues = data.secondaryYValues {
            legacySeries.append(GraphData.Series(label: secondaryEquation, xValues: data.xValues, yValues: secondaryYValues))
        }
        return legacySeries
    }
    
    private var primaryEquationFromRegression: String {
        if let regressionLine = linearRegression(x: data.xValues, y: data.yValues) {
            let slope = String(format: (regressionLine.slope.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.slope)
            let intercept = String(format: (regressionLine.intercept.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.intercept)
            if abs(regressionLine.slope) < 0.0001 {
                return "y = \(intercept)"
            }
            return "y = \(slope)x \(regressionLine.intercept >= 0 ? "+" : "-") \(abs(Double(intercept) ?? 0).cleanGraphString)"
        }
        return "Primary Line"
    }

    var body: some View {
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
                    
                    if let inequality = data.inequality {
                        drawInequality(context: context, inequality: inequality, origin: origin, scale: currentScale, canvasSize: canvasSize, color: primaryColor)
                    }
                    
                    for (index, series) in activeSeries.enumerated() {
                        let color = colorForSeries(at: index)
                        
                        let cleanLabel = series.label.lowercased().replacingOccurrences(of: " ", with: "")
                        let isEquation = cleanLabel.hasPrefix("y=") || cleanLabel.contains("x") || Double(cleanLabel) != nil
                        
                        if isEquation, let evaluator = MathEngine.compile(series.label) {
                            drawEquationCurve(context: context, evaluator: evaluator, origin: origin, scale: currentScale, canvasSize: canvasSize, color: color)
                        } else {
                            drawDiscreteSeries(context: context, series: series, origin: origin, scale: currentScale, canvasSize: canvasSize, color: color)
                        }
                    }
                }
                
                // MARK: Invisible Gestures Layer
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { val in
                                currentPan = CGSize(width: lastPan.width + val.translation.width, height: lastPan.height + val.translation.height)
                            }
                            .onEnded { _ in
                                lastPan = currentPan
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.25)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                switch value {
                                case .second(true, let drag):
                                    if let location = drag?.location {
                                        probeLocation = location
                                        // Trigger haptic on initial press engagement
                                        #if os(iOS)
                                        if probeLocation == nil {
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                        }
                                        #endif
                                    }
                                default:
                                    break
                                }
                            }
                            .onEnded { _ in
                                probeLocation = nil
                            }
                    )
                    .simultaneousGesture(
                        MagnifyGesture()
                            .onChanged { val in
                                let newScale = lastScale * val.magnification
                                if newScale.isFinite && newScale > 0 {
                                    currentScale = max(5.0, min(newScale, 300.0))
                                }
                            }
                            .onEnded { _ in
                                lastScale = currentScale
                            }
                    )
                
                // MARK: Tap and Hold Probe Overlay
                if let probe = probeLocation {
                    let mathX = Double((probe.x - origin.x) / currentScale)
                    if let closestData = findClosestPoint(to: probe, mathX: mathX, origin: origin, scale: currentScale) {
                        
                        // Vertical Guide Line
                        Path { p in
                            p.move(to: CGPoint(x: closestData.screenPoint.x, y: 0))
                            p.addLine(to: CGPoint(x: closestData.screenPoint.x, y: size.height))
                        }
                        .stroke(closestData.color.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        
                        // Origin Guide Ring
                        Circle()
                            .fill(Color.platformSecondarySystemGroupedBackground)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(closestData.color, lineWidth: 3.5))
                            .shadow(color: .black.opacity(0.2), radius: 4)
                            .position(closestData.screenPoint)
                        
                        // Coordinate Label
                        Text("(\(mathX.cleanGraphString), \(closestData.mathY.cleanGraphString))")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? closestData.color : closestData.color.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(closestData.color.opacity(colorScheme == .dark ? 0.22 : 0.12))
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                            .position(x: closestData.screenPoint.x, y: closestData.screenPoint.y - 32)
                    }
                }
                
                // MARK: Dynamic Legend Overlay
                if !activeSeries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(activeSeries.enumerated()), id: \.offset) { index, series in
                            let color = colorForSeries(at: index)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                Text(series.label)
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
                
                // Reset Viewport Control
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if currentScale != 30.0 || currentPan != .zero {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    currentScale = 30.0
                                    lastScale = 30.0
                                    currentPan = .zero
                                    lastPan = .zero
                                }
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .background(Color.platformSecondarySystemGroupedBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08), lineWidth: 1.5))
            .clipped()
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
        }
        .frame(minHeight: 320, idealHeight: 400, maxHeight: 500)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func colorForSeries(at index: Int) -> Color {
        seriesColors[index % seriesColors.count]
    }
    
    // MARK: - Mathematical Probe Calculator
    private func findClosestPoint(to probe: CGPoint, mathX: Double, origin: CGPoint, scale: CGFloat) -> (screenPoint: CGPoint, mathY: Double, color: Color)? {
        var closestPoint: CGPoint? = nil
        var closestMathY: Double? = nil
        var minDistance: CGFloat = .infinity
        var closestColor: Color = .primary
        
        for (index, series) in activeSeries.enumerated() {
            let color = colorForSeries(at: index)
            let cleanLabel = series.label.lowercased().replacingOccurrences(of: " ", with: "")
            let isEquation = cleanLabel.hasPrefix("y=") || cleanLabel.contains("x") || Double(cleanLabel) != nil
            
            if isEquation, let evaluator = MathEngine.compile(series.label) {
                let mathY = evaluator(mathX)
                if !mathY.isNaN && !mathY.isInfinite {
                    let screenY = origin.y - CGFloat(mathY) * scale
                    let dist = abs(screenY - probe.y)
                    if dist < minDistance {
                        minDistance = dist
                        closestPoint = CGPoint(x: origin.x + CGFloat(mathX) * scale, y: screenY)
                        closestMathY = mathY
                        closestColor = color
                    }
                }
            } else if !series.xValues.isEmpty {
                // Discrete Point Snapping
                if let closestIndex = series.xValues.enumerated().min(by: { abs($0.element - mathX) < abs($1.element - mathX) })?.offset {
                    let cMathX = series.xValues[closestIndex]
                    let cMathY = series.yValues[closestIndex]
                    
                    let screenX = origin.x + CGFloat(cMathX) * scale
                    let screenY = origin.y - CGFloat(cMathY) * scale
                    
                    let dist = abs(screenX - probe.x) + abs(screenY - probe.y)
                    if dist < minDistance {
                        minDistance = dist
                        closestPoint = CGPoint(x: screenX, y: screenY)
                        closestMathY = cMathY
                        closestColor = color
                    }
                }
            }
        }
        
        if let cp = closestPoint, let cmy = closestMathY {
            return (screenPoint: cp, mathY: cmy, color: closestColor)
        }
        return nil
    }

    // MARK: - Adaptive Grid System
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
    
    private func drawEquationCurve(context: GraphicsContext, evaluator: @escaping (Double) -> Double, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        var path = Path()
        var isFirst = true
        var previousScreenY: CGFloat? = nil
        
        for screenX in stride(from: 0, through: canvasSize.width, by: 2) {
            let mathX = Double((screenX - origin.x) / scale)
            let mathY = evaluator(mathX)
            
            if mathY.isNaN || mathY.isInfinite {
                isFirst = true
                previousScreenY = nil
                continue
            }
            
            let screenY = origin.y - CGFloat(mathY) * scale
            
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
    
    private func drawDiscreteSeries(context: GraphicsContext, series: GraphData.Series, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        let validCount = min(series.xValues.count, series.yValues.count)
        guard validCount > 0 else { return }
        
        var path = Path()
        var isFirst = true
        
        let sortedIndices = (0..<validCount).sorted { series.xValues[$0] < series.xValues[$1] }
        
        for index in sortedIndices {
            let x = series.xValues[index]
            let y = series.yValues[index]
            
            if x.isNaN || y.isNaN || x.isInfinite || y.isInfinite {
                isFirst = true
                continue
            }
            
            let screenX = origin.x + CGFloat(x) * scale
            let screenY = origin.y - CGFloat(y) * scale
            let pt = CGPoint(x: screenX, y: screenY)
            
            if isFirst {
                path.move(to: pt)
                isFirst = false
            } else {
                path.addLine(to: pt)
            }
            
            if validCount <= 24 {
                let rect = CGRect(x: screenX - 4, y: screenY - 4, width: 8, height: 8)
                let pointPath = Path(ellipseIn: rect)
                context.fill(pointPath, with: .color(color))
            }
        }
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    
    private func drawInequality(context: GraphicsContext, inequality: GraphData.Inequality, origin: CGPoint, scale: CGFloat, canvasSize: CGSize, color: Color) {
        var path = Path()
        let m = CGFloat(inequality.slope)
        let b = CGFloat(inequality.intercept)
        
        let mathX1 = (0 - origin.x) / scale
        let mathX2 = (canvasSize.width - origin.x) / scale
        
        let mathY1 = m * mathX1 + b
        let mathY2 = m * mathX2 + b
        
        let screenY1 = origin.y - mathY1 * scale
        let screenY2 = origin.y - mathY2 * scale
        
        path.move(to: CGPoint(x: 0, y: screenY1))
        path.addLine(to: CGPoint(x: canvasSize.width, y: screenY2))
        
        if inequality.shadeAbove {
            path.addLine(to: CGPoint(x: canvasSize.width, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
        } else {
            path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
            path.addLine(to: CGPoint(x: 0, y: canvasSize.height))
        }
        path.closeSubpath()
        
        context.fill(path, with: .color(color.opacity(colorScheme == .dark ? 0.24 : 0.14)))
    }
}

// MARK: - Advanced High-Performance Swift Math Engine
public enum MathEngine {
    
    enum Token: Equatable {
        case number(Double)
        case variable
        case op(Operator)
        case function(MathFunction)
        case openParen
        case closeParen
    }
    
    enum Operator: Character {
        case add = "+", sub = "-", mul = "*", div = "/", pow = "^"
        var precedence: Int {
            switch self { case .add, .sub: return 1; case .mul, .div: return 2; case .pow: return 3 }
        }
        var isRightAssociative: Bool { self == .pow }
    }
    
    enum MathFunction: String {
        case sin, cos, tan, ln, log, sqrt, abs
    }
    
    public static func compile(_ equation: String) -> ((Double) -> Double)? {
        let tokens = tokenize(equation)
        guard !tokens.isEmpty else { return nil }
        let rpn = toRPN(tokens)
        
        return { x in
            evaluateRPN(rpn, x: x)
        }
    }
    
    public static func samplePoints(for equation: String, domain: ClosedRange<Double> = -15...15, step: Double = 0.1) -> GraphData.Series? {
        guard let evaluator = compile(equation) else { return nil }
        
        var xVals: [Double] = []
        var yVals: [Double] = []
        var previousY: Double? = nil
        
        for x in stride(from: domain.lowerBound, through: domain.upperBound, by: step) {
            let y = evaluator(x)
            
            if y.isNaN || y.isInfinite || abs(y) > 2000 {
                xVals.append(x)
                yVals.append(.nan)
                previousY = nil
            } else {
                if let prev = previousY, abs(y - prev) > 50 {
                    xVals.append(x - step/2)
                    yVals.append(.nan)
                }
                xVals.append(x)
                yVals.append(y)
                previousY = y
            }
        }
        
        guard !xVals.isEmpty else { return nil }
        let label = equation.lowercased().hasPrefix("y=") ? equation : "y = \(equation)"
        return GraphData.Series(label: label, xValues: xVals, yValues: yVals)
    }
    
    private static func tokenize(_ eq: String) -> [Token] {
        var tokens: [Token] = []
        let cleanEq = eq.lowercased().replacingOccurrences(of: "y=", with: "").replacingOccurrences(of: " ", with: "")
        let chars = Array(cleanEq)
        var index = 0
        
        while index < chars.count {
            let char = chars[index]
            
            if char.isNumber || char == "." {
                var numStr = ""
                while index < chars.count && (chars[index].isNumber || chars[index] == ".") {
                    numStr.append(chars[index])
                    index += 1
                }
                if let val = Double(numStr) {
                    tokens.append(.number(val))
                    if index < chars.count && (chars[index] == "x" || chars[index] == "(" || chars[index].isLetter) {
                        tokens.append(.op(.mul))
                    }
                }
                continue
            }
            
            if char == "x" {
                tokens.append(.variable)
                index += 1
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            if char == "e" {
                tokens.append(.number(M_E))
                index += 1
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index] == "x" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            if char == "p" && index + 1 < chars.count && chars[index+1] == "i" {
                tokens.append(.number(.pi))
                index += 2
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index] == "x" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            if char.isLetter {
                var fnStr = ""
                while index < chars.count && chars[index].isLetter {
                    fnStr.append(chars[index])
                    index += 1
                }
                if let fn = MathFunction(rawValue: fnStr) {
                    tokens.append(.function(fn))
                }
                continue
            }
            
            if let op = Operator(rawValue: char) {
                if op == .sub {
                    let isUnary = tokens.isEmpty ||
                    (tokens.last != .variable && tokens.last != .closeParen &&
                     (tokens.last == .openParen || isOperator(tokens.last)))
                    
                    if isUnary {
                        tokens.append(.number(-1))
                        tokens.append(.op(.mul))
                        index += 1
                        continue
                    }
                }
                tokens.append(.op(op))
                index += 1
                continue
            }
            
            if char == "(" {
                tokens.append(.openParen)
                index += 1
                continue
            }
            if char == ")" {
                tokens.append(.closeParen)
                index += 1
                if index < chars.count && (chars[index] == "x" || chars[index].isNumber || chars[index] == "(" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            index += 1
        }
        return tokens
    }
    
    private static func isOperator(_ token: Token?) -> Bool {
        guard let token = token else { return false }
        if case .op = token { return true }
        return false
    }
    
    private static func toRPN(_ tokens: [Token]) -> [Token] {
        var output: [Token] = []
        var opStack: [Token] = []
        
        for token in tokens {
            switch token {
            case .number, .variable:
                output.append(token)
            case .function:
                opStack.append(token)
            case .op(let o1):
                while let last = opStack.last {
                    if case .function = last {
                        output.append(opStack.removeLast())
                        continue
                    }
                    if case .op(let o2) = last {
                        if (!o1.isRightAssociative && o1.precedence <= o2.precedence) ||
                           (o1.isRightAssociative && o1.precedence < o2.precedence) {
                            output.append(opStack.removeLast())
                            continue
                        }
                    }
                    break
                }
                opStack.append(token)
            case .openParen:
                opStack.append(token)
            case .closeParen:
                while let last = opStack.last, last != .openParen {
                    output.append(opStack.removeLast())
                }
                if opStack.last == .openParen {
                    opStack.removeLast()
                }
                if let last = opStack.last, case .function = last {
                    output.append(opStack.removeLast())
                }
            }
        }
        while let last = opStack.last {
            output.append(opStack.removeLast())
        }
        return output
    }
    
    private static func evaluateRPN(_ rpn: [Token], x: Double) -> Double {
        var stack: [Double] = []
        for token in rpn {
            switch token {
            case .number(let val):
                stack.append(val)
            case .variable:
                stack.append(x)
            case .op(let op):
                let b = stack.popLast() ?? 0
                let a = stack.popLast() ?? 0
                switch op {
                case .add: stack.append(a + b)
                case .sub: stack.append(a - b)
                case .mul: stack.append(a * b)
                case .div: stack.append(a / b)
                case .pow: stack.append(pow(a, b))
                }
            case .function(let fn):
                let a = stack.popLast() ?? 0
                switch fn {
                case .sin: stack.append(sin(a))
                case .cos: stack.append(cos(a))
                case .tan: stack.append(tan(a))
                case .ln: stack.append(log(a))
                case .log: stack.append(log10(a))
                case .sqrt: stack.append(a < 0 ? .nan : sqrt(a))
                case .abs: stack.append(abs(a))
                }
            default: break
            }
        }
        return stack.first ?? .nan
    }
}

enum GraphContentParser {
    static func graphData(from content: String, graphType: String? = nil) -> GraphData {
        let normalizedType = graphType?.lowercased() ?? ""
        let normalizedContent = graphContent(from: content)
        let isPointsGraph = normalizedType.contains("point") || normalizedContent.contains("(")

        if isPointsGraph, let pointsData = pointsGraphData(from: normalizedContent) {
            return pointsData
        }

        return equationGraphData(from: normalizedContent)
    }

    static func graphType(from legacyGraphString: String) -> String? {
        if legacyGraphString.contains("type=points") {
            return QuestionGraphType.points.rawValue
        }
        if legacyGraphString.contains("type=equation") {
            return QuestionGraphType.equation.rawValue
        }
        return nil
    }

    static func graphContent(from legacyGraphString: String) -> String {
        if let equationRange = legacyGraphString.range(of: "equation=") {
            return String(legacyGraphString[equationRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let pointsRange = legacyGraphString.range(of: "points=") {
            return String(legacyGraphString[pointsRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return legacyGraphString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func pointsGraphData(from content: String) -> GraphData? {
        let cleanedContent = content
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "type=points", with: "")
            .replacingOccurrences(of: "points=", with: "")
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "\n", with: "")

        var xValues: [Double] = []
        var yValues: [Double] = []
        let pointStrings = cleanedContent.components(separatedBy: "),(")

        for pointString in pointStrings {
            let coordinates = pointString
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .components(separatedBy: ",")

            if coordinates.count == 2,
               let xValue = Double(coordinates[0]),
               let yValue = Double(coordinates[1]) {
                xValues.append(xValue)
                yValues.append(yValue)
            }
        }

        guard !xValues.isEmpty else { return nil }
        return GraphData(xValues: xValues, yValues: yValues)
    }

    private static func equationGraphData(from content: String) -> GraphData {
        let cleanedContent = graphContent(from: content)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "type=equation", with: "")
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "\n", with: "|")
        
        let components = cleanedContent.components(separatedBy: "|")
        if components.count > 1 {
            var allSeries: [GraphData.Series] = []
            var primaryX: [Double] = [-10.0, 10.0]
            var primaryY: [Double] = [-10.0, 10.0]
            var secondaryY: [Double]? = nil
            
            for (index, component) in components.enumerated() {
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                
                let eqString = trimmed.replacingOccurrences(of: "y=", with: "")
                if let sampled = MathEngine.samplePoints(for: eqString) {
                    allSeries.append(sampled)
                    if index == 0 {
                        primaryX = sampled.xValues
                        primaryY = sampled.yValues
                    } else if index == 1 {
                        secondaryY = sampled.yValues
                    }
                } else {
                    let line = lineValues(from: eqString)
                    let xValues = [-10.0, 10.0]
                    let yValues = xValues.map { line.slope * $0 + line.intercept }
                    let label = trimmed.hasPrefix("y=") ? trimmed : "y = \(trimmed)"
                    allSeries.append(GraphData.Series(label: label, xValues: xValues, yValues: yValues))
                    
                    if index == 0 {
                        primaryX = xValues
                        primaryY = yValues
                    } else if index == 1 {
                        secondaryY = yValues
                    }
                }
            }
            
            return GraphData(
                xValues: primaryX,
                yValues: primaryY,
                secondaryYValues: secondaryY,
                series: allSeries.isEmpty ? nil : allSeries
            )
        }
        
        let singleEq = cleanedContent.replacingOccurrences(of: "y=", with: "")
        if let sampled = MathEngine.samplePoints(for: singleEq) {
            return GraphData(xValues: sampled.xValues, yValues: sampled.yValues, series: [sampled])
        }
        
        if cleanedContent.starts(with: "x=") {
            let xValue = Double(cleanedContent.replacingOccurrences(of: "x=", with: "")) ?? 0.0
            return GraphData(xValues: [xValue, xValue], yValues: [-10.0, 10.0])
        }
        
        for inequalityOperator in [">=", "<=", ">", "<"] {
            let prefix = "y\(inequalityOperator)"
            if cleanedContent.starts(with: prefix) {
                let equation = String(cleanedContent.dropFirst(prefix.count))
                let line = lineValues(from: equation)
                let xValues = [-10.0, 10.0]
                let yValues = xValues.map { line.slope * $0 + line.intercept }
                return GraphData(
                    xValues: xValues,
                    yValues: yValues,
                    inequality: GraphData.Inequality(
                        slope: line.slope,
                        intercept: line.intercept,
                        shadeAbove: inequalityOperator.contains(">")
                    )
                )
            }
        }
        
        let equation = cleanedContent.replacingOccurrences(of: "y=", with: "")
        let line = lineValues(from: equation)
        
        let xValues = [-10.0, 10.0]
        let yValues = xValues.map { line.slope * $0 + line.intercept }
        return GraphData(xValues: xValues, yValues: yValues)
    }
    
    private static func lineValues(from equation: String) -> (slope: Double, intercept: Double) {
        let cleaned = equation.replacingOccurrences(of: " ", with: "")
        if cleaned.contains("x**") || cleaned.contains("x^") {
            return (slope: 0.0, intercept: 0.0)
        }
        
        let components = cleaned.components(separatedBy: "x")
        guard components.count == 2 else {
            let intercept = Double(cleaned) ?? 0.0
            return (slope: 0.0, intercept: intercept)
        }
        
        let slopeStr = components[0]
        let slope: Double
        if slopeStr.isEmpty || slopeStr == "+" {
            slope = 1.0
        } else if slopeStr == "-" {
            slope = -1.0
        } else {
            slope = Double(slopeStr) ?? 1.0
        }
        
        let interceptStr = components[1]
        let intercept = Double(interceptStr) ?? 0.0
        
        return (slope: slope, intercept: intercept)
    }
}

func linearRegression(x: [Double], y: [Double]) -> (slope: Double, intercept: Double)? {
    guard x.count == y.count && x.count > 1 else { return nil }
    
    let n = Double(x.count)
    let sumX = x.reduce(0, +)
    let sumY = y.reduce(0, +)
    let sumXY = zip(x, y).map(*).reduce(0, +)
    let sumXSquare = x.map { $0 * $0 }.reduce(0, +)
    
    let denominator = (n * sumXSquare - sumX * sumX)
    if denominator == 0 { return (0, 0) }
    
    let slope = (n * sumXY - sumX * sumY) / denominator
    let intercept = (sumY - slope * sumX) / n
    
    return (slope, intercept)
}

extension Double {
    var cleanGraphString: String {
        abs(self.truncatingRemainder(dividingBy: 1)) < 0.0001 ? String(format: "%.0f", self) : String(format: "%.2f", self)
    }
}

extension CGFloat {
    var cleanMathString: String {
        abs(self.truncatingRemainder(dividingBy: 1)) < 0.0001 ? String(format: "%.0f", self) : String(format: "%.2f", self)
    }
}

#Preview {
    ZStack {
        Color.platformSystemGroupedBackground.ignoresSafeArea()
        DynamicGraphView(data: sampleData)
    }
}
