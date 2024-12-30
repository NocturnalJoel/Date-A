//
//  MatchesView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MatchesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ContentModel
    
    @State private var showingRatingPopup = false
    @State private var selectedUnmatchId: String?
    
    
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
                                MatchCard(
                                    match: match,
                                    matchId: [Auth.auth().currentUser?.uid ?? "", match.id].sorted().joined(separator: "_")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !model.unmatchedProfiles.isEmpty {
                                    UnmatchesSection(showingRatingPopup: $showingRatingPopup,
                                                     selectedUnmatchId: $selectedUnmatchId)
                                        .environmentObject(model)
                                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            
        }
        .navigationBarHidden(true)
        .overlay {
                    // Move the overlay here
                    if showingRatingPopup, let unmatchId = selectedUnmatchId {
                        RatingPopupView(
                            isPresented: $showingRatingPopup,
                            matchId: ""
                        ) { rating in
                            Task {
                                try? await model.rateUnmatchedUser(unmatchedUserId: unmatchId, rating: rating)
                                await model.loadUnmatchedProfiles()
                            }
                        }
                    }
                }
        
    }
    
    
}

// Extracted match card component for better organization
struct MatchCard: View {
    let match: User
    let matchId: String
    @State private var hasNewActivity: Bool = false
    @State private var isNewMatch: Bool = false
    
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
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(
                            hasNewActivity ? Color.red :
                            isNewMatch ? Color.green : .clear,
                            lineWidth: 7
                        )
                )
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
        .task {
            // Check activity status
            do {
                        let matchDoc = try await Firestore.firestore()
                            .collection("matches")
                            .document(matchId)
                            .getDocument()
                        
                        if let data = matchDoc.data(),
                           let viewed = data["viewed"] as? [String: Timestamp?],
                           let lastActivity = data["lastActivity"] as? Timestamp {
                            
                            let currentUserId = Auth.auth().currentUser?.uid ?? ""
                            
                            // Fixed optional handling
                            let lastViewedDate: Date
                            if let viewedTimestamp = viewed[currentUserId] ?? nil {
                                lastViewedDate = viewedTimestamp.dateValue()
                            } else {
                                lastViewedDate = Date(timeIntervalSince1970: 0)
                            }
                            
                            // If never viewed, it's a new match
                            isNewMatch = lastViewedDate == Date(timeIntervalSince1970: 0)
                            
                            // If there's activity after last view, show red circle
                            hasNewActivity = !isNewMatch && lastActivity.dateValue() > lastViewedDate
                        }
                    } catch {
                print("Error fetching match status: \(error)")
            }
        }
    }
}

struct UnmatchesSection: View {
    @EnvironmentObject var model: ContentModel
    @Binding var showingRatingPopup: Bool
    @Binding var selectedUnmatchId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rate your Unmatches")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(model.unmatchedProfiles, id: \.id) { profile in
                        VStack {
                            AsyncImage(url: URL(string: profile.imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            
                            Text(profile.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            selectedUnmatchId = profile.id
                            showingRatingPopup = true
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        
    }
}
