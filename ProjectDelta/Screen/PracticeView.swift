//
//  PracticeView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI

struct PracticeView: View {
    @State private var user: GitHubUser?
    
    var body: some View {
        VStack(spacing: 20) {
            
            AsyncImage(url: URL(string: user?.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, height: 120)
            
            Text(user?.login ?? "Login placeholder")
                .bold()
                .font(.title3)
            
            Text(user?.bio ?? "Bio placeholder")
                .padding()
            
            Spacer()
        }
        .padding()
        .task {
            do {
                user = try await getUser()
            } catch GHError.invalidURL {
                print("invalid URL")
            } catch GHError.invalidResponse {
                print("invalid response")
            } catch GHError.invalidData {
                print("invalid data")
            } catch {
                print("unexpected error")
            }
        }
    }
    
    // IN THIS FUNCTION, WE RETURN THE GITHUB USER OBJECT
    // Async throws is an asynchronous function that throws an error if needed
    
    func getUser() async throws -> GitHubUser {
        let endpoint = "https://api.github.com/users/jakecmeissner"
        
        guard let url = URL(string: endpoint) else {
            throw GHError.invalidURL
        }
        
        // GET REQUEST USING URL DATA
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw GHError.invalidResponse
        }
        
        // DECODING PROCESS FROM THE DATA ON SERVER
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(GitHubUser.self, from: data)
        } catch {
            throw GHError.invalidData
        }
    }
}

#Preview {
    PracticeView()
}

// WOULD BE IN MODEL FOLDER NORMALLY
struct GitHubUser: Codable {
    let login: String
    let avatarUrl: String
    let bio: String
}

enum GHError: Error {
    case invalidURL
    case invalidResponse
    case invalidData
}
