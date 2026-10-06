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
        
        let overview: String
        let analogy: String
        let messengerExplanation: String
        let misconception: String
        let role: [String]
    }
    
    private var currentForce: ForceDetails {
        switch selectedForce {
        case .gravity:
            return ForceDetails(
                name: "Gravity",
                icon: "globe.americas.fill",
                baseColor: .cyan,
                gradientColors: [.cyan, .blue, .indigo],
                relativeStrength: "10⁻³⁹ (Weakest)",
                range: "Infinite",
                boson: "Graviton",
                overview: "Gravity is the fundamental attraction between anything that has mass or energy. While it is incredibly weak on a microscopic scale, it dominates the macroscopic universe because it has an infinite range and only attracts, never repels.",
                analogy: "Imagine the universe as a giant, stretched-out trampoline. If you place a heavy bowling ball (a star or planet) in the middle, it creates a dip in the fabric. If you roll a marble nearby, it naturally falls into that dip. Gravity isn't a traditional 'pull'; it's the curving of the trampoline itself.",
                messengerExplanation: "Physicists believe gravity is communicated by a messenger particle called the 'Graviton'. However, gravity is so weak that we have never actually detected one in a lab. It remains the missing puzzle piece bridging gravity with quantum mechanics.",
                misconception: "Astronauts float on the International Space Station not because there is 'zero gravity' in space—Earth's gravity is still 90% as strong up there! They float because they are moving sideways so fast that as they fall toward Earth, the Earth curves away beneath them. They are in a state of continuous freefall.",
                role: ["Holds planets, stars, and galaxies together", "Drives the crushing pressure that ignites stars", "Dictates the flow of time (time moves slower in stronger gravity)"]
            )
        case .weak:
            return ForceDetails(
                name: "Weak Nuclear",
                icon: "aqi.medium",
                baseColor: .purple,
                gradientColors: [.purple, .indigo, .mint],
                relativeStrength: "10⁻⁵",
                range: "Subatomic (10⁻¹⁸ m)",
                boson: "W & Z Bosons",
                overview: "Operating entirely inside the nucleus of an atom, the weak force is the only mechanism in nature capable of changing a fundamental particle's identity (its 'flavor'). It is the primary driver of radioactive decay.",
                analogy: "Unlike other forces that push or pull, the weak force acts like a microscopic alchemist. If a neutron has too much energy, the weak force casts a 'spell' that magically transforms it into a completely different particle—a proton—spitting out radiation in the process.",
                messengerExplanation: "The weak force communicates using W and Z Bosons. These particles are incredibly heavy, meaning it takes a massive amount of energy to create them, and they vanish almost instantly. This is why the weak force only works at distances smaller than a single proton.",
                misconception: "Despite its name, it isn't just a 'weaker version' of the strong force. It performs a completely unique job. Without it, the sun couldn't burn, because the fusion process relies on the weak force transforming protons into neutrons.",
                role: ["Drives radioactive beta decay", "Initiates the nuclear fusion that powers the sun", "Creates the radioactive isotopes used in medicine and carbon dating"]
            )
        case .electromagnetism:
            return ForceDetails(
                name: "Electromagnetism",
                icon: "bolt.fill",
                baseColor: .yellow,
                gradientColors: [.yellow, .orange, .red],
                relativeStrength: "1 / 137",
                range: "Infinite",
                boson: "Photon",
                overview: "This force governs the interaction between electrically charged particles. Opposite charges (positive and negative) attract, while like charges repel. It is the fundamental force responsible for almost everything you experience in daily life.",
                analogy: "It is the 'chemistry' force. When you touch a table, your hand doesn't pass through it. Why? Because the negative electrons in the atoms of your hand are violently repelling the negative electrons in the atoms of the table. You have never actually 'touched' anything; you only feel electromagnetic repulsion.",
                messengerExplanation: "Electromagnetism is communicated by the 'Photon'—the fundamental particle of light. When two magnets push apart, they are actually shooting an invisible stream of photons at each other to communicate the repulsive force.",
                misconception: "Electricity and magnetism seem like different things, but they are two sides of the exact same coin. A moving electrical charge creates a magnetic field, and a moving magnet creates electricity. This unified principle powers our entire modern world.",
                role: ["Binds atoms into complex molecules (Chemistry)", "Transmits all visible light, Wi-Fi, and X-Rays", "Drives every electronic device on Earth"]
            )
        case .strong:
            return ForceDetails(
                name: "Strong Nuclear",
                icon: "atom",
                baseColor: .pink,
                gradientColors: [.red, .pink, .purple],
                relativeStrength: "1 (Baseline)",
                range: "Subatomic (10⁻¹⁵ m)",
                boson: "Gluon",
                overview: "The absolute strongest force in the universe. It operates on an unimaginably small scale to bind quarks together into protons and neutrons, and subsequently holds those protons and neutrons tightly together in the atomic nucleus.",
                analogy: "Imagine a subatomic bungee cord. If you try to pull two quarks apart, the strong force actually gets stronger the further you pull, stretching the cord until it snaps. When it snaps, the stored energy instantly creates brand new particles out of thin air to cap the broken ends.",
                messengerExplanation: "Quarks communicate this force by tossing particles called 'Gluons' back and forth. They are literally the 'glue' that holds the universe's building blocks together. This exchange is so violent and energetic that it accounts for 99% of your body's mass.",
                misconception: "Since opposite charges attract and like charges repel, a cluster of positively charged protons packed into a tiny nucleus should violently explode outward. The only reason atoms (and you) exist is because the strong force is 137 times more powerful than electromagnetism, overpowering the explosion.",
                role: ["Binds quarks into protons and neutrons", "Overcomes electromagnetic repulsion to hold the nucleus intact", "Releases devastating energy in nuclear weapons and reactors"]
            )
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 850
            let contentPadding: CGFloat = isWide ? 40 : 24
            let cardSpacing: CGFloat = isWide ? 32 : 28
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isWide ? 40 : 32) {
                    
                    VStack(spacing: 16) {
                        Image(systemName: currentForce.icon)
                            .font(.system(size: isWide ? 72 : 64, weight: .light))
                            .foregroundStyle(LinearGradient(colors: currentForce.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: currentForce.baseColor.opacity(0.8), radius: 15, x: 0, y: 8)
                            .padding(.top, isWide ? 60 : 40)
                            .symbolEffect(.bounce, value: selectedForce)
                        
                        Text(currentForce.name)
                            .font(.system(size: isWide ? 52 : 42, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(LinearGradient(colors: currentForce.gradientColors, startPoint: .leading, endPoint: .trailing))
                            .contentTransition(.numericText())
                    }
                    .padding(.bottom, 8)
                    
                    HStack(spacing: 8) {
                        ForEach(ForceType.allCases, id: \.self) { force in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    selectedForce = force
                                }
                            }) {
                                Text(force.tabName)
                                    .font(.system(isWide ? .title3 : .subheadline, design: .rounded, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.vertical, 16)
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
                    .padding(.bottom, isWide ? 20 : 12)
                    
                    if isWide {
                        HStack(alignment: .top, spacing: 40) {
                            VStack(spacing: cardSpacing) {
                                forceVisualizerBox(isWide: true)
                                metricsBox()
                                bosonExplanationBox()
                            }
                            VStack(spacing: cardSpacing) {
                                overviewBox()
                                analogyBox()
                                misconceptionBox()
                                rolesBox()
                            }
                        }
                    } else {
                        VStack(spacing: cardSpacing) {
                            forceVisualizerBox(isWide: false)
                            metricsBox()
                            overviewBox()
                            analogyBox()
                            bosonExplanationBox()
                            misconceptionBox()
                            rolesBox()
                        }
                    }
                }
                .padding(.horizontal, contentPadding)
                .padding(.bottom, isWide ? 80 : 160)
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
            .frame(height: isWide ? 340 : 280)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RadialGradient(colors: [currentForce.baseColor.opacity(0.2), .clear], center: .center, startRadius: 10, endRadius: 160)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(currentForce.baseColor.opacity(0.4), lineWidth: 1.5)
            )
            .shadow(color: currentForce.baseColor.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func metricsBox() -> some View {
        ForceCard(baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            VStack(spacing: 24) {
                MetricRow(title: "Relative Strength", value: currentForce.relativeStrength)
                MetricRow(title: "Effective Range", value: currentForce.range)
                MetricRow(title: "Messenger Particle", value: currentForce.boson)
            }
        }
    }
    
    @ViewBuilder
    private func overviewBox() -> some View {
        ForceCard(title: "The Science", icon: "books.vertical.fill", baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            Text(currentForce.overview)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .lineSpacing(8)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true) // Prevents truncation
        }
    }
    
    @ViewBuilder
    private func analogyBox() -> some View {
        ForceCard(title: "The Simple Explanation", icon: "lightbulb.fill", baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            Text(currentForce.analogy)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .lineSpacing(8)
                .foregroundStyle(.primary.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func bosonExplanationBox() -> some View {
        ForceCard(title: "How It Communicates", icon: "paperplane.fill", baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Forces don't happen by magic. Objects 'feel' a force because they are throwing microscopic messenger particles (called Bosons) at each other.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(6)
                    .padding(.bottom, 8)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(currentForce.messengerExplanation)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .lineSpacing(8)
                    .foregroundStyle(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    @ViewBuilder
    private func misconceptionBox() -> some View {
        ForceCard(title: "Clearing Up Confusion", icon: "exclamationmark.triangle.fill", baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            Text(currentForce.misconception)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .lineSpacing(8)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func rolesBox() -> some View {
        ForceCard(title: "Role in Nature", icon: "sparkles", baseColor: currentForce.baseColor, gradientColors: currentForce.gradientColors) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(currentForce.role, id: \.self) { role in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LinearGradient(colors: currentForce.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: currentForce.baseColor.opacity(0.5), radius: 4, y: 2)
                        Text(role)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: 20) {
            if let title = title, let icon = icon {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: baseColor.opacity(0.5), radius: 6, y: 2)
                    Text(title)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().opacity(0.6)
            }
            
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(28)
        .background(
            ZStack {
                Rectangle().fill(.regularMaterial)
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(baseColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: baseColor.opacity(0.1), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Diagram Label Modifier
private struct DiagramLabelModifier: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.heavy))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.65))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

extension View {
    func diagramLabel(color: Color) -> some View {
        self.modifier(DiagramLabelModifier(color: color))
    }
}

// MARK: - Vibrant Educational Visualizations

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

// 1. Gravity: Spacetime Well
private struct GravityAnimation: View {
    let colors: [Color]
    @State private var phase = false
    
    var body: some View {
        ZStack {
            ForEach(1...5, id: \.self) { i in
                Ellipse()
                    .stroke(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: CGFloat(i * 50), height: CGFloat(i * 15))
                    .offset(y: CGFloat(i * 8))
                    .opacity(0.8 - (Double(i) * 0.15))
            }
            
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .shadow(color: colors.first!.opacity(1.0), radius: 20, x: 0, y: 0)
                .scaleEffect(phase ? 1.0 : 1.08)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: phase)
                .offset(y: -10)
            
            Text("Mass")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.white)
                .offset(y: -10)
            
            Text("Spacetime Well")
                .diagramLabel(color: colors.first!)
                .offset(y: 80)
        }
        .onAppear { phase = true }
    }
}

// 2. Electromagnetism: Photonic Exchange
private struct ElectromagnetismAnimation: View {
    let colors: [Color]
    @State private var phase = false
    @State private var photonTravel = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 120) {
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(colors.first!.opacity(0.6), lineWidth: 2)
                            .frame(width: phase ? 120 : 40)
                            .opacity(phase ? 0 : 1 - (Double(i) * 0.3))
                            .animation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(Double(i) * 0.6), value: phase)
                    }
                    Circle()
                        .fill(colors.first!)
                        .frame(width: 40)
                        .overlay(Image(systemName: "minus").foregroundColor(.white).font(.headline.weight(.heavy)))
                        .shadow(color: colors.first!.opacity(0.8), radius: 15)
                    
                    Text("Electron")
                        .diagramLabel(color: .white)
                        .offset(y: 45)
                }
                
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(colors.last!.opacity(0.6), lineWidth: 2)
                            .frame(width: phase ? 120 : 40)
                            .opacity(phase ? 0 : 1 - (Double(i) * 0.3))
                            .animation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(Double(i) * 0.6), value: phase)
                    }
                    Circle()
                        .fill(colors.last!)
                        .frame(width: 40)
                        .overlay(Image(systemName: "plus").foregroundColor(.white).font(.headline.weight(.heavy)))
                        .shadow(color: colors.last!.opacity(0.8), radius: 15)
                    
                    Text("Proton")
                        .diagramLabel(color: .white)
                        .offset(y: 45)
                }
            }
            
            Circle()
                .fill(.white)
                .frame(width: 12)
                .shadow(color: .white, radius: 10)
                .offset(x: photonTravel ? 60 : -60)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: photonTravel)
            
            Text("Photon Exchange")
                .diagramLabel(color: colors.first!)
                .offset(y: -65)
        }
        .onAppear {
            phase = true
            photonTravel = true
        }
    }
}

