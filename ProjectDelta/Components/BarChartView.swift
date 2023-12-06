//
//  BarChartView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 11/7/23.
//

// BarChartView
import SwiftUI
import Charts

struct BarChartData: Identifiable, Equatable {
    let day: String
    let pointsCount: Int
    
    var id: String { return day }
}

struct BarChartView: View {
    @State private var averageIsShown: Bool = false
    
    let data = [BarChartData(day: "11/01/23", pointsCount: 40),
                BarChartData(day: "11/02/23", pointsCount: 20),
                BarChartData(day: "11/03/23", pointsCount: 35),
                BarChartData(day: "11/04/23", pointsCount: 10),
                BarChartData(day: "11/05/23", pointsCount: 60),
                BarChartData(day: "11/06/23", pointsCount: 65),
                BarChartData(day: "11/07/23", pointsCount: 55),
    ]
    
    var maxChartData: BarChartData? {
        data.max { $0.pointsCount < $1.pointsCount }
    }
    
    var body: some View {
        Chart {
            ForEach(data) { dataPoint in
                BarMark(x: .value("Day", dataPoint.day),
                        y: .value("Points", dataPoint.pointsCount))
                .opacity(maxChartData == dataPoint ? 1.0 : 0.5)
            }
            
            if averageIsShown {
                RuleMark(y: .value("Average", 6))
                    .foregroundStyle(.gray)
                    .annotation(position: .bottom, alignment: .bottomLeading) {
                        Text("Average 6")
                    }
            }
        }
        .frame(width: 350, height: 250)
        .aspectRatio(contentMode: .fit)
        
        Toggle(averageIsShown ? "Display Average": "Display Average", isOn: $averageIsShown.animation())
    }
}

#Preview {
    BarChartView()
}
