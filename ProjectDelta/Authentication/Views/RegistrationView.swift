//
//  RegistrationView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/20/23.
//

import SwiftUI

struct RegistrationView: View {
    // MARK: - PROPERTIES
    @State private var email = ""
    @State private var fullname = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        // MARK: - IMAGE
        
        Image("Delta")
            .resizable()
            .scaledToFill()
            .frame(width: 100, height: 120)
            .padding(.vertical, 32)
        
        // MARK: - FORM FIELDS
        
        VStack(spacing: 24) {
            InputView(text: $email,
                      title: "Email Address",
                      placeholder: "name@example.com")
                .autocapitalization(.none)
            
            InputView(text: $fullname,
                      title: "Full Name",
                      placeholder: "Enter your name")
            
            InputView(text: $password,
                      title: "Password",
                      placeholder: "Enter your password",
                      isSecureField: true)
            
            ZStack(alignment: .trailing) {
                InputView(text: $confirmPassword,
                          title: "Confirm Password",
                          placeholder: "Confirm your password",
                          isSecureField: true)
                
                if !password.isEmpty && !confirmPassword.isEmpty {
                    if password == confirmPassword {
                        Image(systemName: "checkmark.circle.fill")
                            .imageScale(.large)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.systemGreen))
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.large)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.systemRed))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        
        // MARK: - SIGN UP BUTTON
        
        Button {
            Task {
                try await viewModel.createUser(withEmail: email, password: password, fullname: fullname)
            }
        } label: {
            HStack {
                Text("SIGN UP")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .foregroundColor(.white)
            .frame(width: UIScreen.main.bounds.width - 32, height: 48)
        }
        .background(Color.blue)
        .disabled(!formIsValid)
        .opacity(formIsValid ? 1.0 : 0.5)
        .cornerRadius(10)
        .padding(.top, 24)
        
        Spacer()
        
        // MARK: - LOG IN BUTTON
        
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Text("Already have an account?")
                Text("Log In")
                    .fontWeight(.bold)
            }
            .font(.system(size: 16))
        }
    }
}

// MARK: - AuthenticationFormProtocol

extension RegistrationView: AuthenticationFormProtocol {
    var formIsValid: Bool {
        return !email.isEmpty
        && email.contains("@")
        && !password.isEmpty
        && password.count > 5
        && confirmPassword == password
        && !fullname.isEmpty
    }
}

#Preview {
    RegistrationView()
        .environmentObject(AuthViewModel())
}
