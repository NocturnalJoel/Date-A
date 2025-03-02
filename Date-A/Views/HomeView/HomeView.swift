

import SwiftUI
struct HomeView: View {
    @EnvironmentObject var model: ContentModel
    @State private var matchedUser: User?
    @State private var showMatchAnimation = false
    @State private var stampType: StampType?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationBarView()
                    .environmentObject(model)
                
                MoonSliderView(selectedLevel: $model.currentMoonLevel)
                    .environmentObject(model)
                
                Spacer()
                
                ZStack {
                    // Always show shimmer while loading
                    if isLoading {
                        ProfileCardPlaceholder()
                            .transition(.opacity)
                    }
                    
                    // Show profiles when loaded and available
                    if !isLoading && model.checkProfileVisibility() {
                        ForEach(Array(model.profileStack.prefix(2).enumerated().reversed()), id: \.element.id) { index, user in
                            ProfileCardView(user: user, stampType: $stampType)
                                .opacity(index == 0 ? 1 : 0.05)
                                .background(Color(.systemBackground))
                                .id("\(user.id)_\(index)")
                                .transition(.opacity)
                        }
                    }
                    
                    // Show empty state when loaded but no profiles
                    if !isLoading && model.hasReachedEndForCurrentLevel() {
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
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isLoading)
                .frame(height: 500)
                
                Spacer()
                
                ButtonsView(showMatchAnimation: $showMatchAnimation,
                           matchedUser: $matchedUser,
                           stampType: $stampType)
                    .environmentObject(model)
                    .opacity(isLoading ? 0 : 1) // Hide buttons while loading
                    .animation(.easeInOut(duration: 0.3), value: isLoading)
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
                isLoading = true
                
                Task {
                    do {
                        // Start all async operations concurrently
                        async let refreshUser = try model.refreshCurrentUser()
                        async let initializeStacks = model.initializeStacks()
                        async let fetchMatches = try model.fetchMatches()
                        async let loadUnmatched = model.loadUnmatchedProfiles()
                        
                        // Wait for all operations to complete
                        _ = try await (refreshUser, initializeStacks, fetchMatches, loadUnmatched)
                        
                        // Update UI state
                        await MainActor.run {
                            isLoading = false
                        }
                    } catch {
                        // Handle any errors that occur during the async operations
                        await MainActor.run {
                            isLoading = false
                            model.errorMessage = "Failed to load data. Please try again."
                            print("Error loading data: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
