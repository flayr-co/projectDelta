//
//  PhysicsHubView.swift
//  ProjectDelta
//

import SwiftUI

struct PhysicsHubView: View {
    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 850
            let contentPadding: CGFloat = isWide ? 40 : 20
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: isWide ? 32 : 24) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Explore the Universe")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        Text("How It Works")
                            .font(.system(size: isWide ? 42 : 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, isWide ? 40 : 16)
                    
                    // Navigation Grid
                    let columns = [
                        GridItem(.adaptive(minimum: isWide ? 350 : 300, maximum: 600), spacing: 16)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 16) {
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
                        
                        HubCard(
                            title: "Wave-Matter Interaction",
                            subtitle: "Interactive EM Spectrum Scenarios",
                            icon: "waveform.path.ecg.rectangle.fill",
                            colors: [.purple, .pink],
                            destination: EMInteractionView()
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

// MARK: - Reusable Hub Card Component (Compact Horizontal Layout)
private struct HubCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.system(.body, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: colors.first!.opacity(0.3), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PhysicsHubView()
    }
}
