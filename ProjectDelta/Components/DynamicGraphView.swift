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
                        
                        LineMark(
                            x: .value("X Value", xValue),
                            y: .value("Y Value", yValue),
                            series: .value("Series", series.label)
                        )
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(seriesColor)
                        
                        if validCount <= 24 {
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
                data.secondaryYValues == nil
                ? KeyValuePairs(dictionaryLiteral: (primaryEquation, primaryColor))
                : KeyValuePairs(dictionaryLiteral: (primaryEquation, primaryColor), (secondaryEquation, secondaryColor))
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
        guard let minX = data.xValues.min(), let maxX = data.xValues.max() else { return 0...10 }

        if minX == maxX {
            return (minX - 1)...(maxX + 1)
        } else {
            let xRange = maxX - minX
            return (minX - 0.15 * xRange)...(maxX + 0.15 * xRange)
        }
    }

    func adjustedYDomain() -> ClosedRange<Double> {
        let allYValues = data.yValues + (data.secondaryYValues ?? [])
        guard let minY = allYValues.min(), let maxY = allYValues.max() else { return 0...10 }
        
        if minY == maxY {
            return (minY - 1)...(maxY + 1)
        } else {
            let yRange = maxY - minY
            return (minY - 0.15 * yRange)...(maxY + 0.15 * yRange)
        }
    }
}

enum MathEvaluator {
    /// Samples continuous mathematical curves into discrete points for SwiftUI Charts safely.
    static func samplePoints(for equation: String, domain: ClosedRange<Double> = -15...15, step: Double = 0.2) -> GraphData.Series? {
        var exprString = equation
            .lowercased()
            .replacingOccurrences(of: "y=", with: "")
            .replacingOccurrences(of: " ", with: "")
            
        guard !exprString.isEmpty, !exprString.contains("==") else { return nil }
        
        // Fix implicit multiplication (e.g., "2x" -> "2*x") before NSExpression evaluates
        exprString = exprString.replacingOccurrences(of: "([0-9])x", with: "$1*x", options: .regularExpression)
        exprString = exprString.replacingOccurrences(of: "x([0-9])", with: "x*$1", options: .regularExpression)
        exprString = exprString.replacingOccurrences(of: "^", with: "**")
        
        // Validate expression string to prevent NSExpression from throwing an uncatchable NSException
        let allowedCharacterSet = CharacterSet(charactersIn: "0123456789x.*+-/()")
        guard exprString.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else { return nil }
        
        var balance = 0
        var lastChar: Character = " "
        for char in exprString {
            if char == "(" { balance += 1 }
            if char == ")" { balance -= 1 }
            if balance < 0 { return nil } // Catch unmatched closing parenthesis
            
            let isOp = "+-*/".contains(char)
            let wasOp = "+-*/".contains(lastChar)
            
            // Prevent consecutive operators (except "**" for exponents)
            if isOp && wasOp {
                if !(char == "*" && lastChar == "*") { return nil }
            }
            lastChar = char
        }
        
        guard balance == 0 else { return nil } // Catch unmatched opening parenthesis
        guard let first = exprString.first, !("*/.)".contains(first)) else { return nil }
        guard let last = exprString.last, !("+-*/.(".contains(last)) else { return nil }
        guard !exprString.contains("()"), !exprString.contains("*)"), !exprString.contains("/)") else { return nil }
        
        var xVals: [Double] = []
        var yVals: [Double] = []
        
        let expression: NSExpression
        do {
            expression = NSExpression(format: exprString)
        } catch {
            print("Mathematical syntax error in equation: \(equation)")
            return nil
        }
        
        for x in stride(from: domain.lowerBound, through: domain.upperBound, by: step) {
            let context: NSMutableDictionary = ["x": x]
            if let result = evaluateSafely(expression: expression, context: context) {
                if !result.isNaN && !result.isInfinite && abs(result) < 1000 {
                    xVals.append(x)
                    yVals.append(result)
                }
            }
        }
        
        guard !xVals.isEmpty else { return nil }
        return GraphData.Series(label: equation, xValues: xVals, yValues: yVals)
    }
    
    private static func evaluateSafely(expression: NSExpression, context: NSMutableDictionary) -> Double? {
        @objcMembers class EvaluatorHelper: NSObject {
            var value: Double?
            func evaluate(_ expr: NSExpression, ctx: NSDictionary) {
                if let res = expr.expressionValue(with: ctx, context: nil) as? Double {
                    value = res
                }
            }
        }
        let helper = EvaluatorHelper()
        helper.evaluate(expression, ctx: context)
        return helper.value
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
            .replacingOccurrences(of: "\n", with: "") // Strip newlines to prevent parsing failures

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
            .replacingOccurrences(of: "\n", with: "|") // Added to split multiline editor arrays
        
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
                if let sampled = MathEvaluator.samplePoints(for: eqString) {
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
        if let sampled = MathEvaluator.samplePoints(for: singleEq) {
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
