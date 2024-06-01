//
//  DynamicGraphView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/23/24.
//

import Foundation
import SwiftUI
import Charts

// Sample data for the graph
let sampleData = GraphData(
    xValues: [1.0, 2.0, 3.0, 4.0, 5.0],
    yValues: [28.0, 23.0, 18.0, 13.0, 8.0]
//    yValues: [10.0, 12.0, 14.0, 16.0, 18.0]
)

struct DynamicGraphView: View {
    var data: GraphData
    @Environment(\.colorScheme) var colorScheme

    var isHorizontalLine: Bool {
        return Set(data.yValues).count == 1
    }

    var isVerticalLine: Bool {
        return Set(data.xValues).count == 1
    }

    var regressionLine: (slope: Double, intercept: Double)? {
        linearRegression(x: data.xValues, y: data.yValues)
    }

    var isNegativeSlope: Bool {
        return regressionLine?.slope ?? 0 < 0
    }

    var crossesXAxis: Bool {
        guard let regressionLine = regressionLine else { return false }
        let yValuesAtXMin = regressionLine.slope * data.xValues.min()! + regressionLine.intercept
        let yValuesAtXMax = regressionLine.slope * data.xValues.max()! + regressionLine.intercept
        return (yValuesAtXMin <= 0 && yValuesAtXMax >= 0) || (yValuesAtXMin >= 0 && yValuesAtXMax <= 0)
    }

    var crossesYAxis: Bool {
        guard let regressionLine = regressionLine else { return false }
        return (0 <= data.xValues.max()! && 0 >= data.xValues.min()!)
    }

    var xIncrement: Double {
        let differences = zip(data.xValues.dropFirst(), data.xValues).map(-)
        return differences.max() ?? 1.0
    }

    var yIncrement: Double {
        let differences = zip(data.yValues.dropFirst(), data.yValues).map(-)
        return differences.max() ?? 1.0
    }

    var body: some View {
        VStack {
            if isHorizontalLine {
                HorizontalLineChart(data: data)
            } else if isVerticalLine {
                VerticalLineChart(data: data)
            } else if isNegativeSlope {
                NegativeSlopeGraphView(data: data)
            } else {
                Chart {
                    ForEach(Array(zip(data.xValues.indices, data.yValues.indices)), id: \.self.0) { (xIndex, yIndex) in
                        let xValue = data.xValues[xIndex]
                        let yValue = data.yValues[yIndex]
                        LineMark(
                            x: .value("X Value", xValue),
                            y: .value("Y Value", yValue)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(colorScheme == .dark ? .cyan : .red)

                        PointMark(
                            x: .value("X Value", xValue),
                            y: .value("Y Value", yValue)
                        )
                        .symbol(Circle())
                        .symbolSize(30)
                        .foregroundStyle(colorScheme == .dark ? Color(red: 0.0, green: 0.8, blue: 1.0) : Color(red: 0.7, green: 0.0, blue: 0.0))
                    }
                }
                .chartXScale(domain: (data.xValues.min()!)...(data.xValues.max()!))
                .chartYScale(domain: adjustedYDomain())
                .chartXAxis {
                    AxisMarks(position: .bottom, values: Array(stride(from: data.xValues.min()!, through: data.xValues.max()!, by: xIncrement))) { value in
                        AxisTick()
                        AxisGridLine()
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                                .padding(.leading, -5)
                        }
                    }
                    if crossesYAxis {
                        AxisMarks(position: .bottom, values: [0]) { value in
                            AxisGridLine()
                                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: yAxisValues()) { value in
                        AxisTick()
                        AxisGridLine()
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                                .padding()
                        }
                    }
                    if crossesXAxis {
                        AxisMarks(position: .leading, values: [0]) { value in
                            AxisGridLine()
                                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 30)
                .overlay(
                    VStack {
                        if let regressionLine = regressionLine {
                            Text("y = \(Int(regressionLine.slope))x + \(Int(regressionLine.intercept))")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .cyan : .red)
                                .fontWeight(.bold)
                                .padding(4)
                                .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
                                .cornerRadius(4)
                                .offset(x: 100, y: -40)
                        }
                        Spacer()
                    },
                    alignment: .topLeading
                )
                .onAppear {
                    debugPrintData()
                }
            }
        }
    }

    func adjustedYDomain() -> ClosedRange<Double> {
        let minY = data.yValues.min()!
        let maxY = data.yValues.max()!
        
        if minY == maxY {
            return (minY - 1)...(maxY + 1)
        } else {
            let yRange = maxY - minY
            return (minY - 0.1 * yRange)...(maxY + 0.1 * yRange)
        }
    }

    func yAxisValues() -> [Double] {
        let minY = data.yValues.min()!
        let maxY = data.yValues.max()!
        let yIncrement = (maxY - minY) / 5
        return stride(from: minY, through: maxY, by: yIncrement).map { $0 }
    }

    func debugPrintData() {
        print("DynamicGraphView initialized with data:")
        print("xValues: \(data.xValues)")
        print("yValues: \(data.yValues)")
        if let regressionLine = regressionLine {
            print("Slope: \(regressionLine.slope), Intercept: \(regressionLine.intercept)")
        } else {
            print("Regression line is nil")
        }
    }
}


struct HorizontalLineChart: View {
    var data: GraphData
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                let yValue = data.yValues.first!
                let yPosition = geometry.size.height / 2
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: yPosition))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: yPosition))
                }
                .stroke(colorScheme == .dark ? .cyan : .red, lineWidth: 2)
                .overlay(
                    ForEach(Array(zip(data.xValues.indices, data.yValues.indices)), id: \.self.0) { (xIndex, _) in
                        let xValue = data.xValues[xIndex]
                        Circle()
                            .frame(width: 6, height: 6)
                            .foregroundColor(colorScheme == .dark ? Color(red: 0.0, green: 0.8, blue: 1.0) : Color(red: 0.7, green: 0.0, blue: 0.0))
                            .position(x: CGFloat(xValue / data.xValues.max()!) * geometry.size.width, y: yPosition)
                    }
                )
            }
            .frame(height: 200)
            .padding(.horizontal, 30)
        }
    }
}