// 3. Strong Nuclear: Quantum Chromodynamics (QCD)
private struct StrongNuclearAnimation: View {
    let colors: [Color]
    @State private var rotation: Double = 0
    @State private var jiggle = false
    @State private var colorShift = false
    
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 100, y: 50))
                path.addLine(to: CGPoint(x: 60, y: 120))
                path.addLine(to: CGPoint(x: 140, y: 120))
                path.closeSubpath()
            }
            .stroke(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 8, dash: [10, 8]))
            .frame(width: 200, height: 200)
            .scaleEffect(jiggle ? 1.1 : 0.9)
            
            Group {
                Circle().fill(.red).frame(width: 44).offset(y: -50)
                Circle().fill(.green).frame(width: 44).offset(x: -40, y: 20)
                Circle().fill(.blue).frame(width: 44).offset(x: 40, y: 20)
            }
            .shadow(color: colors.first!.opacity(0.8), radius: 15)
            .hueRotation(.degrees(colorShift ? 360 : 0))
            .rotationEffect(.degrees(rotation))
            .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotation)
            .animation(.spring(response: 0.2, dampingFraction: 0.1).repeatForever(autoreverses: true), value: jiggle)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: false), value: colorShift)
            
            Text("Quarks (QCD)")
                .diagramLabel(color: .white)
                .offset(y: -8)
            
            Text("Gluon Flux")
                .diagramLabel(color: colors.first!)
                .offset(x: -80, y: -60)
        }
        .onAppear {
            rotation = 360
            jiggle = true
            colorShift = true
        }
    }
}

