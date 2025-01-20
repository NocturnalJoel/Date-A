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
    @State private var stampType: StampType?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationBarView()
                    .environmentObject(model)
                
                MoonSliderView(selectedLevel: $model.currentMoonLevel)
                    .environmentObject(model)
                
                Spacer()
                
                ZStack {
                    if !model.checkProfileVisibility() {
                        if model.hasReachedEndForCurrentLevel() {
                            // Empty state view
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
                        } else {
                            // Loading placeholder
                            ProfileCardPlaceholder()
                                .background(Color(.systemBackground))
                        }
                    } else {
                        // Show profiles
                        ForEach(Array(model.profileStack.prefix(2).enumerated().reversed()), id: \.element.id) { index, user in
                            ProfileCardView(user: user, stampType: $stampType)
                                .opacity(index == 0 ? 1 : 0.05)
                                .background(Color(.systemBackground))
                                .id("\(user.id)_\(index)")
                        }
                    }
                }
                .background(Color(.systemBackground))
                .frame(height: 500)
                
                Spacer()
                
                ButtonsView(showMatchAnimation: $showMatchAnimation,
                          matchedUser: $matchedUser,
                          stampType: $stampType)
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
                Task {
                    
                    try? await model.refreshCurrentUser()
                    model.initializeStacks()  // This now loads all stacks at once
                    try? await model.fetchMatches()
                    await model.loadUnmatchedProfiles()
                }
            }
        }
    }
}
