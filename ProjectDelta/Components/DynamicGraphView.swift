//
//  DynamicGraphView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/23/24.
//

import SwiftUI
import Charts

// Sample data for the graph
let sampleData = [
    (x: 1, y: 10),
    (x: 2, y: 15),
    (x: 3, y: 20),
    (x: 4, y: 25),
    (x: 5, y: 30)
]

struct DynamicGraphView: View {
    var data: GraphData
    
    var body: some View {
        Chart {
            ForEach(Array(zip(data.xValues, data.yValues)), id: \.0) { (xValue, yValue) in
                LineMark(
                    x: .value("X Value", xValue),
                    y: .value("Y Value", yValue)
                )
                .symbol(Circle())
                .foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: 0...data.yValues.max()!)
        .frame(height: 200)
    }
}

//#Preview {
//    let sampleGraphData = GraphData(
//        xValues: [1.0, 2.0, 3.0, 4.0, 5.0],
//        yValues: [2.0, 4.0, 6.0, 8.0, 10.0]
//    )
//    
//    DynamicGraphView(data: sampleGraphData)
//}

