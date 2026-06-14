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
        #if os(macOS)
        // Native TabView for macOS desktop UX
        TabView(selection: $selectedTab) {
            HomeView()
                .id(homeRefreshKey)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            CardView()
                .id(cardRefreshKey)
                .tabItem { Label("Practice", systemImage: "pencil.line") }
                .tag(1)
            
            ProfileView()
                .id(profileRefreshKey)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            handleMacTabSelection(index: newValue, refreshKey: getRefreshKey(for: newValue))
        }
        #else
        ZStack(alignment: .bottom) {
            // Cross-platform dynamic background color resolution
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            // Native TabView preserves view state automatically instead of destroying inactive views
            TabView(selection: $selectedTab) {
                HomeView()
                    .id(homeRefreshKey)
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaPadding(.bottom, 100)
                
                CardView()
                    .id(cardRefreshKey)
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaPadding(.bottom, 100)
                
                ProfileView()
                    .id(profileRefreshKey)
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaPadding(.bottom, 100)
            }
            
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
        #endif
    }
    
    #if os(iOS)
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
    #endif
    
    #if os(macOS)
    private func handleMacTabSelection(index: Int, refreshKey: Binding<UUID>) {
        if selectedTab == index {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                refreshKey.wrappedValue = UUID()
            }
        }
    }
    
    private func getRefreshKey(for index: Int) -> Binding<UUID> {
        switch index {
        case 0: return $homeRefreshKey
        case 1: return $cardRefreshKey
        default: return $profileRefreshKey
        }
    }
    #endif
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
