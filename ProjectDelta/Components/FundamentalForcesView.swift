//
//  FundamentalForcesView.swift
//  ProjectDelta
//

import SwiftUI

struct FundamentalForcesView: View {
    @State private var selectedForce: ForceType = .strong
    @Namespace private var animation
    
    enum ForceType: String, CaseIterable {
        case gravity = "Gravity"
        case weak = "Weak Nuclear"
        case electromagnetism = "Electromagnetism"
        case strong = "Strong Nuclear"
        
        var tabName: String {
            switch self {
            case .gravity: return "Gravity"
            case .weak: return "Weak"
            case .electromagnetism: return "EM"
            case .strong: return "Strong"
            }
        }
    }
    
    private struct ForceDetails {
        let name: String
        let icon: String
        let baseColor: Color
        let gradientColors: [Color]
        let relativeStrength: String
        let range: String
        let boson: String
        let description: String
        let role: [String]
    }
    
    private var currentForce: ForceDetails {
        switch selectedForce {
        case .gravity:
            return ForceDetails(
                name: "Gravity",
                icon: "globe.americas.fill",
                baseColor: .teal,
                gradientColors: [.blue, .teal],
                relativeStrength: "10⁻³⁹",
                range: "Infinite",
                boson: "Graviton (Theoretical)",
                description: "The weakest but most far-reaching force. Instead of a traditional 'pull', it is the warping of the fabric of spacetime by mass and energy, dictating the motion of planets, stars, and galaxies.",
                role: ["Holds planets in orbit", "Drives stellar formation", "Shapes large-scale cosmic structure"]
            )
        case .weak:
            return ForceDetails(
                name: "Weak Nuclear",
                icon: "aqi.medium",
                baseColor: .purple,
                gradientColors: [.purple, .indigo],
                relativeStrength: "10⁻⁵",
                range: "Subatomic (10⁻¹⁸ m)",
                boson: "W & Z Bosons",
                description: "Operates at incredibly tiny distances to govern particle decay and radioactivity. It is uniquely able to change the fundamental 'flavor' of quarks, essentially transforming protons into neutrons and vice versa.",
                role: ["Drives beta decay", "Initiates stellar nuclear fusion", "Enables carbon dating"]
            )
        case .electromagnetism:
            return ForceDetails(
                name: "Electromagnetism",
                icon: "bolt.fill",
                baseColor: .yellow,
                gradientColors: [.yellow, .orange],
                relativeStrength: "1 / 137",
                range: "Infinite",
                boson: "Photon",
                description: "The force of attraction and repulsion between electrically charged particles. It binds electrons to atoms, dictates all of chemistry and biology, and travels through space as light and radio waves.",
                role: ["Binds atoms into molecules", "Generates visible light & EM waves", "Drives electricity & magnetism"]
            )
        case .strong:
            return ForceDetails(
                name: "Strong Nuclear",
                icon: "atom",
                baseColor: .red,
                gradientColors: [.red, .pink],
                relativeStrength: "1 (Baseline)",
                range: "Subatomic (10⁻¹⁵ m)",
                boson: "Gluon",
                description: "The absolute strongest force in the universe, but only over microscopic distances. It acts like an incredibly tight bungee cord, overcoming the violent repulsion of positively charged protons to bind the atomic nucleus together.",
                role: ["Binds quarks into protons & neutrons", "Holds the atomic nucleus intact", "Releases energy in nuclear fission"]
            )
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 850
            let contentPadding: CGFloat = isWide ? 32 : 20
            let cardSpacing: CGFloat = isWide ? 32 : 28 // Increased spacing for better breathing room
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isWide ? 36 : 28) {
                    
                    // Dynamic Header
                    VStack(spacing: 12) {
                        Image(systemName: currentForce.icon)
                            .font(.system(size: isWide ? 64 : 56, weight: .regular))
                            .foregroundStyle(LinearGradient(colors: currentForce.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: currentForce.baseColor.opacity(0.6), radius: 10, x: 0, y: 4)
                            .padding(.top, isWide ? 60 : 40)
                            .symbolEffect(.bounce, value: selectedForce)
                        
                        Text(currentForce.name)
                            .font(.system(size: isWide ? 46 : 38, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(LinearGradient(colors: currentForce.gradientColors, startPoint: .leading, endPoint: .trailing))
                            .contentTransition(.numericText())
                    }
                    .padding(.bottom, 4)
                    
                    // Fixed Segmented Control
                    HStack(spacing: 8) {
                        ForEach(ForceType.allCases, id: \.self) { force in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedForce = force
                                }
                            }) {
                                Text(force.tabName)
                                    .font(.system(isWide ? .headline : .subheadline, design: .rounded, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(selectedForce == force ? .white : .secondary)
                                    .background(
                                        ZStack {
                                            if selectedForce == force {
                                                LinearGradient(colors: currentForce.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    .clipShape(Capsule())
                                                    .matchedGeometryEffect(id: "PillBackground", in: animation)
                                            } else {
                                                Capsule().fill(.ultraThinMaterial)
                                            }
                                        }
                                    )
                                    .overlay(
                                        Capsule().stroke(selectedForce == force ? .clear : .secondary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, isWide ? 16 : 8)
                    
                    // Content Grid
                    if isWide {
                        HStack(alignment: .top, spacing: 32) {
                            VStack(spacing: cardSpacing) {
                                forceVisualizerBox(isWide: true)
                                metricsBox()
                            }
                            VStack(spacing: cardSpacing) {
                                overviewBox()
                                rolesBox()
                            }
                        }
                    } else {
                        VStack(spacing: cardSpacing) {
                            forceVisualizerBox(isWide: false)
                            metricsBox()
                            overviewBox()
                            rolesBox()
                        }
                    }
                }
                .padding(.horizontal, contentPadding)
                .padding(.bottom, isWide ? 60 : 140)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Fundamental Forces")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sensoryFeedback(.selection, trigger: selectedForce)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func forceVisualizerBox(isWide: Bool) -> some View {
        ForceVisualizer(forceType: selectedForce, gradientColors: currentForce.gradientColors)
            .frame(maxWidth: .infinity)
            .frame(height: isWide ? 280 : 250)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RadialGradient(colors: [currentForce.baseColor.opacity(0.15), .clear], center: .center, startRadius: 10, endRadius: 120)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(currentForce.baseColor.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: currentForce.baseColor.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    @ViewBuilder
    private func metricsBox() -> some View {
        ForceCard(baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            VStack(spacing: 20) {
                MetricRow(title: "Relative Strength", value: currentForce.relativeStrength)
                MetricRow(title: "Effective Range", value: currentForce.range)
                MetricRow(title: "Carrier Particle", value: currentForce.boson)
            }
        }
    }
    
    @ViewBuilder
    private func overviewBox() -> some View {
        ForceCard(title: "Physical Overview", icon: "book.fill", baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            Text(currentForce.description)
                .font(.system(.body, design: .rounded))
                .lineSpacing(6)
                .foregroundStyle(.primary.opacity(0.9))
        }
    }
    
    @ViewBuilder
    private func rolesBox() -> some View {
        ForceCard(title: "Role in Nature", icon: "sparkles", baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(currentForce.role, id: \.self) { role in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LinearGradient(colors: currentForce.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text(role)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.9))
                    }
                }
            }
        }
    }
}

// MARK: - Internal Components

private struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ForceCard<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var baseColor: Color
    var gradientColors: [Color]
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title, let icon = icon {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: baseColor.opacity(0.4), radius: 4, y: 2)
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Divider().opacity(0.5)
            }
            
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(28) // Increased internal padding for better text breathing room
        .background(
            ZStack {
                Rectangle().fill(.regularMaterial)
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.05)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(baseColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: baseColor.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Diagram Label Modifier
private struct DiagramLabelModifier: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.black.opacity(0.5)) // Diagram pill background
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }
}

extension View {
    func diagramLabel(color: Color) -> some View {
        self.modifier(DiagramLabelModifier(color: color))
    }
}

// MARK: - Labeled Educational Visualizations

private struct ForceVisualizer: View {
    let forceType: FundamentalForcesView.ForceType
    let gradientColors: [Color]
    
    var body: some View {
        ZStack {
            switch forceType {
            case .gravity:
                GravityAnimation(colors: gradientColors)
            case .electromagnetism:
                ElectromagnetismAnimation(colors: gradientColors)
            case .strong:
                StrongNuclearAnimation(colors: gradientColors)
            case .weak:
                WeakNuclearAnimation(colors: gradientColors)
            }
        }
    }
}

private struct GravityAnimation: View {
    let colors: [Color]
    @State private var phase = false
    
    var body: some View {
        ZStack {
            // Ripples
            ForEach(0..<4) { i in
                Circle()
                    .stroke(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: phase ? 10 : 180)
                    .opacity(phase ? 0 : 1 - (Double(i) * 0.2))
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: false).delay(Double(i) * 0.75), value: phase)
            }
            
            // Core Mass
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .shadow(color: colors.first!.opacity(0.8), radius: 15, x: 0, y: 0)
                .scaleEffect(phase ? 1.0 : 1.1)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: phase)
            
            // Educational Labels
            Text("Mass")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
            
            Text("Spacetime Curvature")
                .diagramLabel(color: colors.first!)
                .offset(y: 85) // Pushed slightly further down, protected by pill background
        }
        .onAppear { phase = true }
    }
}

private struct ElectromagnetismAnimation: View {
    let colors: [Color]
    @State private var phase = false
    
