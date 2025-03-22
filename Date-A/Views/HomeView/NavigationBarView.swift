import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct NavigationBarView: View {
    @EnvironmentObject var model: ContentModel
    @State private var showingSettings = false
    @State private var showingMatches = false
    @State private var hasMatchActivity = false
    
    var body: some View {
        HStack {
            // Settings Button
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // App Logo
            Text("DATE-A")
                .font(.system(size: 34, weight: .heavy))
                .tracking(-1.5)
                .kerning(-0.8)
                .scaleEffect(x: 1.1, y: 1.0)
            
            Spacer()
            
            // Matches Button with notification indicator
            Button {
                showingMatches = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                    
                    if hasMatchActivity {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        .navigationDestination(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(model)
        }
        .navigationDestination(isPresented: $showingMatches) {
            MatchesView()
                .environmentObject(model)
        }
        .task {
            await checkMatchActivity()
        }
    }
    
    private func checkMatchActivity() async {
        // Check all matches for activity
        for match in model.matches {
            let matchId = [Auth.auth().currentUser?.uid ?? "", match.id].sorted().joined(separator: "_")
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
                    let isNewMatch = lastViewedDate == Date(timeIntervalSince1970: 0)
                    
                    // Check if there's activity after last view
                    if !isNewMatch && lastActivity.dateValue() > lastViewedDate {
                        // Fetch the most recent message from the messages subcollection
                        let messagesQuery = try await Firestore.firestore()
                            .collection("matches")
                            .document(matchId)
                            .collection("messages")
                            .order(by: "timestamp", descending: true)
                            .limit(to: 1)
                            .getDocuments()
                        
                        if let mostRecentMessage = messagesQuery.documents.first,
                           let senderId = mostRecentMessage.data()["senderId"] as? String {
                            // Only set hasMatchActivity to true if the most recent message was NOT sent by the current user
                            hasMatchActivity = senderId != currentUserId
                            if hasMatchActivity {
                                return
                            }
                        } else {
                            // If there are no messages, assume no new activity
                            hasMatchActivity = false
                        }
                    } else {
                        // No new activity
                        hasMatchActivity = false
                    }
                }
            } catch {
                print("Error checking match activity: \(error)")
            }
        }
        hasMatchActivity = false
    }
}
