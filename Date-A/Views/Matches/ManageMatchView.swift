import SwiftUI
import FirebaseAuth
import FirebaseFirestore

import SwiftUI
import FirebaseFirestore

struct ManageMatchView: View {
    @EnvironmentObject var model: ContentModel
    @Environment(\.dismiss) var dismiss
    @Binding var shouldPopToRoot: Bool
    
    let matchId: String
    
    @State private var hasSocialRequest: Bool = false
    @State private var hasDateRequest: Bool = false
    @State private var showingRatingPopup = false
    
    private var exchangeSocialsOpacity: Double {
        hasSocialRequest ? 0.6 : 1.0
    }
    
    private var goOnDateOpacity: Double {
        hasDateRequest ? 0.6 : 1.0
    }
    
    @State private var unmatchOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Manage Match")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            
            Text("Tap on one of these buttons if you're ready. If they do the same for you, you will both be notified.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundStyle(.gray)
            
            Button {
                withAnimation {
                    hasSocialRequest = true
                    Task {
                        try? await model.updateMatchSocialRequest(matchId: matchId)
                    }
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(Color.blue.opacity(exchangeSocialsOpacity))
                        .frame(width: 250, height: 60)
                    Text("Exchange Socials")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            
            Button {
                withAnimation {
                    hasDateRequest = true
                    Task {
                        try? await model.updateMatchDateRequest(matchId: matchId)
                    }
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(Color.red.opacity(goOnDateOpacity))
                        .frame(width: 250, height: 60)
                    Text("Go on a Date")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            
            Text("At any time, you can unilaterally unmatch.")
                .padding(.top)
                .foregroundStyle(.gray)
            
            Button {
                withAnimation {
                    unmatchOpacity = 0.6
                    showingRatingPopup = true
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(Color.gray.opacity(unmatchOpacity))
                        .frame(width: 250, height: 60)
                    Text("Unmatch")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .onAppear {
            fetchCurrentState()
        }
        .overlay {
            if showingRatingPopup {
                RatingPopupView(
                    isPresented: $showingRatingPopup,
                    matchId: matchId
                ) { rating in
                    Task {
                        try? await model.unmatchAndRate(matchId: matchId, rating: rating)
                        dismiss()
                        shouldPopToRoot = true
                    }
                }
            }
        }
    }
    
    private func fetchCurrentState() {
        Task {
            do {
                let state = try await model.fetchMatchState(matchId: matchId)
                await MainActor.run {
                    hasSocialRequest = state.hasSocialRequest
                    hasDateRequest = state.hasDateRequest
                }
            } catch {
                print("Error fetching match state: \(error)")
            }
        }
    }
}