    var body: some View {
        ZStack {
            HStack(spacing: phase ? 30 : 80) {
                // Negative Charge
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(colors.first!.opacity(0.5), lineWidth: 2)
                            .frame(width: phase ? 80 : 40)
                            .opacity(phase ? 0 : 1)
                        
                        Circle()
                            .fill(colors.first!)
                            .frame(width: 30)
                            .overlay(Image(systemName: "minus").foregroundColor(.white).font(.caption.weight(.bold)))
                            .shadow(color: colors.first!.opacity(0.6), radius: 10)
                    }
                    Text("Negative")
                        .diagramLabel(color: .secondary)
                }
                
                // Positive Charge
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(colors.last!.opacity(0.5), lineWidth: 2)
                            .frame(width: phase ? 80 : 40)
                            .opacity(phase ? 0 : 1)
                        
                        Circle()
                            .fill(colors.last!)
                            .frame(width: 30)
                            .overlay(Image(systemName: "plus").foregroundColor(.white).font(.caption.weight(.bold)))
                            .shadow(color: colors.last!.opacity(0.6), radius: 10)
                    }
                    Text("Positive")
                        .diagramLabel(color: .secondary)
                }
            }
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: phase)
            
            Text("Field Attraction")
                .diagramLabel(color: colors.first!)
                .offset(y: -60)
        }
        .onAppear { phase = true }
    }
}

