//
//  MainTabView.swift
//  ProjectDelta
//

import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(TestSessionViewModel.self) var testViewModel
    @Environment(LessonViewModel.self) var lessonVM
    
    @State private var selectedTab = 0
    @State private var homeRefreshKey = UUID()
    @State private var cardRefreshKey = UUID()
    @State private var profileRefreshKey = UUID()
    @AppStorage("hideCustomTabBar") private var hideCustomTabBar: Bool = false
    
    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            // Native Custom Sidebar for macOS intercepting tap events
            VStack(alignment: .leading, spacing: 16) {
                Text("ProjectDelta")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 40)
                
                SidebarButton(icon: "house.fill", label: "Home", isSelected: selectedTab == 0) {
                    handleMacTabSelection(index: 0, refreshKey: $homeRefreshKey)
                }
                
                SidebarButton(icon: "pencil.line", label: "Assessments", isSelected: selectedTab == 1) {
                    handleMacTabSelection(index: 1, refreshKey: $cardRefreshKey)
                }
                
                SidebarButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == 2) {
                    handleMacTabSelection(index: 2, refreshKey: $profileRefreshKey)
                }
                Spacer()
            }
            .frame(width: 220)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content View
            ZStack {
                Color(NSColor.controlBackgroundColor).ignoresSafeArea()
                
                if selectedTab == 0 {
                    HomeView()
                        .id(homeRefreshKey)
                } else if selectedTab == 1 {
                    CardView()
                        .id(cardRefreshKey)
                } else if selectedTab == 2 {
                    ProfileView()
                        .id(profileRefreshKey)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all, edges: .top)
        #else
        ZStack(alignment: .bottom) {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
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
                
                TabBarButton(icon: "pencil.line", label: "Assessments", isSelected: selectedTab == 1) {
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
            .offset(y: hideCustomTabBar ? 150 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hideCustomTabBar)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // Explicitly reset the AppStorage value so the tab bar is never permanently hidden upon restart
            hideCustomTabBar = false
        }
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
            // Absolute reset trigger
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                refreshKey.wrappedValue = UUID()
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
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

#if os(macOS)
struct SidebarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .frame(width: 24)
                
                Text(label)
                    .font(.system(.body, design: .rounded, weight: isSelected ? .bold : .medium))
                
                Spacer()
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
