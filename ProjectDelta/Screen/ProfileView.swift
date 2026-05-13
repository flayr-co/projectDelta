//
//  ProfileView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/20/23.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showImagePicker = false
    @State private var showProfileDetail = false
    @State private var pickedImage: UIImage?
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationStack {
            if let user = viewModel.currentUser {
                List {
                    Section {
                        VStack(spacing: 16) {
                            Button {
                                showImagePicker = true
                            } label: {
                                if let urlString = user.profilePictureUrl, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Text(user.initials)
                                            .font(.largeTitle)
                                            .fontWeight(.semibold)
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                    }
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                                } else {
                                    Text(user.initials)
                                        .font(.largeTitle)
                                        .fontWeight(.semibold)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .frame(width: 120, height: 120)
                                        .background(Circle().fill(Color.gray.opacity(0.3)))
                                }
                            }
                            .padding(.top, 20)
                            .sheet(isPresented: $showImagePicker) {
                                PhotoPicker(image: $pickedImage)
                                    .onChange(of: pickedImage) { _, newImage in
                                        if let image = newImage {
                                            Task {
                                                await viewModel.uploadProfileImage(image, for: user)
                                            }
                                        }
                                    }
                            }
                            
                            Text(user.fullname)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text(user.email)
                                .font(.callout)
                                .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                            
                            // Role Badge for visual confirmation
                            Text(user.role.rawValue.uppercased())
                                .font(.caption2)
                                .fontWeight(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(user.role == .teacher ? Color.purple : Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear)
                    
                    // MARK: - Administrative Access
                    if user.role == .teacher {
                        Section("Administrative") {
                            NavigationLink {
                                AdminView()
                            } label: {
                                SettingsRowView(imageName: "lock.shield.fill",
                                                title: "Admin Panel",
                                                tintColor: .purple)
                            }
                        }
                    }
                    
                    Section("General") {
                        NavigationLink {
                            // About View
                        } label: {
                            SettingsRowView(imageName: "info.circle.fill",
                                            title: "About Vrtex",
                                            tintColor: Color.green)
                        }
                        
                        HStack {
                            SettingsRowView(imageName: "paintbrush.fill", title: "Theme", tintColor: .blue)
                            Toggle(isOn: $isDarkMode) {
                                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(isDarkMode ? .yellow : .orange)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                        }
                    }
                    
                    Section("Account") {
                        Button(action: {
                            showProfileDetail = true
                        }) {
                            SettingsRowView(imageName: "person.fill",
                                            title: "Profile Settings",
                                            tintColor: colorScheme == .dark ? Color.white : Color(.systemGray))
                        }
                        .sheet(isPresented: $showProfileDetail) {
                            ProfileViewDetail(isPresented: $showProfileDetail)
                                .environment(viewModel)
                        }
                        
                        NavigationLink {
                            QuizSnapshotsHistoryView()
                                .environment(viewModel)
                        } label: {
                            SettingsRowView(imageName: "chart.bar.xaxis", title: "View your progress", tintColor: .cyan)
                        }
                        
                        Button {
                            viewModel.signOut()
                        } label: {
                            SettingsRowView(imageName: "arrow.left.circle.fill",
                                            title: "Sign Out",
                                            tintColor: .red)
                        }
                    }
                }
            }
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    }
}

#Preview {
    let authViewModel = AuthViewModel()
    authViewModel.currentUser = User(fullname: "Mock User", email: "mock@example.com", role: .student)
    return ProfileView().environment(authViewModel)
}
