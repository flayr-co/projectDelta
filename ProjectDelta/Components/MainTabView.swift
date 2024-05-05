//
//  MainTabView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @EnvironmentObject var quizViewModel: QuizViewModel
    @EnvironmentObject var lessonVM: LessonViewModel
    @State private var selectedTab = 0
    @State private var homeRefreshKey = UUID()
    @State private var cardRefreshKey = UUID()
    @State private var profileRefreshKey = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // Content views for the tabs
            Group {
                switch selectedTab {
                case 0:
                    HomeView().id(homeRefreshKey)
                case 1:
                    CardView().id(cardRefreshKey)
                case 2:
                    ProfileView().id(profileRefreshKey)
                default:
                    Text("Selection does not exist")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Custom tab bar
            HStack {
                TabBarButton(icon: "house.fill", label: "Home", isSelected: selectedTab == 0) {
                    if selectedTab == 0 {
                        homeRefreshKey = UUID()
                    } else {
                        selectedTab = 0
                    }
                }
                
                TabBarButton(icon: "pencil.line", label: "Practice", isSelected: selectedTab == 1) {
                    if selectedTab == 1 {
                        cardRefreshKey = UUID()
                    } else {
                        selectedTab = 1
                    }
                }
                
                TabBarButton(icon: "person", label: "Profile", isSelected: selectedTab == 2) {
                    if selectedTab == 2 {
                        profileRefreshKey = UUID()
                    } else {
                        selectedTab = 2
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 30)
            .background(Color(UIColor.systemBackground).shadow(radius: 2))
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .gray)
                Text(label)
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}



#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
        .environmentObject(LessonViewModel(subjectName: "Geometry"))
}
