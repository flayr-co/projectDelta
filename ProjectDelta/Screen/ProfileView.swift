//
//  ProfileView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/20/23.
//

// ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    
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
                                PhotoPicker(selectedImage: $pickedImage) { image in
                                    viewModel.uploadProfileImage(image, for: user)
                                }
                            }
                            
                            Text(user.fullname)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text(user.email)
                                .font(.callout)
                                .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                        } //:VSTACK
                        .frame(maxWidth: .infinity)
                    } //: SECTION 1
                    
                    Section("General") {
                        HStack {
                            SettingsRowView(imageName: "gear",
                                            title: "Version",
                                            tintColor: colorScheme == .dark ? Color.white : Color(.systemGray))
                            
                            Spacer()
                            
                            Text("1.0.0")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        }
                    } //: SECTION 2
                    
                    Section("Account") {
                        Button {
                            viewModel.signOut()
                        } label: {
                            SettingsRowView(imageName: "arrow.left.circle.fill",
                                            title: "Sign Out",
                                            tintColor: .red)
                        }
                        
                        NavigationLink {
                            UserStatsView()
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            SettingsRowView(imageName: "chart.bar.xaxis", title: "View your progress", tintColor: .cyan)
                        }
                        .navigationBarBackButtonHidden(true)
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
