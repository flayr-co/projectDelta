//
//  EMInteractionView.swift
//  ProjectDelta
//

import SwiftUI

struct EMInteractionView: View {
    @State private var frequencyLog: Double = 9.5
    @State private var selectedMaterial: MaterialType = .water
    @Namespace private var animation
    
    enum MaterialType: String, CaseIterable {
        case water = "Water"
        case metal = "Metal"
        case dna = "Human DNA"
        
        var tabName: String { return self.rawValue }
    }
    
    enum InteractionType {
        case transmission
        case reflection
        case heating
        case ionization
    }
    
    // Physics Logic
    private var currentInteraction: InteractionType {
        switch selectedMaterial {
        case .water:
            if frequencyLog < 8.0 { return .transmission }
            else if frequencyLog < 11.5 { return .heating }
            else if frequencyLog < 14.8 { return .transmission }
            else { return .ionization }
            
        case .metal:
            if frequencyLog < 15.0 { return .reflection }
            else { return .ionization }
            
        case .dna:
            if frequencyLog < 14.8 { return .transmission }
            else { return .ionization }
        }
    }
    
    private struct EMRegion {
        let name: String
        let color: Color
        let wavelengthText: String
        let photonEnergy: String
    }
    
    private var currentRegion: EMRegion {
        switch frequencyLog {
        case ..<9.0:
            return EMRegion(name: "Radio Waves", color: .blue, wavelengthText: "~100 m", photonEnergy: "< 10⁻⁶ eV")
        case 9.0..<11.5:
            return EMRegion(name: "Microwaves", color: .orange, wavelengthText: "~1 cm", photonEnergy: "~10⁻⁴ eV")
        case 11.5..<14.3:
            return EMRegion(name: "Infrared", color: .red, wavelengthText: "~10 μm", photonEnergy: "~0.1 eV")
        case 14.3..<14.8:
            return EMRegion(name: "Visible Light", color: .green, wavelengthText: "~500 nm", photonEnergy: "1.8 – 3.1 eV")
        case 14.8..<16.5:
            return EMRegion(name: "Ultraviolet", color: .purple, wavelengthText: "~100 nm", photonEnergy: "3.1 – 100 eV")
        case 16.5..<19.5:
            return EMRegion(name: "X-Rays", color: .cyan, wavelengthText: "~1 nm", photonEnergy: "100 eV – 100 keV")
        default:
            return EMRegion(name: "Gamma Rays", color: .pink, wavelengthText: "< 0.01 nm", photonEnergy: "> 100 keV")
        }
    }
    
