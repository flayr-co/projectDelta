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
            Group {
                #if os(macOS)
                macOSLayout
                #else
                iOSLayout
                #endif
            }
        }
    }
    
    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Graph of a Line with Slope 0")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
                
                Text("Analytics integration pending.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(40)
            .frame(width: 400, height: 300)
            .background(Color.platformSystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformSystemGroupedBackground)
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
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
    #endif
}

#Preview {
    LeaderboardView()
}
