//
//  SubatomicParticlesView.swift
//  ProjectDelta
//

import SwiftUI

struct SubatomicParticlesView: View {
    @State private var selectedParticle: ParticleType = .proton
    @Namespace private var animation
    @State private var headerBounce: Bool = false
    
    enum ParticleType: String, CaseIterable {
        case proton = "Proton"
        case neutron = "Neutron"
        case electron = "Electron"
        
        var tabName: String { return self.rawValue }
    }
    
    // Structured Data for the Diagram Key
    struct CompositionPart: Hashable {
        let symbol: String
        let name: String
        let charge: String
        let color: Color
    }
    
    private struct ParticleDetails {
        let name: String
        let chargeSymbol: String
        let baseColor: Color
        let gradientColors: [Color]
        
        let charge: String
        let mass: String
        let location: String
        
        let overview: String
        let analogy: String
        let mechanics: String
        let misconception: String
        let facts: [String]
        
        let compositionParts: [CompositionPart]
        let netEquation: String
    }
    
    private var currentParticle: ParticleDetails {
        switch selectedParticle {
        case .proton:
            return ParticleDetails(
                name: "Proton",
                chargeSymbol: "+",
                baseColor: .red,
                gradientColors: [.red, .orange, .pink],
                charge: "+1 (Positive)",
                mass: "1.672 × 10⁻²⁷ kg",
                location: "Atomic Nucleus",
                overview: "The proton is a massive, positively charged subatomic particle that anchors the atomic nucleus. The exact number of protons an atom possesses determines its fundamental identity as a chemical element.",
                analogy: "Think of the proton as the 'ID card' of the atom. Just like a fingerprint tells you exactly who a person is, the number of protons tells you exactly what element you are looking at (1 is always Hydrogen, 6 is always Carbon).",
                mechanics: "A proton is not a solid, static sphere. It is made of three smaller building blocks called 'quarks' (two 'Up' quarks and one 'Down' quark). Their fractional electrical charges mathematically add together to produce the proton's perfect +1 net charge.",
                misconception: "People often picture protons sitting quietly in the center of an atom. In reality, the quarks inside are zipping around at near light speed, creating a chaotic, boiling storm of quantum energy. Despite this chaos, protons are so stable they are theorized to live longer than the current age of the universe.",
                facts: ["Determines the element's atomic number", "Composed of 3 quarks (uud)", "Mass is 99% binding energy, 1% quarks"],
                compositionParts: [
                    CompositionPart(symbol: "u", name: "Up Quark", charge: "+⅔ e", color: .red),
                    CompositionPart(symbol: "u", name: "Up Quark", charge: "+⅔ e", color: .green),
                    CompositionPart(symbol: "d", name: "Down Quark", charge: "-⅓ e", color: .blue)
                ],
                netEquation: "(+⅔) + (+⅔) + (-⅓) = +1 Net Charge"
            )
        case .neutron:
            return ParticleDetails(
                name: "Neutron",
                chargeSymbol: "0",
                baseColor: .teal,
                gradientColors: [.teal, .cyan, .mint],
                charge: "0 (Neutral)",
                mass: "1.674 × 10⁻²⁷ kg",
                location: "Atomic Nucleus",
                overview: "The neutron is the electrically neutral counterpart to the proton, residing alongside it in the nucleus. It is slightly heavier than a proton and provides the crucial 'nuclear glue' required to hold the atom together.",
                analogy: "Imagine trying to pack highly repulsive magnets (protons) into a tiny box. Neutrons act as the nuclear 'bubble wrap' between them, adding the binding strength needed to hold the nucleus together without adding more repulsive electric charge.",
                mechanics: "A neutron consists of one 'Up' quark and two 'Down' quarks. When you add their fractional charges together, they perfectly cancel out to zero, giving the neutron its neutral identity while still allowing it to interact via the strong nuclear force.",
                misconception: "Because neutrons have no electric charge, people assume they are unimportant. Without neutrons to stabilize the nucleus, no element heavier than Hydrogen could exist. The universe would be entirely devoid of complex chemistry and life.",
                facts: ["Acts as the atomic peacekeeper", "Composed of 3 quarks (udd)", "Creates isotopes when counts vary"],
                compositionParts: [
                    CompositionPart(symbol: "u", name: "Up Quark", charge: "+⅔ e", color: .red),
                    CompositionPart(symbol: "d", name: "Down Quark", charge: "-⅓ e", color: .green),
                    CompositionPart(symbol: "d", name: "Down Quark", charge: "-⅓ e", color: .blue)
                ],
                netEquation: "(+⅔) + (-⅓) + (-⅓) = 0 Net Charge"
            )
        case .electron:
            return ParticleDetails(
                name: "Electron",
                chargeSymbol: "−",
                baseColor: .blue,
                gradientColors: [.blue, .indigo, .purple],
                charge: "-1 (Negative)",
                mass: "9.109 × 10⁻³¹ kg",
                location: "Probability Cloud",
                overview: "The electron is a fundamental, negatively charged particle that swarms around the nucleus. It is nearly 2,000 times lighter than a proton and is entirely responsible for electricity, magnetism, and the chemical bonds that build our world.",
                analogy: "If the atomic nucleus were a heavy bowling ball sitting in the middle of a massive football stadium, the electrons would be like a swarm of gnats buzzing around the outermost nosebleed seats. Most of a solid object is entirely empty space!",
                mechanics: "Electrons are elementary particles—they aren't made of smaller pieces. They don't orbit the nucleus in perfect circles like planets around a sun; instead, they exist as a fuzzy 'probability cloud,' meaning an electron is theoretically everywhere in its shell simultaneously until it interacts with something.",
                misconception: "We often picture electricity as individual electrons zooming through wires at the speed of light. In reality, individual electrons in a wire move at a crawl (less than a millimeter per second). It's the electromagnetic energy wave that travels near light speed.",
                facts: ["Responsible for all chemical bonding", "Fundamental particle (a lepton)", "Exists as a wave-particle duality"],
                compositionParts: [
                    CompositionPart(symbol: "e⁻", name: "Electron", charge: "-1 e", color: .blue),
                    CompositionPart(symbol: "ψ", name: "Wave Function", charge: "Probability", color: .indigo)
                ],
                netEquation: "Fundamental Lepton (No internal structure)"
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
                    
                    // Dynamic Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: currentParticle.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: isWide ? 88 : 76, height: isWide ? 88 : 76)
                                .shadow(color: currentParticle.baseColor.opacity(0.6), radius: 15, x: 0, y: 8)
                            
                            Text(currentParticle.chargeSymbol)
                                .font(.system(size: isWide ? 56 : 48, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                        }
                        .frame(height: isWide ? 88 : 76)
                        .padding(.top, isWide ? 60 : 40)
                        .scaleEffect(headerBounce ? 1.08 : 1.0)
                        
                        Text(currentParticle.name)
                            .font(.system(size: isWide ? 52 : 42, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(LinearGradient(colors: currentParticle.gradientColors, startPoint: .leading, endPoint: .trailing))
                            .contentTransition(.numericText())
                    }
                    .padding(.bottom, 8)
                    
                    // Segmented Control (Extracted to subview to fix compiler timeout)
                    HStack(spacing: 8) {
                        ForEach(ParticleType.allCases, id: \.self) { particle in
                            ParticleTabButton(
                                particle: particle,
                                isSelected: selectedParticle == particle,
                                isWide: isWide,
                                activeColors: currentParticle.gradientColors,
                                namespace: animation
                            ) {
                                // Trigger header bounce on switch
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    headerBounce = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        headerBounce = false
                                    }
                                }
                                
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    selectedParticle = particle
                                }
                            }
                        }
                    }
                    .padding(.bottom, isWide ? 20 : 12)
                    
                    // Content Grid
                    if isWide {
                        HStack(alignment: .top, spacing: 40) {
                            // Left Column
                            VStack(spacing: cardSpacing) {
                                particleVisualizerBox(isWide: true)
                                metricsBox()
                                mechanicsBox()
                            }
                            // Right Column
                            VStack(spacing: cardSpacing) {
                                overviewBox()
                                analogyBox()
                                misconceptionBox()
                                factsBox()
                            }
                        }
                    } else {
                        // Mobile Layout
                        VStack(spacing: cardSpacing) {
                            particleVisualizerBox(isWide: false)
                            metricsBox()
                            overviewBox()
                            analogyBox()
                            mechanicsBox()
                            misconceptionBox()
                            factsBox()
                        }
                    }
                }
                .padding(.horizontal, contentPadding)
                .padding(.bottom, isWide ? 80 : 160)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Subatomic Particles")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        // Handles native haptics cross-platform
        .sensoryFeedback(.selection, trigger: selectedParticle)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func particleVisualizerBox(isWide: Bool) -> some View {
        VStack(spacing: 0) {
            
            // 3D Visualizer Animation Stage
            ParticleVisualizer(particleType: selectedParticle, gradientColors: currentParticle.gradientColors)
                .frame(height: 280) // Fixed height ensures the HUD aligns perfectly below it
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            
            // Diagram Key / HUD
            HStack {
                DiagramKeyHUD(parts: currentParticle.compositionParts, equation: currentParticle.netEquation)
                    .frame(maxWidth: isWide ? 400 : .infinity, alignment: .leading)
                
                if isWide { Spacer() }
            }
            .padding([.horizontal, .bottom], 24)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                RadialGradient(colors: [currentParticle.baseColor.opacity(0.15), .clear], center: .top, startRadius: 10, endRadius: 220)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(currentParticle.baseColor.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: currentParticle.baseColor.opacity(0.12), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func metricsBox() -> some View {
        ParticleCard(baseColor: currentParticle.baseColor, gradientColors: currentParticle.gradientColors) {
            VStack(spacing: 24) {
                ParticleMetricRow(title: "Electric Charge", value: currentParticle.charge)
                ParticleMetricRow(title: "Rest Mass", value: currentParticle.mass)
                ParticleMetricRow(title: "Typical Location", value: currentParticle.location)
            }
        }
    }
    
    @ViewBuilder
    private func overviewBox() -> some View {
        ParticleCard(title: "The Science", icon: "books.vertical.fill", baseColor: currentParticle.baseColor, gradientColors: currentParticle.gradientColors) {
            Text(currentParticle.overview)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .lineSpacing(8)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func analogyBox() -> some View {
        ParticleCard(title: "The Simple Explanation", icon: "lightbulb.fill", baseColor: currentParticle.baseColor, gradientColors: currentParticle.gradientColors) {
            Text(currentParticle.analogy)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .lineSpacing(8)
                .foregroundStyle(.primary.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func mechanicsBox() -> some View {
        ParticleCard(title: "Quantum Mechanics", icon: "atom", baseColor: currentParticle.baseColor, gradientColors: currentParticle.gradientColors) {
            Text(currentParticle.mechanics)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .lineSpacing(8)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func misconceptionBox() -> some View {
        ParticleCard(title: "Clearing Up Confusion", icon: "exclamationmark.triangle.fill", baseColor: currentParticle.baseColor, gradientColors: currentParticle.gradientColors) {
            Text(currentParticle.misconception)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .lineSpacing(8)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func factsBox() -> some View {
        ParticleCard(title: "Core Facts", icon: "star.fill", baseColor: currentParticle.baseColor, gradientColors: currentParticle.gradientColors) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(currentParticle.facts, id: \.self) { fact in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LinearGradient(colors: currentParticle.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: currentParticle.baseColor.opacity(0.5), radius: 4, y: 2)
                        Text(fact)
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

private struct ParticleTabButton: View {
    let particle: SubatomicParticlesView.ParticleType
    let isSelected: Bool
    let isWide: Bool
    let activeColors: [Color]
    var namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(particle.tabName)
                .font(.system(isWide ? .title3 : .headline, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .foregroundColor(isSelected ? .white : .secondary)
                .background(
                    ZStack {
                        if isSelected {
                            LinearGradient(colors: activeColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .clipShape(Capsule())
                                .matchedGeometryEffect(id: "ParticlePill", in: namespace)
                        } else {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Capsule().stroke(isSelected ? .clear : .secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ParticleMetricRow: View {
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

private struct ParticleCard<Content: View>: View {
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

// MARK: - Data-Driven Diagram Key HUD
private struct DiagramKeyHUD: View {
    let parts: [SubatomicParticlesView.CompositionPart]
    let equation: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Composition & Math")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .textCase(.uppercase)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(parts, id: \.self) { part in
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(part.color)
                                .frame(width: 24, height: 24)
                                .shadow(color: part.color.opacity(0.6), radius: 4)
                            Text(part.symbol)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        }
                        
                        Text("\(part.name) (\(part.charge))")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Divider().background(Color.secondary.opacity(0.3))
            
            Text(equation)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Diagram Label Modifier
fileprivate struct SubatomicDiagramLabelModifier: ViewModifier {
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

fileprivate extension View {
    func subatomicDiagramLabel(color: Color) -> some View {
        self.modifier(SubatomicDiagramLabelModifier(color: color))
    }
}

// MARK: - Vibrant Educational Visualizations

private struct ParticleVisualizer: View {
    let particleType: SubatomicParticlesView.ParticleType
    let gradientColors: [Color]
    
    var body: some View {
        ZStack {
            switch particleType {
            case .proton:
                ProtonAnimation()
            case .neutron:
                NeutronAnimation()
            case .electron:
                ElectronAnimation(colors: gradientColors)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 1. Proton: 2 Up (Red/Green), 1 Down (Blue)
private struct ProtonAnimation: View {
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 120
    @State private var rotation3: Double = 240
    @State private var corePulse = false
    
    var body: some View {
        ZStack {
            // Nucleon Containment Field
            Circle()
                .fill(.white.opacity(0.02))
                .frame(width: 220)
            Circle()
                .stroke(.red.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .frame(width: 220)
                .rotationEffect(.degrees(rotation1 / 4))
            
            // Glowing Core / Gluon Field
            Circle()
                .fill(RadialGradient(colors: [.red.opacity(0.3), .clear], center: .center, startRadius: 10, endRadius: 80))
                .frame(width: 160)
                .scaleEffect(corePulse ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: corePulse)
            
            // Precision Geometric Binding Energy Springs
            Path { path in
                let center = CGPoint(x: 125, y: 125)
                path.move(to: CGPoint(x: center.x, y: center.y - 45))
                path.addLine(to: CGPoint(x: center.x - 40, y: center.y + 25))
                path.addLine(to: CGPoint(x: center.x + 40, y: center.y + 25))
                path.closeSubpath()
            }
            .stroke(LinearGradient(colors: [.red, .orange, .pink], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
            .frame(width: 250, height: 250)
            
            // Orbiting Quarks
            QuarkNode(symbol: "u", color: .red)
                .offset(y: -45)
                .rotationEffect(.degrees(rotation1))
            
            QuarkNode(symbol: "u", color: .green)
                .offset(x: -40, y: 25)
                .rotationEffect(.degrees(rotation2))
            
            QuarkNode(symbol: "d", color: .blue)
                .offset(x: 40, y: 25)
                .rotationEffect(.degrees(rotation3))
        }
        .onAppear {
            corePulse = true
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { rotation1 = 360 }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { rotation2 = 480 }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { rotation3 = 600 }
        }
    }
}

// 2. Neutron: 1 Up (Red), 2 Down (Green/Blue)
private struct NeutronAnimation: View {
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 120
    @State private var rotation3: Double = 240
    @State private var corePulse = false
    
    var body: some View {
        ZStack {
            // Nucleon Containment Field
            Circle()
                .fill(.white.opacity(0.02))
                .frame(width: 220)
            Circle()
                .stroke(.teal.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .frame(width: 220)
                .rotationEffect(.degrees(-rotation1 / 4))
            
            // Glowing Core / Gluon Field
            Circle()
                .fill(RadialGradient(colors: [.teal.opacity(0.2), .clear], center: .center, startRadius: 10, endRadius: 80))
                .frame(width: 160)
                .scaleEffect(corePulse ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: corePulse)
            
            // Precision Geometric Binding Energy Springs
            Path { path in
                let center = CGPoint(x: 125, y: 125)
                path.move(to: CGPoint(x: center.x, y: center.y - 45))
                path.addLine(to: CGPoint(x: center.x - 40, y: center.y + 25))
                path.addLine(to: CGPoint(x: center.x + 40, y: center.y + 25))
                path.closeSubpath()
            }
            .stroke(LinearGradient(colors: [.teal, .cyan, .mint], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
            .frame(width: 250, height: 250)
            
            // Orbiting Quarks
            QuarkNode(symbol: "u", color: .red)
                .offset(y: -45)
                .rotationEffect(.degrees(rotation1))
            
            QuarkNode(symbol: "d", color: .green)
                .offset(x: -40, y: 25)
                .rotationEffect(.degrees(rotation2))
            
            QuarkNode(symbol: "d", color: .blue)
                .offset(x: 40, y: 25)
                .rotationEffect(.degrees(rotation3))
        }
        .onAppear {
            corePulse = true
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { rotation1 = 360 }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { rotation2 = 480 }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { rotation3 = 600 }
        }
    }
}

// Reusable Quark Node
private struct QuarkNode: View {
    let symbol: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 44, height: 44)
                .shadow(color: color.opacity(0.8), radius: 10)
            
            Text(symbol)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
    }
}

// 3. Electron: Multi-layered Probability Cloud
private struct ElectronAnimation: View {
    let colors: [Color]
    @State private var wavePulse = false
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            // Central Nucleus
            Circle()
                .fill(.white)
                .frame(width: 10)
                .shadow(color: .white, radius: 8)
            
            // Probability Cloud / Wave Function Layers
            ForEach(0..<5) { i in
                Ellipse()
                    .stroke(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: CGFloat(8 - i))
                    .frame(width: wavePulse ? CGFloat(180 + (i * 20)) : CGFloat(120 + (i * 15)),
                           height: wavePulse ? CGFloat(100 + (i * 10)) : CGFloat(60 + (i * 8)))
                    .rotationEffect(.degrees(rotation + Double(i * 36)))
                    .blur(radius: wavePulse ? CGFloat(6 + i) : CGFloat(3 + i))
                    .opacity(wavePulse ? 0.15 : 0.4)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double(i) * 0.2), value: wavePulse)
            }
        }
        .onAppear {
            wavePulse = true
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    NavigationStack {
        SubatomicParticlesView()
            .preferredColorScheme(.light)
    }
}
