//
//  ProfileView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/20/23.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showImagePicker = false
    @State private var showProfileDetail = false
    @State private var pickedImage: UIImage?
    @AppStorage("isDarkMode") private var isDarkMode = false // AppStorage to save theme preference
    
    var body: some View {
        NavigationStack {
            if let user = viewModel.currentUser {
                List {
                    Section {
                        VStack(spacing: 16) {
                            Button {
                                showImagePicker = true
                            } label: {
                                // Profile picture or initials
                                if let urlString = user.profilePictureUrl, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Text(user.initials)
                                            .font(.largeTitle)
                                            .fontWeight(.semibold)
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                    }
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                                } else {
                                    Text(user.initials)
                                        .font(.largeTitle)
                                        .fontWeight(.semibold)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .frame(width: 120, height: 120)
                                        .background(Circle().fill(Color.gray))
                                }
                            }
                            .padding(.top, 50)
                            .sheet(isPresented: $showImagePicker) {
                                PhotoPicker(image: $pickedImage)
                                    .onChange(of: pickedImage) { newImage in
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
                        } //: VSTACK
                        .frame(maxWidth: .infinity)
                    } //: SECTION 1
                    
                    Section("General") {
                        NavigationLink {
                            
                        } label: {
                            SettingsRowView(imageName: "plus",
                                            title: "About Vrtex",
                                            tintColor: Color.green)
                        }
                        
                        HStack {
                            SettingsRowView(imageName: "paintbrush", title: "Theme", tintColor: .blue)
                            
                            // Toggle for Dark Mode and Light Mode
                            Toggle(isOn: $isDarkMode) {
                                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(isDarkMode ? .yellow : .orange)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                        }
                    } //: SECTION 2
                    
                    Section("Account") {
                        Button(action: {
                            showProfileDetail = true
                        }) {
                            SettingsRowView(imageName: "person",
                                            title: "Profile",
                                            tintColor: colorScheme == .dark ? Color.white : Color(.systemGray))
                        }
                        .sheet(isPresented: $showProfileDetail) {
                            ProfileViewDetail(isPresented: $showProfileDetail)
                                .environmentObject(viewModel)
                        }
                        
                        NavigationLink {
                            UserStatsView()
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            SettingsRowView(imageName: "chart.bar.xaxis", title: "View your progress", tintColor: .cyan)
                        }
                        .navigationBarBackButtonHidden(true)
                        
                        Button {
                            viewModel.signOut()
                        } label: {
                            SettingsRowView(imageName: "arrow.left.circle.fill",
                                            title: "Sign Out",
                                            tintColor: .red)
                        }
                    } //: SECTION 3
                }
            }
        } //: NAVIGATIONSTACK
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    }
}

#Preview {
    let authViewModel = AuthViewModel()
    authViewModel.currentUser = User.MOCK_USERS.first
    
    return ProfileView()
        .environmentObject(authViewModel)
//        .preferredColorScheme(.dark)
}



