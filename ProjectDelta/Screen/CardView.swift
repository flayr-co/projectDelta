//
//  CardView.swift
//  ProjectDelta
//

import SwiftUI

struct CardView: View {
    @Environment(TestSessionViewModel.self) var testViewModel
    @Environment(\.colorScheme) var colorScheme
    
    let warmTan = Color(red: 0.97, green: 0.96, blue: 0.94)
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.12) : warmTan)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Area
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assessments")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.5)
                        
                        Text("Testing Hub")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            NavigationLink(destination: SubjectGridView(navigationSource: .quickTest).navigationBarBackButtonHidden(true)) {
                                assessmentCard(
                                    title: "Quick Test",
                                    description: "Jump straight into a 10-question randomized test for a subject.",
                                    icon: "bolt.fill",
                                    color: .orange
                                )
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(destination: SubjectGridView(navigationSource: .timedExam).navigationBarBackButtonHidden(true)) {
                                assessmentCard(
                                    title: "Timed Exam",
                                    description: "Take a focused, timed assessment with a dedicated interface.",
                                    icon: "timer",
                                    color: .red
                                )
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(destination: SubjectGridView(navigationSource: .practice).navigationBarBackButtonHidden(true)) {
                                assessmentCard(
                                    title: "Lesson Practice",
                                    description: "Focus your testing on a specific lesson and subtopic.",
                                    icon: "book.pages.fill",
                                    color: .cyan
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                #if os(macOS)
                .frame(maxWidth: 800)
                #endif
            }
        }
    }
    
    @ViewBuilder
    private func assessmentCard(title: String, description: String, icon: String, color: Color) -> some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.system(size: 14, weight: .bold))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.19) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 10, x: 0, y: 5)
    }
}
