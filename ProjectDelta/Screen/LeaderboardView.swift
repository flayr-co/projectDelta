//
//  LeaderboardView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI

struct LeaderboardView: View {
    let testGraphData = GraphData(xValues: [0.0, 1.0, 2.0, 3.0, 4.0], yValues: [7.0, 7.0, 7.0, 7.0, 7.0])
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        Spacer(minLength: geometry.size.height * 0.3)
                        
                        Text("Graph of a Line with Slope 0")
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .minimumScaleFactor(0.5)
                            .lineLimit(nil)
                            .padding(.horizontal)
                            .lineSpacing(10)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
//                        DynamicGraphView(data: testGraphData)
//                            .padding(.bottom, 15)
//                            .padding(.top, 58)
//                            .frame(maxWidth: .infinity, alignment: .center)
//                            .onAppear {
//                                print("Displaying graph data: \(testGraphData.xValues), \(testGraphData.yValues)")
//                            }
                        
                        Spacer()
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
    }
}

#Preview {
    LeaderboardView()
}