private struct StrongNuclearAnimation: View {
    let colors: [Color]
    @State private var rotation: Double = 0
    @State private var jiggle = false
    
    var body: some View {
        ZStack {
            // "Gluon" Springs
            Path { path in
                path.move(to: CGPoint(x: 100, y: 70))
                path.addLine(to: CGPoint(x: 70, y: 120))
                path.addLine(to: CGPoint(x: 130, y: 120))
                path.closeSubpath()
            }
            .stroke(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 6, dash: [8, 6]))
            .frame(width: 200, height: 200)
            .scaleEffect(jiggle ? 1.05 : 0.95)
            
            // "Quark" Nodes (RGB Color Charge)
            Group {
                Circle().fill(.red).frame(width: 36).offset(y: -30)
                Circle().fill(.green).frame(width: 36).offset(x: -28, y: 20)
                Circle().fill(.blue).frame(width: 36).offset(x: 28, y: 20)
            }
            .shadow(color: colors.first!.opacity(0.6), radius: 10)
            
            // Rotating component wrapper
            .rotationEffect(.degrees(rotation))
            .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: rotation)
            .animation(.spring(response: 0.3, dampingFraction: 0.2).repeatForever(autoreverses: true), value: jiggle)
            
            // Static Labels
            Text("Quarks")
                .diagramLabel(color: .white)
                .offset(y: 4)
            
            Text("Gluon Flux")
                .diagramLabel(color: colors.first!)
                .offset(x: -60, y: -50)
        }
        .onAppear {
            rotation = 360
            jiggle = true
        }
    }
}

private struct WeakNuclearAnimation: View {
    let colors: [Color]
    @State private var emit = false
    
    var body: some View {
        ZStack {
            // Emitted Particle Path
            Capsule()
                .fill(LinearGradient(colors: [colors.last!.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: emit ? 100 : 0, height: 4)
                .offset(x: emit ? 70 : 20, y: -20)
                .rotationEffect(.degrees(-15))
                .opacity(emit ? 0 : 1)
            
            // Emitted Particle (e.g. Electron/Neutrino)
            Circle()
                .fill(colors.last!)
                .frame(width: 16)
                .shadow(color: colors.last!.opacity(0.8), radius: 6)
                .offset(x: emit ? 120 : 10, y: emit ? -40 : -10)
                .opacity(emit ? 0 : 1)
            
            // Core Nucleus changing states
            Circle()
                .fill(LinearGradient(colors: emit ? [colors.first!, colors.last!] : [colors.last!, colors.first!], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60)
                .shadow(color: colors.first!.opacity(0.6), radius: 15)
                .scaleEffect(emit ? 0.9 : 1.1)
            
            // Educational Labels
            Text("Unstable Nucleus")
                .diagramLabel(color: .white)
                .offset(x: -45, y: 45)
            
            Text("Beta Particle")
                .diagramLabel(color: colors.last!)
                .offset(x: 65, y: -55)
        }
        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: emit)
        .onAppear { emit = true }
    }
}

#Preview {
    NavigationStack {
        FundamentalForcesView()
            .preferredColorScheme(.dark)
    }
}
