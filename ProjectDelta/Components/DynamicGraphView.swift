//
//  DynamicGraphView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/23/24.
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

    var primaryColor: Color { colorScheme == .dark ? .teal : .blue }
    var secondaryColor: Color { colorScheme == .dark ? .orange : .purple }
    private var surfaceColor: Color { colorScheme == .dark ? Color.black.opacity(0.28) : Color.white }
    private var plotSurfaceColor: Color { colorScheme == .dark ? Color.white.opacity(0.045) : Color.blue.opacity(0.035) }
    private var borderColor: Color { colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.07) }
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

    private var hasSecondarySeries: Bool {
        activeSeries.count > 1 || data.secondaryYValues?.isEmpty == false
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
    
    private var sortedPrimaryIndices: [Int] {
        let validCount = min(data.xValues.count, data.yValues.count)
        return (0..<validCount).sorted { data.xValues[$0] < data.xValues[$1] }
    }
        
    private var sortedSecondaryIndices: [Int]? {
        guard let secondaryY = data.secondaryYValues else { return nil }
        let validCount = min(data.xValues.count, secondaryY.count)
        return (0..<validCount).sorted { data.xValues[$0] < data.xValues[$1] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Graph", systemImage: "chart.xyaxis.line")
                        .font(.caption)
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(Array(activeSeries.prefix(4).enumerated()), id: \.offset) { index, series in
                            equationPill(series.label, color: colorForSeries(at: index))
                        }
                        
                        if activeSeries.count > 4 {
                            Text("+\(activeSeries.count - 4)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundColor(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer(minLength: 12)
                
                if let inequality = data.inequality {
                    Label(inequality.shadeAbove ? "Above" : "Below", systemImage: "switch.2")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(primaryColor.opacity(0.11))
                        .foregroundColor(primaryColor)
                        .clipShape(Capsule())
                }
            }
            
            Chart {
                if adjustedXDomain().contains(0) {
                    RuleMark(x: .value("Y Axis", 0))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1.2))
                }
                
                if adjustedYDomain().contains(0) {
                    RuleMark(y: .value("X Axis", 0))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1.2))
                }
                
                if let inequality = data.inequality {
                    ForEach(sortedPrimaryIndices, id: \.self) { index in
                        let xValue = data.xValues[index]
                        let yLineValue = inequality.slope * xValue + inequality.intercept
                        let yStartValue = inequality.shadeAbove ? yLineValue : adjustedYDomain().lowerBound
                        let yEndValue = inequality.shadeAbove ? adjustedYDomain().upperBound : yLineValue
                        
                        AreaMark(
                            x: .value("X Value", xValue),
                            yStart: .value("Y Start", yStartValue),
                            yEnd: .value("Y End", yEndValue)
                        )
                        .foregroundStyle(primaryColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
                    }
                }
                
                ForEach(Array(activeSeries.enumerated()), id: \.offset) { seriesIndex, series in
                    let validCount = min(series.xValues.count, series.yValues.count)
                    let sortedIndices = (0..<validCount).sorted { series.xValues[$0] < series.xValues[$1] }
                    let seriesColor = colorForSeries(at: seriesIndex)
                    
                    ForEach(sortedIndices, id: \.self) { pointIndex in
                        let xValue = series.xValues[pointIndex]
                        let yValue = series.yValues[pointIndex]
                        
                        // LineMark inherently handles Double.nan by breaking the line, which is perfect for asymptotes
                        LineMark(
                            x: .value("X Value", xValue),
                            y: .value("Y Value", yValue),
                            series: .value("Series", series.label)
                        )
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(seriesColor)
                        
                        if validCount <= 24 && !yValue.isNaN {
                            PointMark(
                                x: .value("X Value", xValue),
                                y: .value("Y Value", yValue)
                            )
                            .symbol(Circle())
                            .symbolSize(72)
                            .foregroundStyle(seriesColor)
                        }
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: activeSeries.map { $0.label },
                range: activeSeries.indices.map { colorForSeries(at: $0) }
            )
            .chartLegend(.hidden)
            .chartXScale(domain: adjustedXDomain())
            .chartYScale(domain: adjustedYDomain())
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.16))
                    AxisTick().foregroundStyle(Color.secondary.opacity(0.32))
                    AxisValueLabel() {
                        if let axisValue = value.as(Double.self) {
                            Text(axisValue.cleanGraphString)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.16))
                    AxisTick().foregroundStyle(Color.secondary.opacity(0.32))
                    AxisValueLabel() {
                        if let axisValue = value.as(Double.self) {
                            Text(axisValue.cleanGraphString)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(plotSurfaceColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 270)
        }
        .padding(18)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, x: 0, y: 10)
        .padding(.horizontal)
    }

    private func colorForSeries(at index: Int) -> Color {
        seriesColors[index % seriesColors.count]
    }

    @ViewBuilder
    private func equationPill(_ equation: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(equation)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(colorScheme == .dark ? 0.18 : 0.11))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    func adjustedXDomain() -> ClosedRange<Double> {
        let validX = activeSeries.flatMap { $0.xValues }.filter { !$0.isNaN }
        guard let minX = validX.min(), let maxX = validX.max() else { return 0...10 }
        
        if minX == maxX {
            return (minX - 1)...(maxX + 1)
        } else {
            let xRange = maxX - minX
            return (minX - 0.15 * xRange)...(maxX + 0.15 * xRange)
        }
    }

    func adjustedYDomain() -> ClosedRange<Double> {
        let allYValues = activeSeries.flatMap { $0.yValues }.filter { !$0.isNaN && !$0.isInfinite && abs($0) < 1000 }
        guard let minY = allYValues.min(), let maxY = allYValues.max() else { return -10...10 }
        
        if minY == maxY {
            return (minY - 1)...(maxY + 1)
        } else {
            let yRange = maxY - minY
            return (minY - 0.15 * yRange)...(maxY + 0.15 * yRange)
        }
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
    
    /// Compiles a math expression string into an ultra-fast `(Double) -> Double` closure using RPN architecture.
    public static func compile(_ equation: String) -> ((Double) -> Double)? {
        let tokens = tokenize(equation)
        guard !tokens.isEmpty else { return nil }
        let rpn = toRPN(tokens)
        
        return { x in
            evaluateRPN(rpn, x: x)
        }
    }
    
    /// Safely samples continuous mathematical curves into discrete series data for SwiftUI Charts.
    public static func samplePoints(for equation: String, domain: ClosedRange<Double> = -15...15, step: Double = 0.1) -> GraphData.Series? {
        guard let evaluator = compile(equation) else { return nil }
        
        var xVals: [Double] = []
        var yVals: [Double] = []
        var previousY: Double? = nil
        
        for x in stride(from: domain.lowerBound, through: domain.upperBound, by: step) {
            let y = evaluator(x)
            
            // Asymptote & Infinity Discontinuity Break
            if y.isNaN || y.isInfinite || abs(y) > 2000 {
                xVals.append(x)
                yVals.append(.nan)
                previousY = nil
            } else {
                // High-velocity slope break detection (e.g., jump from 1/x at x=0)
                if let prev = previousY, abs(y - prev) > 50 {
                    xVals.append(x - step/2) // Insert midpoint nan break
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
            
            // Numbers
            if char.isNumber || char == "." {
                var numStr = ""
                while index < chars.count && (chars[index].isNumber || chars[index] == ".") {
                    numStr.append(chars[index])
                    index += 1
                }
                if let val = Double(numStr) {
                    tokens.append(.number(val))
                    // Implicit Multiplication (e.g. 2x -> 2 * x, 2(x) -> 2 * (x))
                    if index < chars.count && (chars[index] == "x" || chars[index] == "(" || chars[index].isLetter) {
                        tokens.append(.op(.mul))
                    }
                }
                continue
            }
            
            // Variable x
            if char == "x" {
                tokens.append(.variable)
                index += 1
                // Implicit Multiplication (e.g. x( -> x * (, xx -> x * x)
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            // Euler's Number
            if char == "e" {
                tokens.append(.number(M_E))
                index += 1
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index] == "x" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            // Pi
            if char == "p" && index + 1 < chars.count && chars[index+1] == "i" {
                tokens.append(.number(.pi))
                index += 2
                if index < chars.count && (chars[index] == "(" || chars[index].isNumber || chars[index] == "x" || chars[index].isLetter) {
                    tokens.append(.op(.mul))
                }
                continue
            }
            
            // Math Functions (sin, cos, ln, sqrt, etc.)
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
            
            // Operators (+, -, *, /, ^)
            if let op = Operator(rawValue: char) {
                // Detect Unary Minus
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
            
            // Parentheses
            if char == "(" {
                tokens.append(.openParen)
                index += 1
                continue
            }
            if char == ")" {
                tokens.append(.closeParen)
                index += 1
                // Implicit Multiplication mapping for trailing parens (e.g., (2+2)x -> (2+2)*x)
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
            .replacingOccurrences(of: "\n", with: "|") // Handle multi-line blocks safely
        
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

extension Double {
    var cleanGraphString: String {
        abs(self.truncatingRemainder(dividingBy: 1)) < 0.0001 ? String(format: "%.0f", self) : String(format: "%.2f", self)
    }
}

// Helper mathematical functions
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

#Preview {
    ZStack {
        Color.platformSystemGroupedBackground.ignoresSafeArea()
        DynamicGraphView(data: sampleData)
    }
}
