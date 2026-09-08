//
//  MathScratchpadView.swift
//  ProjectDelta
//

import SwiftUI
import Observation

// MARK: - Core Data Models

enum TokenType: String, Hashable {
    case number, variable, operatorSymbol, function, structural
}

struct MathToken: Identifiable, Hashable {
    let id = UUID()
    var value: String
    var type: TokenType
}

// MARK: - View Model

@MainActor
@Observable
class MathScratchpadViewModel {
    // 2D array representing lines of math
    var lines: [[MathToken]] = [[]]
    var activeLineIndex: Int = 0
    var cursorIndex: Int = 0
    
    // Dynamic context based on current problem (can be injected)
    var activeVariables: [String] = ["x", "y", "θ"]
    
    func insert(_ value: String, type: TokenType) {
        let token = MathToken(value: value, type: type)
        lines[activeLineIndex].insert(token, at: cursorIndex)
        cursorIndex += 1
    }
    
    func backspace() {
        if cursorIndex > 0 {
            lines[activeLineIndex].remove(at: cursorIndex - 1)
            cursorIndex -= 1
        } else if activeLineIndex > 0 {
            // Merge with previous line if current is empty
            if lines[activeLineIndex].isEmpty {
                lines.remove(at: activeLineIndex)
                activeLineIndex -= 1
                cursorIndex = lines[activeLineIndex].count
            }
        }
    }
    
    func newLine() {
        activeLineIndex += 1
        lines.insert([], at: activeLineIndex)
        cursorIndex = 0
    }
    
    func clearAll() {
        lines = [[]]
        activeLineIndex = 0
        cursorIndex = 0
    }
    
    func moveCursor(to index: Int, on line: Int) {
        activeLineIndex = line
        cursorIndex = index
    }
}

// MARK: - Main Canvas View

struct MathScratchpadView: View {
    @Bindable var viewModel: MathScratchpadViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var bgPrimary: Color { colorScheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.08) : Color.platformSystemBackground }
    let emeraldAccent = Color(red: 0.15, green: 0.80, blue: 0.50)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scratchpad")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { viewModel.clearAll() }) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(bgPrimary)
            
            // Equation Canvas
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(0..<viewModel.lines.count, id: \.self) { lineIndex in
                            MathLineView(
                                tokens: viewModel.lines[lineIndex],
                                isActive: lineIndex == viewModel.activeLineIndex,
                                cursorIndex: lineIndex == viewModel.activeLineIndex ? viewModel.cursorIndex : nil,
                                onCursorTap: { newIndex in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.moveCursor(to: newIndex, on: lineIndex)
                                    }
                                }
                            )
                            .id(lineIndex)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.platformSystemGroupedBackground)
                .onChange(of: viewModel.activeLineIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .bottom)
                    }
                }
            }
            
            // Custom Keypad
            MathKeypadView(viewModel: viewModel)
        }
        .background(bgPrimary.ignoresSafeArea())
    }
}

// MARK: - Line & Token Rendering

struct MathLineView: View {
    let tokens: [MathToken]
    let isActive: Bool
    let cursorIndex: Int?
    let onCursorTap: (Int) -> Void
    
    let emeraldAccent = Color(red: 0.15, green: 0.80, blue: 0.50)
    
    var body: some View {
        HStack(spacing: 2) {
            // Line Indicator
            Rectangle()
                .fill(isActive ? emeraldAccent : Color.clear)
                .frame(width: 3)
                .cornerRadius(1.5)
                .padding(.trailing, 8)
            
            // Token Flow
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Start of line cursor drop zone
                    CursorDropZone(index: 0, activeCursorIndex: cursorIndex, onSelect: { onCursorTap(0) })
                    
                    ForEach(0..<tokens.count, id: \.self) { i in
                        TokenView(token: tokens[i])
                            .onTapGesture { onCursorTap(i + 1) }
                        
                        CursorDropZone(index: i + 1, activeCursorIndex: cursorIndex, onSelect: { onCursorTap(i + 1) })
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }
            .background(isActive ? Color.platformSystemBackground : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? emeraldAccent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .frame(height: 56)
    }
}

struct TokenView: View {
    let token: MathToken
    
    var body: some View {
        Text(token.value)
            .font(.system(size: 24, weight: token.type == .operatorSymbol ? .bold : .medium, design: .rounded))
            .italic(token.type == .variable)
            .foregroundColor(colorForType(token.type))
            .padding(.horizontal, 2)
    }
    
    private func colorForType(_ type: TokenType) -> Color {
        switch type {
        case .number: return .primary
        case .variable: return .blue
        case .operatorSymbol: return .orange
        case .function: return .purple
        case .structural: return .secondary
        }
    }
}

struct CursorDropZone: View {
    let index: Int
    let activeCursorIndex: Int?
    let onSelect: () -> Void
    
    @State private var isBlinking = false
    let emeraldAccent = Color(red: 0.15, green: 0.80, blue: 0.50)
    
    var isActive: Bool {
        index == activeCursorIndex
    }
    
    var body: some View {
        Rectangle()
            .fill(isActive ? emeraldAccent : Color.clear)
            .frame(width: 2, height: 28)
            .opacity(isActive ? (isBlinking ? 1.0 : 0.0) : 0.0)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            }
    }
}

// MARK: - Custom Context-Aware Keypad

struct MathKeypadView: View {
    @Bindable var viewModel: MathScratchpadViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var triggerHaptic = false
    
