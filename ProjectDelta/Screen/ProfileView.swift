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
                Group {
                    #if os(macOS)
                    macOSProfileLayout(for: user)
                    #else
                    iOSProfileLayout(for: user)
                    #endif
                }
                .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
            }
        }
    }
    
    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private func macOSProfileLayout(for user: User) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                // Header Profile Card
                HStack(spacing: 32) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        profileImageContent(for: user)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhotoItem) { oldValue, newValue in
                        handleImageSelection(newValue: newValue, user: user)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(user.fullname)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(user.email)
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(user.role.rawValue.uppercased())
                            .font(.system(.caption, design: .rounded, weight: .black))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(user.role == .teacher ? Color.purple : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .padding(.top, 4)
                    }
                    Spacer()
                }
                .padding(40)
                .background(Color.platformSystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))

                // Settings Grid
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 32, alignment: .top), GridItem(.flexible(), spacing: 32, alignment: .top)], spacing: 32) {
                    
                    if user.role == .teacher {
                        macOSSectionCard(title: "Administrative") {
                            NavigationLink {
                                AdminView()
                            } label: {
                                macOSSettingRow(icon: "lock.shield.fill", title: "Admin Panel", color: .purple)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    macOSSectionCard(title: "General") {
                        NavigationLink {
                            // About View
                        } label: {
                            macOSSettingRow(icon: "info.circle.fill", title: "About Vrtex", color: .green)
                        }
                        .buttonStyle(.plain)
                        
                        Divider().opacity(0.5)
                        
                        HStack {
                            macOSSettingRow(icon: "paintbrush.fill", title: "Theme", color: .blue)
                            Spacer()
                            Toggle("", isOn: $isDarkMode)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .labelsHidden()
                        }
                    }
                    
                    macOSSectionCard(title: "Account") {
                        Button {
                            showProfileDetail = true
                        } label: {
                            macOSSettingRow(icon: "person.fill", title: "Profile Settings", color: colorScheme == .dark ? .white : .gray)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showProfileDetail) {
                            ProfileViewDetail(isPresented: $showProfileDetail)
                                .environment(viewModel)
                        }
                        
                        Divider().opacity(0.5)
                        
                        NavigationLink {
                            QuizSnapshotsHistoryView()
                                .environment(viewModel)
                        } label: {
                            macOSSettingRow(icon: "chart.bar.xaxis", title: "View your progress", color: .cyan)
                        }
                        .buttonStyle(.plain)
                        
                        Divider().opacity(0.5)
                        
                        Button {
                            viewModel.signOut()
                        } label: {
                            macOSSettingRow(icon: "arrow.left.circle.fill", title: "Sign Out", color: .red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 1000) // Constrain width for ultrawide
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.platformSystemGroupedBackground)
    }
    
    private func macOSSectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                content()
            }
            .padding(24)
            .background(Color.platformSystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        }
    }

    private func macOSSettingRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Text(title)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if title != "Theme" {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private func iOSProfileLayout(for user: User) -> some View {
        List {
            Section {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        profileImageContent(for: user)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    .onChange(of: selectedPhotoItem) { oldValue, newValue in
                        handleImageSelection(newValue: newValue, user: user)
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
        .padding(.bottom, 100) // Padding to clear floating tab bar only on mobile where tabbar exists
    }
    #endif
    
    // MARK: - SHARED LOGIC & SUBVIEWS
    private func handleImageSelection(newValue: PhotosPickerItem?, user: User) {
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