struct VerticalLineChart: View {
    var data: GraphData
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                let xValue = data.xValues.first!
                let xPosition = geometry.size.width / 2
                
                Path { path in
                    path.move(to: CGPoint(x: xPosition, y: 0))
                    path.addLine(to: CGPoint(x: xPosition, y: geometry.size.height))
                }
                .stroke(colorScheme == .dark ? .cyan : .red, lineWidth: 2)
                .overlay(
                    ForEach(Array(zip(data.xValues.indices, data.yValues.indices)), id: \.self.0) { (_, yIndex) in
                        let yValue = data.yValues[yIndex]
                        Circle()
                            .frame(width: 6, height: 6)
                            .foregroundColor(colorScheme == .dark ? Color(red: 0.0, green: 0.8, blue: 1.0) : Color(red: 0.7, green: 0.0, blue: 0.0))
                            .position(x: xPosition, y: CGFloat(yValue / data.yValues.max()!) * geometry.size.height)
                    }
                )
            }
            .frame(height: 200)
            .padding(.horizontal, 30)
        }
    }
}

func linearRegression(x: [Double], y: [Double]) -> (slope: Double, intercept: Double)? {
    guard x.count == y.count && x.count > 1 else { return nil }
    
    let n = Double(x.count)
    let sumX = x.reduce(0, +)
    let sumY = y.reduce(0, +)
    let sumXY = zip(x, y).map(*).reduce(0, +)
    let sumXSquare = x.map { $0 * $0 }.reduce(0, +)
    
    let slope = (n * sumXY - sumX * sumY) / (n * sumXSquare - sumX * sumX)
    let intercept = (sumY - slope * sumX) / n
    
    return (slope, intercept)
}

struct NegativeSlopeGraphView: View {
    var data: GraphData
    @Environment(\.colorScheme) var colorScheme
    
    var regressionLine: (slope: Double, intercept: Double)? {
        linearRegression(x: data.xValues, y: data.yValues)
    }
    
