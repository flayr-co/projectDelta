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
    yValues: [10.0, 15.0, 20.0, 25.0, 30.0]
)

struct DynamicGraphView: View {
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
    
    var body: some View {
        VStack {
            Chart {
                ForEach(Array(zip(data.xValues, data.yValues)), id: \.0) { (xValue, yValue) in
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
            .chartXScale(domain: (data.xValues.min()! - xIncrement)...(data.xValues.max()! + xIncrement))
            .chartYScale(domain: (data.yValues.min()! - yIncrement)...(data.yValues.max()! + yIncrement))
            .chartXAxis {
                AxisMarks(position: .bottom, values: Array(stride(from: data.xValues.min()! - xIncrement, through: data.xValues.max()! + xIncrement, by: xIncrement))) { value in
                    AxisTick()
                    AxisGridLine()
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.leading, -5) // Adjust the padding to move the label closer to the tick
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: Array(stride(from: data.yValues.min()! - yIncrement, through: data.yValues.max()! + yIncrement, by: yIncrement))) { value in
                    AxisTick()
                    AxisGridLine()
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding()
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

#Preview {
    DynamicGraphView(data: sampleData)
    //        .preferredColorScheme(.dark)
}



