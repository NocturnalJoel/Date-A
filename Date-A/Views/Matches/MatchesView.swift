//
//  MatchesView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//

import SwiftUI
import FirebaseAuth

struct MatchesView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var model: ContentModel
    @State private var isLoading = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    Text("Matches")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 20)
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if model.matches.isEmpty {
                    Text("No matches yet")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        ForEach(model.matches) { match in
                            NavigationLink(destination: ChatView(
                                matchedUser: match,
                                matchId: [Auth.auth().currentUser?.uid ?? "", match.id].sorted().joined(separator: "_")
                            )) {
                                HStack(spacing: 16) {
                                    // Profile Image
                                    if let imageURL = match.pictureURLs.first {
                                        AsyncImage(url: URL(string: imageURL)) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Color.gray.opacity(0.1)
                                        }
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                    
                                    // Name and Age
                                    Text(match.firstName)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.black) +
                                    Text(", \(match.age)")
                                        .font(.system(size: 20, weight: .regular, design: .rounded))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(16)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        .task {
            isLoading = true
            try? await model.fetchMatches()
            isLoading = false
        }
    }
}
