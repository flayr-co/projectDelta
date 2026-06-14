//
//  ProfileView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/20/23.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showProfileDetail = false
    
    // Native PhotosUI integration replaces UIKit wrappers
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessingImage = false
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationStack {
            if let user = viewModel.currentUser {
                List {
                    Section {
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                profileImageContent(for: user)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 20)
                            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                                Task {
                                    if let item = newValue {
                                        isProcessingImage = true
                                        // Retrieve raw data to remain completely abstracted from UIKit/AppKit
                                        if let imageData = try? await item.loadTransferable(type: Data.self) {
                                            await viewModel.uploadProfileImage(imageData, for: user)
                                        }
                                        isProcessingImage = false
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
                                            tintColor: colorScheme == .dark ? Color.white : Color(.gray))
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
                #if os(iOS)
                .padding(.bottom, 100) // Padding to clear floating tab bar only on mobile where tabbar exists
                #endif
            }
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func profileImageContent(for user: User) -> some View {
        if isProcessingImage {
            ProgressView()
                .frame(width: 120, height: 120)
                .background(Circle().fill(Color.gray.opacity(0.3)))
        } else if let urlString = user.profilePictureUrl, let url = URL(string: urlString) {
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
}