    var keypadBg: Color { colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color.platformSecondarySystemBackground }
    var buttonBg: Color { colorScheme == .dark ? Color(red: 0.18, green: 0.18, blue: 0.22) : Color.platformSystemBackground }
    let operatorBg = Color.orange.opacity(0.15)
    let actionBg = Color.blue.opacity(0.15)
    
    var body: some View {
        VStack(spacing: 8) {
            // Context Variables Rail
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.activeVariables, id: \.self) { variable in
                        KeypadButton(text: variable, type: .variable, color: .blue.opacity(0.15)) {
                            viewModel.insert(variable, type: .variable)
                            triggerHaptic.toggle()
                        }
                    }
                    
                    Divider().frame(height: 24).background(Color.gray)
                    
                    KeypadButton(text: "sin", type: .function, color: .purple.opacity(0.15)) { viewModel.insert("sin(", type: .function); triggerHaptic.toggle() }
                    KeypadButton(text: "cos", type: .function, color: .purple.opacity(0.15)) { viewModel.insert("cos(", type: .function); triggerHaptic.toggle() }
                    KeypadButton(text: "tan", type: .function, color: .purple.opacity(0.15)) { viewModel.insert("tan(", type: .function); triggerHaptic.toggle() }
                }
                .padding(.horizontal)
            }
            .frame(height: 50)
            .padding(.top, 8)
            
            // Main Grid
            HStack(spacing: 8) {
                // Numpad
                VStack(spacing: 8) {
                    ForEach([[7,8,9], [4,5,6], [1,2,3]], id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.self) { num in
                                KeypadButton(text: "\(num)", type: .number, color: buttonBg) {
                                    viewModel.insert("\(num)", type: .number)
                                    triggerHaptic.toggle()
                                }
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        KeypadButton(text: ".", type: .number, color: buttonBg) { viewModel.insert(".", type: .number); triggerHaptic.toggle() }
                        KeypadButton(text: "0", type: .number, color: buttonBg) { viewModel.insert("0", type: .number); triggerHaptic.toggle() }
                        KeypadButton(text: "( )", type: .structural, color: buttonBg) { viewModel.insert("(", type: .structural); triggerHaptic.toggle() }
                    }
                }
                
                // Operators
                VStack(spacing: 8) {
                    KeypadButton(text: "÷", type: .operatorSymbol, color: operatorBg) { viewModel.insert("÷", type: .operatorSymbol); triggerHaptic.toggle() }
                    KeypadButton(text: "×", type: .operatorSymbol, color: operatorBg) { viewModel.insert("×", type: .operatorSymbol); triggerHaptic.toggle() }
                    KeypadButton(text: "-", type: .operatorSymbol, color: operatorBg) { viewModel.insert("-", type: .operatorSymbol); triggerHaptic.toggle() }
                    KeypadButton(text: "+", type: .operatorSymbol, color: operatorBg) { viewModel.insert("+", type: .operatorSymbol); triggerHaptic.toggle() }
                }
                
                // Actions
                VStack(spacing: 8) {
                    KeypadButton(icon: "delete.left.fill", color: Color.red.opacity(0.15)) { viewModel.backspace(); triggerHaptic.toggle() }
                        .frame(height: 50)
                    
                    KeypadButton(text: "^", type: .operatorSymbol, color: operatorBg) { viewModel.insert("^", type: .operatorSymbol); triggerHaptic.toggle() }
                    
                    KeypadButton(text: "=", type: .operatorSymbol, color: actionBg) { viewModel.insert("=", type: .operatorSymbol); triggerHaptic.toggle() }
                    
                    KeypadButton(icon: "return", color: Color(red: 0.15, green: 0.80, blue: 0.50)) { viewModel.newLine(); triggerHaptic.toggle() }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(keypadBg)
        .clipShape(
            .rect(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        .sensoryFeedback(.selection, trigger: triggerHaptic)
    }
}

struct KeypadButton: View {
    var text: String? = nil
    var icon: String? = nil
    var type: TokenType = .number
    var color: Color
    var action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textColor)
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 24, weight: type == .operatorSymbol ? .bold : .medium, design: .rounded))
                        .italic(type == .variable)
                        .foregroundColor(textColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(KeypadButtonStyle())
    }
    
    private var textColor: Color {
        if color == Color.blue.opacity(0.15) { return .blue }
        if color == Color.orange.opacity(0.15) { return .orange }
        if color == Color.purple.opacity(0.15) { return .purple }
        if color == Color.red.opacity(0.15) { return .red }
        if color == Color(red: 0.15, green: 0.80, blue: 0.50) { return .white } // Return key
        return colorScheme == .dark ? .white : .primary
    }
}

struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
