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
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Your Matches")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 20)
                
                if model.matches.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                        
                        Text("No matches yet")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text("Keep swiping to find your perfect match!")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(model.matches) { match in
                            NavigationLink(destination: ChatView(
                                matchedUser: match,
                                matchId: [Auth.auth().currentUser?.uid ?? "", match.id].sorted().joined(separator: "_")
                            )) {
                                MatchCard(match: match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        
    }
}

// Extracted match card component for better organization
struct MatchCard: View {
    let match: User
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            if let imageURL = match.pictureURLs.first {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.1)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Name and Age
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(match.firstName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("\(match.age)")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                // Message prompt
                Text("Tap to start chatting")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Chat indicator
            Image(systemName: "bubble.right.fill")
                .foregroundColor(.black)
                .font(.system(size: 20, weight: .medium))
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}
