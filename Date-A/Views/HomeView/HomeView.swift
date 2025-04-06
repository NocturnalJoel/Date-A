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
                // Navigation Bar
                NavigationBarView()
                    .environmentObject(model)
                
                // Moon Level Slider
                MoonSliderView(selectedLevel: $model.currentMoonLevel)
                    .environmentObject(model)
                
                Spacer()
                
                // Main Content Area
                ZStack {
                    // 1. Loading State (Spinner/Shimmer)
                    if isLoading && model.profileStack.isEmpty {
                        ProfileCardPlaceholder()
                            .transition(.opacity)
                    }
                    
                    // 2. Profiles (if loaded and available)
                    else if !model.profileStack.isEmpty {
                        ForEach(Array(model.profileStack.enumerated()), id: \.element.id) { index, user in
                            ProfileCardView(user: user, stampType: $stampType)
                                .zIndex(Double(model.profileStack.count - index))
                                .opacity(index == 0 ? 1 : 0)
                                .id("\(user.id)_\(index)")
                        }
                    }
                    
                    // 3. Empty State (Only shown when no profiles exist)
                    else if model.hasReachedEndForCurrentLevel() {
                        VStack(spacing: 16) {
                            Text("🌌")
                                .font(.system(size: 150, weight: .bold))
                            Text("The Sky Is Empty Tonight")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isLoading)
                .frame(height: 500)
                
                Spacer()
                
                // Action Buttons (Hidden during loading)
                ButtonsView(
                    showMatchAnimation: $showMatchAnimation,
                    matchedUser: $matchedUser,
                    stampType: $stampType
                )
                .environmentObject(model)
                .opacity(isLoading ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: isLoading)
            }
            .navigationBarHidden(true)
            .overlay(
                // Match Animation Overlay
                ZStack {
                    if showMatchAnimation, let matchedUser = matchedUser {
                        MatchAnimationView(
                            isPresented: $showMatchAnimation,
                            matchedUser: matchedUser
                        )
                    }
                }
            )
            .onAppear {
                Task {
                    isLoading = true
                    try await model.fetchMatches()
                    isLoading = false
                }
            }
            
        }
    }
}
