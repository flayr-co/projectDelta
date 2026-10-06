//
//  PhysicsHubView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/6/26.
//


//
//  PhysicsHubView.swift
//  ProjectDelta
//

import SwiftUI

struct PhysicsHubView: View {
    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 850
            let contentPadding: CGFloat = isWide ? 40 : 24
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Explore the Universe")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        Text("How It Works")
                            .font(.system(size: isWide ? 46 : 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, isWide ? 40 : 20)
                    
                    // Navigation Grid
                    let columns = [
                        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 24)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 24) {
                        HubCard(
                            title: "Fundamental Forces",
                            subtitle: "Gravity, EM, Strong & Weak Nuclear",
                            icon: "bolt.heart.fill",
                            colors: [.yellow, .orange],
                            destination: FundamentalForcesView()
                        )
                        
                        HubCard(
                            title: "Subatomic Particles",
                            subtitle: "Protons, Neutrons & Electrons",
                            icon: "circle.hexagongrid.fill",
                            colors: [.cyan, .blue],
                            destination: SubatomicParticlesView()
                        )
                    }
                }
                .padding(.horizontal, contentPadding)
                .padding(.bottom, isWide ? 80 : 120)
                .frame(maxWidth: 1200, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Physics Hub")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

// MARK: - Reusable Hub Card Component
private struct HubCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: colors.first!.opacity(0.3), radius: 15, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PhysicsHubView()
    }
}