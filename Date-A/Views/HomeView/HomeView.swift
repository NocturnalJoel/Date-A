//  HomeView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: ContentModel
    @State private var matchedUser: User?
    @State private var showMatchAnimation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationBarView()
                    .environmentObject(model)
                
                MoonSliderView(selectedLevel: $model.moonSliderLevel)
                    .environmentObject(model)
                
                Spacer()
                
                ZStack {
                    if !model.profileStack.isEmpty {
                        ForEach(Array(model.profileStack.prefix(2).enumerated().reversed()), id: \.element.id) { index, user in
                            ProfileCardView(user: user)
                                .opacity(index == 0 ? 1 : 0.05)
                                .background(Color(.systemBackground))
                        }
                    } else {
                        if model.isLoadingProfiles {
                            ProfileCardPlaceholder()
                                .background(Color(.systemBackground))
                        } else if model.hasReachedEnd {
                            VStack(spacing: 16) {
                                Text("🌌")
                                    .font(.system(size: 150, weight: .bold))
                                Text("The Sky Is Empty Tonight")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                Text("Change your filters to see more profiles")
                                    .font(.subheadline)
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 5)
                            .padding()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .frame(height: 500)
                .onChange(of: model.profileStack.count) { count in
                    if count < 3 {
                        model.fetchMoreProfilesIfNeeded()
                    }
                }
                
                Spacer()
                
                ButtonsView(showMatchAnimation: $showMatchAnimation, matchedUser: $matchedUser)
                    .environmentObject(model)
            }
            .navigationBarHidden(true)
            .overlay(
                ZStack {
                    if showMatchAnimation, let matchedUser = matchedUser {
                        MatchAnimationView(isPresented: $showMatchAnimation, matchedUser: matchedUser)
                    }
                }
            )
            .onAppear {
                model.startFetchingProfiles()
                Task {
                    do {
                        await model.loadUnmatchedProfiles()
                        try await model.fetchMatches()
                    } catch {
                        print("Error fetching matches: \(error)")
                    }
                }
            }
        }
    }
}