    // Scientifically rigorous explanations
    private var educationalContent: (title: String, body: String, misconception: String) {
        switch (selectedMaterial, currentInteraction) {
        case (.water, .heating):
            return (
                "Dielectric Dipole Heating",
                "Water molecules are permanent electric dipoles (with a negative Oxygen pole and positive Hydrogen poles). The rapidly alternating electric field of a microwave exerts continuous torque on the molecules, forcing them to rotate back and forth billions of times per second. This rotational friction converts electromagnetic energy into thermal kinetic energy.",
                "Microwave ovens do NOT work by 'matching the natural resonant frequency of water.' If they did, all the energy would be absorbed in the first millimeter of food. They operate at 2.45 GHz specifically because water absorbs this frequency moderately, allowing the wave to penetrate several centimeters deep before heat conducts inward."
            )
        case (.water, .transmission):
            return (
                "Optical & Radio Transparency",
                "Low-frequency radio waves and visible light pass straight through water without significant absorption. Visible photons lack the exact quantum energy needed to excite water's electronic transitions, yet oscillate too fast for the bulky water molecule to rotate. Water thus exhibits an 'optical window,' allowing visible light to travel deep into lakes and oceans.",
                "Water isn't universally transparent. It is intensely opaque to most of the infrared spectrum and vacuum ultraviolet. It only appears transparent to us because our biological eyes evolved specifically to detect the narrow window of frequencies that penetrates sunlight and water."
            )
        case (.water, .ionization):
            return (
                "Water Radiolysis & Free Radicals",
                "High-energy photons from X-Rays and Gamma Rays carry far more energy than the chemical bond strength of water. When struck, water molecules are ionized (H₂O → H₂O⁺ + e⁻), which rapidly breaks apart into highly reactive Hydroxyl free radicals (•OH) and Hydrogen Peroxide (H₂O₂).",
                "Irradiated water does NOT become radioactive or glow. The danger of high-energy radiation to living organisms is indirect: because your body is 70% water, ionizing radiation turns cellular water into a bath of toxic free radicals that chemically tear through cellular machinery."
            )
        
        case (.metal, .reflection):
            return (
                "Drude Electron Plasma Reflection",
                "Metals are bound by an 'electron sea'—a dense lattice of positive ion cores submerged in freely moving conduction electrons. When low-to-medium frequency waves strike the surface, these free electrons oscillate in direct opposition to the wave's electric field. This collective motion re-radiates an identical wave traveling backward, producing specular reflection.",
                "Household mirrors aren't fundamentally silver or white—they are whatever color is reflected in them. The glass in a mirror is just a protective plate; the actual reflection comes from an ultra-thin backing of metal (usually aluminum or silver) acting as a conductive electromagnetic shield."
            )
        case (.metal, .ionization):
            return (
                "The Photoelectric Effect",
                "When photon energy exceeds the metal's characteristic 'work function' (Φ), the waves plunge into the atomic lattice and directly eject core electrons with kinetic energy K = hf - Φ. This phenomenon proved that light travels as discrete packets of energy (photons), earning Albert Einstein the 1921 Nobel Prize in Physics.",
                "Dental lead aprons do not 'bounce' X-Rays away like a shield. Lead is used because it has an extremely high atomic number (Z = 82) and high density, meaning it has an enormous concentration of tightly bound electrons that fully absorb X-ray photons via inner-shell photoelectric absorption."
            )
            
        case (.dna, .transmission):
            return (
                "Non-Ionizing Bond Safety",
                "Radio waves, microwaves, infrared, and visible light are strictly 'Non-Ionizing.' The covalent bonds holding human DNA base pairs together require roughly 3 to 5 electron-volts (eV) of energy to rupture. A radio or microwave photon carries less than 0.0001 eV, meaning it is mathematically and physically impossible for it to snap DNA bonds.",
                "Cell phones, Wi-Fi routers, and 5G towers operate exclusively in the radio and microwave bands. Because individual photons lack the threshold quantum energy to ionize atoms, they cannot cause genetic mutations or DNA lesions, regardless of signal intensity."
            )
        case (.dna, .ionization):
            return (
                "Photodimerization & Double-Strand Breaks",
                "Photons in the Ultraviolet, X-Ray, and Gamma bands carry sufficient quantum energy (3 eV to MeV) to ionize biomolecules. UV radiation causes adjacent thymine bases in DNA to chemically fuse into 'thymine dimers,' kinking the helix. Higher-energy X-Rays physically sever the sugar-phosphate backbone, causing lethal double-strand breaks.",
                "A sunburn is not a thermal burn from heat; it is acute radiation damage. When skin cells detect that UV photons have corrupted their DNA beyond repair, they initiate programmed cellular suicide (apoptosis) to prevent mutated cells from replicating into melanoma."
            )
            
        default:
            return (
                "Complex Electromagnetic Interaction",
                "At this frequency boundary, matter exhibits coupled absorption, refraction, and scattering dictated by complex dielectric permittivity.",
                "Matter interactions are not strictly binary; real-world behavior depends on temperature, material thickness, and molecular orientation."
            )
        }
    }
    
