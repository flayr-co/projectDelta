//
//  KeypadTab.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/4/26.
//


//
//  MathKeypadView.swift
//  ProjectDelta
//

import SwiftUI

#if os(macOS)
enum KeypadTab: String, CaseIterable {
    case num = "123"
    case fn = "ƒ(x)"
    case sym = "αβγ"
}

struct MathKeypadView: View {
    @Binding var text: String
    var onHighlight: () -> Void
    @State private var currentTab: KeypadTab = .num
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $currentTab) {
                ForEach(KeypadTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            
            LazyVGrid(columns: columns, spacing: 10) {
                switch currentTab {
                case .num:
                    keyButton("7", display: "7")
                    keyButton("8", display: "8")
                    keyButton("9", display: "9")
                    keyButton("\\div", display: "÷", color: Color.teal.opacity(0.15))
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color.red.opacity(0.15), textColor: .red)
                    
                    keyButton("4", display: "4")
                    keyButton("5", display: "5")
                    keyButton("6", display: "6")
                    keyButton("\\times", display: "×", color: Color.teal.opacity(0.15))
                    keyButton("\\frac{ }{ }", display: "a/b", color: Color.teal.opacity(0.15))
                    
                    keyButton("1", display: "1")
                    keyButton("2", display: "2")
                    keyButton("3", display: "3")
                    keyButton("-", display: "-", color: Color.teal.opacity(0.15))
                    keyButton("^{2}", display: "x²", color: Color.teal.opacity(0.15))
                    
                    keyButton("0", display: "0")
                    keyButton(".", display: ".")
                    keyButton("=", display: "=", color: Color.teal.opacity(0.15))
                    keyButton("+", display: "+", color: Color.teal.opacity(0.15))
                    keyButton("^{ }", display: "xⁿ", color: Color.teal.opacity(0.15))
                    
                case .fn:
                    keyButton("\\sin()", display: "sin")
                    keyButton("\\cos()", display: "cos")
                    keyButton("\\tan()", display: "tan")
                    keyButton("\\ln()", display: "ln")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color.red.opacity(0.15), textColor: .red)
                    
                    keyButton("\\csc()", display: "csc")
                    keyButton("\\sec()", display: "sec")
                    keyButton("\\cot()", display: "cot")
                    keyButton("\\log_{10}()", display: "log")
                    keyButton("\\sqrt{ }", display: "√", color: Color.teal.opacity(0.15))
                    
                    keyButton("x", display: "x", color: Color.teal.opacity(0.15))
                    keyButton("y", display: "y", color: Color.teal.opacity(0.15))
                    keyButton("e^{}", display: "eⁿ", color: Color.teal.opacity(0.15))
                    keyButton("(", display: "(", color: Color.teal.opacity(0.15))
                    keyButton(")", display: ")", color: Color.teal.opacity(0.15))
                    
                    keyButton("a", display: "a", color: Color.teal.opacity(0.15))
                    keyButton("b", display: "b", color: Color.teal.opacity(0.15))
                    keyButton("c", display: "c", color: Color.teal.opacity(0.15))
                    keyButton("[", display: "[", color: Color.teal.opacity(0.15))
                    keyButton("]", display: "]", color: Color.teal.opacity(0.15))
                    
                case .sym:
                    keyButton("\\pi", display: "π")
                    keyButton("\\theta", display: "θ")
                    keyButton("\\alpha", display: "α")
                    keyButton("\\beta", display: "β")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color.red.opacity(0.15), textColor: .red)
                    
                    keyButton("\\leq", display: "≤")
                    keyButton("\\geq", display: "≥")
                    keyButton("\\neq", display: "≠")
                    keyButton("\\approx", display: "≈")
                    keyButton("\\pm", display: "±", color: Color.teal.opacity(0.15))
                    
                    keyButton("\\int", display: "∫")
                    keyButton("\\sum", display: "∑")
                    keyButton("\\infty", display: "∞")
                    keyButton("^{\\circ}", display: "°")
                    
                    Button(action: onHighlight) {
                        Text("HL")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.teal.opacity(0.15))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 2)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    
                    keyButton("\\{", display: "{", color: Color.teal.opacity(0.15))
                    keyButton("\\}", display: "}", color: Color.teal.opacity(0.15))
                    keyButton("<", display: "<", color: Color.teal.opacity(0.15))
                    keyButton(">", display: ">", color: Color.teal.opacity(0.15))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color.teal.opacity(0.15))
                }
            }
        }
        .padding(16)
        .background(Color.platformSecondarySystemGroupedBackground)
        .cornerRadius(16)
    }
    
    private func backspace() {
        if !text.isEmpty { text.removeLast() }
    }
    
    @ViewBuilder
    private func keyButton(_ insertString: String, display: String, color: Color = Color.platformSystemBackground) -> some View {
        Button(action: { text.append(insertString) }) {
            Text(display)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(color)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 2)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func actionButton(systemName: String, action: @escaping () -> Void, color: Color, textColor: Color = .primary) -> some View {
        Button(action: action) {
            Image(systemName: nameForSystem(systemName))
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(color)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 2)
                .foregroundColor(textColor)
        }
        .buttonStyle(.plain)
    }
    
    private func nameForSystem(_ name: String) -> String {
        return name == "space" ? "spacebar" : name
    }
}
#endif