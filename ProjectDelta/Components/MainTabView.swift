//
//  MainTabView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(LessonViewModel.self) var lessonVM
    
    @State private var selectedTab = 0
    @State private var homeRefreshKey = UUID()
    @State private var cardRefreshKey = UUID()
    @State private var profileRefreshKey = UUID()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0: HomeView().id(homeRefreshKey)
                case 1: CardView().id(cardRefreshKey)
                case 2: ProfileView().id(profileRefreshKey)
                default: Text("Selection does not exist")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                TabBarButton(icon: "house.fill", label: "Home", isSelected: selectedTab == 0) {
                    handleTabSelection(index: 0, refreshKey: &homeRefreshKey)
                }
                
                TabBarButton(icon: "pencil.line", label: "Practice", isSelected: selectedTab == 1) {
                    handleTabSelection(index: 1, refreshKey: &cardRefreshKey)
                }
                
                TabBarButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == 2) {
                    handleTabSelection(index: 2, refreshKey: &profileRefreshKey)
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private func handleTabSelection(index: Int, refreshKey: inout UUID) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if selectedTab == index {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                refreshKey = UUID()
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .gray)
                    .frame(height: 26)
                
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .accentColor : .gray)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
