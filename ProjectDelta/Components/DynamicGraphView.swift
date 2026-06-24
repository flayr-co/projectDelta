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
    public var xValues: [Double]
    public var yValues: [Double]
    public var secondaryYValues: [Double]?
    public var inequality: Inequality?
    
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
    
    public init(xValues: [Double], yValues: [Double], secondaryYValues: [Double]? = nil, inequality: Inequality? = nil) {
        self.xValues = xValues
        self.yValues = yValues
        self.secondaryYValues = secondaryYValues
        self.inequality = inequality
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

    var primaryColor: Color { .teal }
    var secondaryColor: Color { .orange }
    
    var primaryEquation: String {
        if let regressionLine = linearRegression(x: data.xValues, y: data.yValues) {
            let slope = String(format: (regressionLine.slope.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.slope)
            let intercept = String(format: (regressionLine.intercept.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.intercept)
            return "y = \(slope)x \(regressionLine.intercept >= 0 ? "+" : "-") \(abs(Double(intercept) ?? 0))"
        } else {
            return "Primary Line"
        }
    }

    var secondaryEquation: String {
        if let secondaryYValues = data.secondaryYValues,
           let regressionLine = linearRegression(x: data.xValues, y: secondaryYValues) {
            let slope = String(format: (regressionLine.slope.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.slope)
            let intercept = String(format: (regressionLine.intercept.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"), regressionLine.intercept)
            return "y = \(slope)x \(regressionLine.intercept >= 0 ? "+" : "-") \(abs(Double(intercept) ?? 0))"
        } else {
            return "Secondary Line"
        }
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
        VStack(spacing: 16) {
            Chart {
                if let inequality = data.inequality {
                    ForEach(sortedPrimaryIndices, id: \.self) { index in
                        let xValue = data.xValues[index]
                        let yLineValue = inequality.slope * xValue + inequality.intercept
                        let yStartValue = inequality.shadeAbove ? yLineValue : data.yValues.min() ?? yLineValue
                        let yEndValue = inequality.shadeAbove ? data.yValues.max() ?? yLineValue : yLineValue
                        
                        AreaMark(
                            x: .value("X Value", xValue),
                            yStart: .value("Y Start", yStartValue),
                            yEnd: .value("Y End", yEndValue),
                            series: .value("Dataset", "Area") // Isolates the area shading
                        )
                        .foregroundStyle(primaryColor.opacity(0.15))
                    }
                }
                
                // Primary data
                ForEach(sortedPrimaryIndices, id: \.self) { index in
                    let xValue = data.xValues[index]
                    let yValue = data.yValues[index]
                    
                    LineMark(
                        x: .value("X Value", xValue),
                        y: .value("Y Value", yValue),
                        series: .value("Dataset", "Primary") // Isolates the primary equation
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(primaryColor)
                    
                    PointMark(
                        x: .value("X Value", xValue),
                        y: .value("Y Value", yValue)
                    )
                    .symbol(Circle())
                    .symbolSize(60)
                    .foregroundStyle(primaryColor)
                }
                
                // Secondary data (if exists)
                if let secondaryYValues = data.secondaryYValues, let secIndices = sortedSecondaryIndices {
                    ForEach(secIndices, id: \.self) { index in
                        let xValue = data.xValues[index]
                        let yValue = secondaryYValues[index]
                        
                        LineMark(
                            x: .value("X Value", xValue),
                            y: .value("Secondary Y Value", yValue),
                            series: .value("Dataset", "Secondary") // Isolates the secondary equation
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(secondaryColor)
                        
                        PointMark(
                            x: .value("X Value", xValue),
                            y: .value("Secondary Y Value", yValue)
                        )
                        .symbol(Circle())
                        .symbolSize(60)
                        .foregroundStyle(secondaryColor)
                    }
                }
            }
            .chartXScale(domain: (data.xValues.min() ?? 0)...(data.xValues.max() ?? 10))
            .chartYScale(domain: adjustedYDomain())
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                    AxisTick().foregroundStyle(Color.gray.opacity(0.4))
                    AxisValueLabel() {
                        if let intValue = value.as(Double.self) {
                            Text(String(format: "%.0f", intValue))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                    AxisTick().foregroundStyle(Color.gray.opacity(0.4))
                    AxisValueLabel() {
                        if let intValue = value.as(Double.self) {
                            Text(String(format: "%.0f", intValue))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 250)
            .padding()
            .background(Color.platformSystemBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            
            // Custom Clean Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle().fill(primaryColor).frame(width: 8, height: 8)
                    Text(primaryEquation)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                if data.secondaryYValues != nil {
                    HStack(spacing: 6) {
                        Circle().fill(secondaryColor).frame(width: 8, height: 8)
                        Text(secondaryEquation)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    func adjustedYDomain() -> ClosedRange<Double> {
        let allYValues = data.yValues + (data.secondaryYValues ?? [])
        guard let minY = allYValues.min(), let maxY = allYValues.max() else { return 0...10 }
        
        if minY == maxY {
            return (minY - 1)...(maxY + 1)
        } else {
            let yRange = maxY - minY
            return (minY - 0.15 * yRange)...(maxY + 0.15 * yRange) // 15% padding for cleaner visual
        }
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
    if denominator == 0 { return (0, 0) } // Prevent division by zero
    
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