    var xIncrement: Double {
        let differences = zip(data.xValues.dropFirst(), data.xValues).map(-)
        return differences.max() ?? 1.0
    }

    var yIncrement: Double {
        let differences = zip(data.yValues.dropFirst(), data.yValues).map(-)
        return differences.max() ?? 1.0
    }
    
    var crossesXAxis: Bool {
        guard let regressionLine = regressionLine else { return false }
        let yValuesAtXMin = regressionLine.slope * data.xValues.min()! + regressionLine.intercept
        let yValuesAtXMax = regressionLine.slope * data.xValues.max()! + regressionLine.intercept
        return (yValuesAtXMin <= 0 && yValuesAtXMax >= 0) || (yValuesAtXMin >= 0 && yValuesAtXMax <= 0)
    }

    var crossesYAxis: Bool {
        guard let regressionLine = regressionLine else { return false }
        return (0 <= data.xValues.max()! && 0 >= data.xValues.min()!)
    }
    
    var body: some View {
        VStack {
            Chart {
                ForEach(Array(zip(data.xValues.indices, data.yValues.indices)), id: \.self.0) { (xIndex, yIndex) in
                    let xValue = data.xValues[xIndex]
                    let yValue = data.yValues[yIndex]
                    LineMark(
                        x: .value("X Value", xValue),
                        y: .value("Y Value", yValue)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(colorScheme == .dark ? .cyan : .red)

                    PointMark(
                        x: .value("X Value", xValue),
                        y: .value("Y Value", yValue)
                    )
                    .symbol(Circle())
                    .symbolSize(30)
                    .foregroundStyle(colorScheme == .dark ? Color(red: 0.0, green: 0.8, blue: 1.0) : Color(red: 0.7, green: 0.0, blue: 0.0))
                }
            }
            .chartXScale(domain: (data.xValues.min()!)...(data.xValues.max()!))
            .chartYScale(domain: adjustedYDomain())
            .chartXAxis {
                AxisMarks(position: .bottom, values: Array(stride(from: data.xValues.min()!, through: data.xValues.max()!, by: xIncrement))) { value in
                    AxisTick()
                    AxisGridLine()
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.leading, -5)
                    }
                }
                if crossesYAxis {
                    AxisMarks(position: .bottom, values: [0]) { value in
                        AxisGridLine()
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues()) { value in
                    AxisTick()
                    AxisGridLine()
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding()
                    }
                }
                if crossesXAxis {
                    AxisMarks(position: .leading, values: [0]) { value in
                        AxisGridLine()
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 30)
            .overlay(
                VStack {
                    if let regressionLine = regressionLine {
                        Text("y = \(Int(regressionLine.slope))x + \(Int(regressionLine.intercept))")
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .cyan : .red)
                            .fontWeight(.bold)
                            .padding(4)
                            .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
                            .cornerRadius(4)
                            .offset(x: 100, y: -40)
                    }
                    Spacer()
                },
                alignment: .topLeading
            )
            .onAppear {
                debugPrintData()
            }
        }
    }
    
    func adjustedYDomain() -> ClosedRange<Double> {
        let minY = data.yValues.min()!
        let maxY = data.yValues.max()!
        
        if minY == maxY {
            return (minY - 1)...(maxY + 1)
        } else {
            let yRange = maxY - minY
            return (minY - 0.1 * yRange)...(maxY + 0.1 * yRange)
        }
    }

    func yAxisValues() -> [Double] {
        let minY = data.yValues.min()!
        let maxY = data.yValues.max()!
        let yIncrement = (maxY - minY) / 5
        return stride(from: minY, through: maxY, by: yIncrement).map { $0 }
    }

    func debugPrintData() {
        print("NegativeSlopeGraphView initialized with data:")
        print("xValues: \(data.xValues)")
        print("yValues: \(data.yValues)")
        if let regressionLine = regressionLine {
            print("Slope: \(regressionLine.slope), Intercept: \(regressionLine.intercept)")
        } else {
            print("Regression line is nil")
        }
    }
}


#Preview {
    DynamicGraphView(data: sampleData)
    //        .preferredColorScheme(.dark)
}