// 4. Weak Nuclear: Beta Decay
private struct WeakNuclearAnimation: View {
    let colors: [Color]
    @State private var decayPhase = 0
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [colors.last!.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: decayPhase > 0 ? 120 : 0, height: 6)
                .offset(x: decayPhase > 0 ? 80 : 30, y: -25)
                .rotationEffect(.degrees(-20))
                .opacity(decayPhase == 2 ? 0 : 1)
                .animation(.easeOut(duration: 0.6), value: decayPhase)
            
            Circle()
                .fill(.cyan)
                .frame(width: 20)
                .shadow(color: .cyan, radius: 12)
                .offset(x: decayPhase == 2 ? 140 : (decayPhase == 1 ? 140 : 10),
                        y: decayPhase == 2 ? -60 : (decayPhase == 1 ? -60 : -10))
                .opacity(decayPhase > 0 ? 1 : 0)
                .animation(.easeOut(duration: 0.8), value: decayPhase)
            
            Circle()
                .fill(.white)
                .frame(width: 12)
                .shadow(color: .white, radius: 8)
                .offset(x: decayPhase == 2 ? 160 : (decayPhase == 1 ? 140 : 10),
                        y: decayPhase == 2 ? -10 : (decayPhase == 1 ? -60 : -10))
                .opacity(decayPhase > 0 ? 1 : 0)
                .animation(.easeOut(duration: 0.8), value: decayPhase)
            
            Circle()
                .fill(decayPhase == 0 ? colors.last! : colors.first!)
                .frame(width: 68)
                .shadow(color: decayPhase == 0 ? colors.last!.opacity(0.8) : colors.first!.opacity(0.8), radius: 20)
                .scaleEffect(decayPhase == 1 ? 0.85 : 1.05)
                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: decayPhase)
            
            Text(decayPhase == 0 ? "Neutron" : "Proton")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.white)
            
            Text("Beta Decay")
                .diagramLabel(color: colors.last!)
                .offset(x: 80, y: -90)
                .opacity(decayPhase > 0 ? 1 : 0)
                .animation(.easeInOut, value: decayPhase)
        }
        .onReceive(timer) { _ in
            if decayPhase == 0 {
                decayPhase = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { decayPhase = 2 }
            } else {
                decayPhase = 0
            }
        }
    }
}
