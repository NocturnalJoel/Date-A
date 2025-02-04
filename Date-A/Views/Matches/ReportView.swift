//
//  ReportView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2025-02-04.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ReportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var model: ContentModel
    
    @Binding var shouldPopToRoot: Bool
    
    let matchId: String
    let matchedUser: User
    
    @State private var reportText = ""
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Report User")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            
            Text("If this person has sent objectionable/offensive material or acted in an abusive, harassing, or aggressive manner, you can report them here. This will also block them from contacting you further.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundStyle(.gray)
            
            TextEditor(text: $reportText)
                .frame(height: 150)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
            
            Button {
                Task {
                    await submitReport()
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(Color.red)
                        .frame(width: 250, height: 60)
                    
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Block and Report")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            .buttonStyle(.plain)
            
            Text("We take these actions very seriously. If you want to contact us directly at any point, you can reach out to us at info@dateadating.com")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private func submitReport() async {
        isSubmitting = true
        
        do {
            // Create report document
            let reportRef = Firestore.firestore().collection("reports").document()
            let data: [String: Any] = [
                "reporterId": Auth.auth().currentUser?.uid ?? "",
                "reportedUserId": matchedUser.id,
                "matchId": matchId,
                "reason": reportText,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            try await reportRef.setData(data)
            
            // Block and unmatch the user with rating 0
            try await model.unmatchAndRate(matchId: matchId, rating: 0)
            
            // Refresh matches list to remove the blocked user
            try await model.fetchMatches()
            
            // Dismiss this view and ChatView to return to MatchesView
            dismiss()
            shouldPopToRoot = true
            
        } catch {
            print("Error submitting report: \(error)")
        }
        
        isSubmitting = false
    }
}