    private let spectrumGradient = LinearGradient(
        colors: [.blue, .orange, .red, .green, .purple, .cyan, .pink],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 850
            let contentPadding: CGFloat = isWide ? 32 : 20
            let cardSpacing: CGFloat = isWide ? 20 : 16
            
            #if os(macOS)
            let topClearance: CGFloat = 36
            #else
            let topClearance: CGFloat = isWide ? 24 : 12
            #endif
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isWide ? 24 : 20) {
                    
                    Spacer(minLength: isWide ? 20 : 10) // Forces layout to center vertically
                    
                    // Sleeker, Optimized Header
                    VStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.system(size: isWide ? 48 : 40, weight: .light))
                            .foregroundStyle(currentRegion.color)
                            .shadow(color: currentRegion.color.opacity(0.8), radius: 10, x: 0, y: 4)
                            .padding(.top, topClearance)
                            .symbolEffect(.pulse, value: frequencyLog)
                        
                        Text("Wave Interactions")
                            .font(.system(size: isWide ? 36 : 28, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(currentRegion.color)
                            .contentTransition(.numericText())
                    }
                    .padding(.bottom, 4)
                    
                    // Restored Stacked Controls
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            ForEach(MaterialType.allCases, id: \.self) { material in
                                MaterialTabButton(
                                    material: material,
                                    isSelected: selectedMaterial == material,
                                    isWide: isWide,
                                    activeColor: currentRegion.color,
                                    namespace: animation
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        selectedMaterial = material
                                    }
                                }
                            }
                        }
                        
                        VStack(spacing: 6) {
                            HStack {
                                Text("Radio")
                                Spacer()
                                Text(currentRegion.name)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundColor(currentRegion.color)
                                Spacer()
                                Text("Gamma")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                            
                            Slider(value: $frequencyLog, in: 6...22, step: 0.1)
                                .tint(currentRegion.color)
                                .background(
                                    RoundedRectangle(cornerRadius: 3).fill(spectrumGradient).frame(height: 5)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.secondary.opacity(0.15), lineWidth: 1))
                    }
                    
                    // Adaptive Two-Column Content Grid
                    if isWide {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(spacing: cardSpacing) {
                                interactionVisualizerBox(isWide: true)
                                statsBox(isWide: true)
                            }
                            VStack(spacing: cardSpacing) {
                                explanationBox(isWide: true)
                                misconceptionBox(isWide: true)
                            }
                        }
                    } else {
                        VStack(spacing: cardSpacing) {
                            interactionVisualizerBox(isWide: false)
                            statsBox(isWide: false)
                            explanationBox(isWide: false)
                            misconceptionBox(isWide: false)
                        }
                    }
                    
                    Spacer(minLength: isWide ? 40 : 20)
                }
                .padding(.horizontal, contentPadding)
                .frame(maxWidth: 1300)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Wave Interactions")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sensoryFeedback(.selection, trigger: selectedMaterial)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func interactionVisualizerBox(isWide: Bool) -> some View {
        VStack(spacing: 0) {
            // Dedicated Animation Stage
            InteractionStage(
                interaction: currentInteraction,
                material: selectedMaterial,
                waveColor: currentRegion.color,
                frequency: frequencyLog,
                isWide: isWide
            )
            .frame(height: isWide ? 280 : 180) // Isolated frame guarantees no UI collision
            .frame(maxWidth: .infinity)
            .padding(.top, isWide ? 16 : 8)
            .clipped()
            
            // HUD strictly below the animation
            HStack {
                DiagramKeyHUD(
                    title: "Interaction Status",
                    items: [
                        "Band: \(currentRegion.name)",
                        "Target: \(selectedMaterial.rawValue)",
                        "Outcome: \(interactionResultText)"
                    ],
                    accentColor: currentRegion.color
                )
                .frame(maxWidth: isWide ? 400 : .infinity, alignment: .leading)
                
                if isWide { Spacer() }
            }
            .padding([.horizontal, .bottom], isWide ? 24 : 16)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial)
                RadialGradient(colors: [currentRegion.color.opacity(0.12), .clear], center: .top, startRadius: 10, endRadius: isWide ? 300 : 200)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(currentRegion.color.opacity(0.25), lineWidth: 1.2))
        .shadow(color: currentRegion.color.opacity(0.08), radius: 15, x: 0, y: 6)
    }
    
    private var interactionResultText: String {
        switch currentInteraction {
        case .transmission: return "Transmission (Passes Through)"
        case .reflection: return "Reflection (Bounces Off)"
        case .heating: return "Dielectric Absorption (Heating)"
        case .ionization: return "Ionization (Bond Destruction)"
        }
    }
    
    private func statsBox(isWide: Bool) -> some View {
        InfoCard(baseColor: currentRegion.color, isWide: isWide) {
            VStack(spacing: isWide ? 16 : 12) {
                InfoRow(title: "Wavelength", value: currentRegion.wavelengthText)
                InfoRow(title: "Frequency Band", value: "10^\(String(format: "%.1f", frequencyLog)) Hz")
                InfoRow(title: "Photon Energy", value: currentRegion.photonEnergy)
                InfoRow(title: "Radiation Hazard", value: currentInteraction == .ionization ? "Ionizing (High Hazard)" : "Non-Ionizing (Safe)")
            }
        }
    }
    
    private func explanationBox(isWide: Bool) -> some View {
        InfoCard(title: educationalContent.title, icon: "books.vertical.fill", baseColor: currentRegion.color, isWide: isWide) {
            Text(educationalContent.body)
                .font(.system(size: isWide ? 16 : 15, weight: .regular, design: .rounded))
                .lineSpacing(6)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func misconceptionBox(isWide: Bool) -> some View {
        InfoCard(title: "Clearing Up Confusion", icon: "exclamationmark.triangle.fill", baseColor: currentRegion.color, isWide: isWide) {
            Text(educationalContent.misconception)
                .font(.system(size: isWide ? 16 : 15, weight: .regular, design: .rounded))
                .lineSpacing(6)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Reusable UI Components

private struct MaterialTabButton: View {
    let material: EMInteractionView.MaterialType
    let isSelected: Bool
    let isWide: Bool
    let activeColor: Color
    var namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(material.tabName)
                .font(.system(isWide ? .title3 : .subheadline, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, isWide ? 16 : 12)
                .frame(maxWidth: .infinity)
                .foregroundColor(isSelected ? .white : .secondary)
                .background(
                    ZStack {
                        if isSelected {
                            activeColor
                                .clipShape(Capsule())
                                .matchedGeometryEffect(id: "MaterialPill", in: namespace)
                        } else {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(Capsule().stroke(isSelected ? .clear : .secondary.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct InfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.headline, design: .rounded, weight: .heavy)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

fileprivate struct InfoCard<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var baseColor: Color
    var isWide: Bool
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: isWide ? 16 : 12) {
            if let title = title, let icon = icon {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.title2.weight(.bold)).foregroundStyle(baseColor).shadow(color: baseColor.opacity(0.4), radius: 3, y: 1)
                    Text(title).font(.title3.weight(.heavy)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                }
                Divider().opacity(0.4)
            }
            content().frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(isWide ? 28 : 20)
        .background(
            ZStack {
                Rectangle().fill(.regularMaterial)
                LinearGradient(colors: [baseColor.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(baseColor.opacity(0.2), lineWidth: 1))
        .shadow(color: baseColor.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

fileprivate struct DiagramKeyHUD: View {
    let title: String
    let items: [String]
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .heavy, design: .rounded)).textCase(.uppercase).foregroundColor(.secondary)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .center, spacing: 8) {
                    Circle().fill(accentColor).frame(width: 5, height: 5).shadow(color: accentColor.opacity(0.8), radius: 2)
                    Text(item).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.secondary.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Advanced 3D Interaction Animation Stage

fileprivate struct InteractionStage: View {
    let interaction: EMInteractionView.InteractionType
    let material: EMInteractionView.MaterialType
    let waveColor: Color
    let frequency: Double
    let isWide: Bool
    
    @State private var wavePhase = 0.0
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h / 2
            let materialWidth: CGFloat = isWide ? 110 : 86
            let materialX = w / 2
            
            // Collision boundary
            let collisionX = materialX - (materialWidth / 2) + 8
            
            ZStack {
                // Incoming Dual-Axis EM Wave
                DualAxisWave(phase: wavePhase, frequency: mappedFreq, color: waveColor)
                    .frame(width: collisionX)
                    .position(x: collisionX / 2, y: midY)
                
                // Outgoing Interaction Mechanics
                if interaction == .transmission {
                    let rightSideX = materialX + (materialWidth / 2) - 8
                    let remainingWidth = w - rightSideX
                    
                    // Transmitted wave (slightly attenuated)
                    DualAxisWave(phase: wavePhase, frequency: mappedFreq, color: waveColor.opacity(0.45))
                        .frame(width: remainingWidth)
                        .position(x: rightSideX + (remainingWidth / 2), y: midY)
                        
                } else if interaction == .reflection {
                    // Reflected Wave Bounces Directly Backwards
                    DualAxisWave(phase: -wavePhase, frequency: mappedFreq, color: waveColor.opacity(0.6))
                        .frame(width: collisionX)
                        .position(x: collisionX / 2, y: midY)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                }
                
                // Detailed 3D Physical Material Representation
                MaterialNode3D(material: material, interaction: interaction, color: waveColor, isWide: isWide)
                    .position(x: materialX, y: midY)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }
    
    var mappedFreq: Double {
        return max(1.6, (frequency - 5) / 3.2)
    }
}

// Dual-Axis Wave (Simulates perpendicular E and B vector fields)
fileprivate struct DualAxisWave: View {
    let phase: Double
    let frequency: Double
    let color: Color
    
    var body: some View {
        ZStack {
            // Magnetic Vector Component (B-Field, horizontally compressed)
            SineWave(phase: phase, frequency: frequency)
                .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .scaleEffect(y: 0.3)
            
            // Electric Vector Component (E-Field)
            SineWave(phase: phase, frequency: frequency)
                .stroke(color, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                .shadow(color: color.opacity(0.7), radius: 6)
        }
    }
}

// MARK: - Bespoke 3D Material Representations

fileprivate struct MaterialNode3D: View {
    let material: EMInteractionView.MaterialType
    let interaction: EMInteractionView.InteractionType
    let color: Color
    let isWide: Bool
    
    @State private var jiggle = false
    @State private var emit = false
    @State private var dipoleRotation = 0.0
    
    var body: some View {
        ZStack {
            switch material {
            case .water:
                water3DRepresentation
            case .metal:
                metal3DRepresentation
            case .dna:
                dna3DRepresentation
            }
        }
        .rotation3DEffect(.degrees(14), axis: (x: 0, y: 1, z: 0))
        .shadow(color: .black.opacity(0.3), radius: 10, x: 8, y: 8)
        .shadow(color: interaction == .heating ? color : .clear, radius: interaction == .heating ? 30 : 0)
        .rotationEffect(.degrees(jiggle ? 2 : -2))
        .onChange(of: interaction) { _, _ in resetAnimations() }
        .onAppear { resetAnimations() }
    }
    
    // 1. Water: Translucent Prism with Molecular Dipoles
    private var water3DRepresentation: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isWide ? 20 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.55), Color.blue.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: isWide ? 110 : 86, height: isWide ? 180 : 140)
                .overlay(
                    RoundedRectangle(cornerRadius: isWide ? 20 : 16, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.8), .clear, .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                )
            
            // Rotating H₂O Dipole Molecules
            VStack(spacing: isWide ? 32 : 24) {
                H2OMolecule(rotation: dipoleRotation, isWide: isWide)
                H2OMolecule(rotation: -dipoleRotation, isWide: isWide)
            }
            
            // Radiolysis free radical sparks
            if interaction == .ionization {
                ionizationSparks
            }
        }
    }
    
    // 2. Metal: Polished Chrome with Conduction Electron Lattice
    private var metal3DRepresentation: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isWide ? 20 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.gray, Color.black.opacity(0.85), Color.gray],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: isWide ? 110 : 86, height: isWide ? 180 : 140)
                .overlay(
                    RoundedRectangle(cornerRadius: isWide ? 20 : 16, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                )
            
            // Conduction Electron Cloud Layer
            VStack(spacing: isWide ? 20 : 16) {
                ForEach(0..<4) { _ in
                    HStack(spacing: isWide ? 18 : 14) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.yellow.opacity(0.9))
                                .frame(width: isWide ? 7 : 5, height: isWide ? 7 : 5)
                                .shadow(color: .yellow, radius: 4)
                        }
                    }
                }
            }
            
            // Photoelectric Ejected Core Electrons
            if interaction == .ionization {
                ionizationSparks
            }
        }
    }
    
    // 3. DNA: Visual Double-Helix Base Pair Strand
    private var dna3DRepresentation: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isWide ? 20 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.85), Color.indigo],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: isWide ? 110 : 86, height: isWide ? 180 : 140)
                .overlay(
                    RoundedRectangle(cornerRadius: isWide ? 20 : 16, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                )
            
            // Double-Helix Ladder Rungs
            VStack(spacing: isWide ? 16 : 12) {
                ForEach(0..<5) { idx in
                    HStack(spacing: isWide ? 6 : 4) {
                        Circle().fill(Color.pink).frame(width: isWide ? 8 : 6, height: isWide ? 8 : 6)
                        Rectangle()
                            .fill(interaction == .ionization && idx % 2 == 0 ? Color.clear : Color.cyan)
                            .frame(width: isWide ? 44 : 32, height: isWide ? 3.5 : 2.5)
                        Circle().fill(Color.purple).frame(width: isWide ? 8 : 6, height: isWide ? 8 : 6)
                    }
                }
            }
            
            // Photodimerization lesion damage sparks
            if interaction == .ionization {
                ionizationSparks
            }
        }
    }
    
    private var ionizationSparks: some View {
        ForEach(0..<4) { i in
            Circle()
                .fill(.white)
                .frame(width: isWide ? 8 : 5, height: isWide ? 8 : 5)
                .shadow(color: color, radius: 8)
                .offset(x: emit ? CGFloat.random(in: 50...120) : 0, y: emit ? CGFloat.random(in: -90...90) : 0)
                .opacity(emit ? 0 : 1)
                .animation(.easeOut(duration: 0.5).repeatForever().delay(Double(i) * 0.12), value: emit)
        }
    }
    
    private func resetAnimations() {
        jiggle = (interaction == .heating)
        emit = (interaction == .ionization)
        
        if interaction == .heating {
            withAnimation(.linear(duration: 0.4).repeatForever(autoreverses: true)) {
                dipoleRotation = 45.0
            }
        } else {
            dipoleRotation = 0.0
        }
    }
}

