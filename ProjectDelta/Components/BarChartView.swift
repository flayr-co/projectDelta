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
    @EnvironmentObject var viewModel: AuthViewModel
//    var user: User // User instance containing points history NOT NEEDED ANYMORE
    @State private var data: [BarChartData] = []
    @State private var averageIsShown: Bool = false

    var maxChartData: BarChartData? {
        data.max(by: { $0.pointsCount < $1.pointsCount })
    }
    
    // No need for a placeholder function anymore since data comes from the user instance
    
    func loadLast7DaysData() {
        guard let pointsHistory = viewModel.currentUser?.pointsHistory else { return }
        self.data = generateLast7DaysData(from: pointsHistory)
        print("Loaded data for bar chart: \(self.data)")
    }

    func generateLast7DaysData(from pointsHistory: [String: Int]) -> [BarChartData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date()) // Start of the day to avoid time zone issues
        let last7DaysRange = (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        
        return last7DaysRange.map { date -> BarChartData in
            let dateKey = dateFormatter.string(from: date)
            let pointsCount = pointsHistory[dateKey] ?? 0
            dateFormatter.dateFormat = "MM/dd"
            let displayDate = dateFormatter.string(from: date)
            return BarChartData(day: displayDate, pointsCount: pointsCount)
        }.reversed()
    }
    
    var body: some View {
        Chart {
            ForEach(data) { dataPoint in
                BarMark(x: .value("Day", dataPoint.day),
                        y: .value("Points", dataPoint.pointsCount))
                    .opacity(maxChartData == dataPoint ? 1.0 : 0.5)
            }
        }
        .frame(width: 350, height: 250)
        .aspectRatio(contentMode: .fit)
        .onAppear(perform: loadLast7DaysData)
        .onChange(of: viewModel.currentUser) { _ in
            loadLast7DaysData()
        }

        
        Toggle(isOn: $averageIsShown.animation()) {
            Text(averageIsShown ? "Hide Average": "Show Average")
        }
        
        // Display the average if toggled
        if averageIsShown, let averagePoints = data.map({ $0.pointsCount }).average() {
            Text("Average: \(averagePoints, specifier: "%.2f") points")
        }
    }
}

// Extension to calculate the average
extension Collection where Element == Int {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        let sum = reduce(0, +)
        return Double(sum) / Double(count)
    }
}

#Preview {
    BarChartView()
        .environmentObject(AuthViewModel())
}