// Microscopic H₂O Model (Oxygen + 2 Hydrogens at 104.5°)
fileprivate struct H2OMolecule: View {
    var rotation: Double
    let isWide: Bool
    
    var body: some View {
        ZStack {
            // Oxygen atom (-)
            Circle()
                .fill(Color.red)
                .frame(width: isWide ? 18 : 14, height: isWide ? 18 : 14)
                .shadow(color: .red.opacity(0.6), radius: 4)
            
            // Hydrogen atoms (+)
            Circle()
                .fill(Color.white)
                .frame(width: isWide ? 10 : 8, height: isWide ? 10 : 8)
                .offset(x: isWide ? -10 : -8, y: isWide ? -10 : -8)
            
            Circle()
                .fill(Color.white)
                .frame(width: isWide ? 10 : 8, height: isWide ? 10 : 8)
                .offset(x: isWide ? 10 : 8, y: isWide ? -10 : -8)
        }
        .rotationEffect(.degrees(rotation))
    }
}

fileprivate struct SineWave: Shape {
    var phase: Double
    var frequency: Double
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let midY = rect.height / 2
        let amplitude = rect.height / 3.4
        
        path.move(to: CGPoint(x: 0, y: midY))
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let y = midY + sin((relativeX * .pi * 2 * frequency) - phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

#Preview {
    NavigationStack {
        EMInteractionView()
            .preferredColorScheme(.dark)
    }
}
