import SwiftUI
import FirebaseAnalytics
import FirebaseAuth
import FirebaseFirestore

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ContentModel
    
    @State private var deletionReason: String = ""
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                Text("We're sorry to see you go")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top)
                
                Text("Please let us know why you're leaving")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                // Free-form reason input
                TextEditor(text: $deletionReason)
                    .frame(height: 120)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.vertical)
                
                Spacer()
                
                // Delete Button
                Button {
                    Task {
                        await deleteAccount()
                    }
                } label: {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.red)
                            .cornerRadius(16)
                    } else {
                        Text("Delete Account")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(deletionReason.isEmpty ? Color.gray : Color.red)
                            .cornerRadius(16)
                    }
                }
                .disabled(deletionReason.isEmpty || isDeleting)
            }
            .padding()
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func deleteAccount() async {
        isDeleting = true
        
        do {
            // Log the deletion reason to Firebase Analytics
            logDeletionReasonToFirebase(reason: deletionReason)
            
            // Delete account from database
            try await model.deleteAccount(reason: deletionReason)
            
            // Sign out the user
            try Auth.auth().signOut()
            
            // Reset app state
            await MainActor.run {
                model.resetState()
                isDeleting = false
            }
            
            // Dismiss the view
            dismiss()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
                showError = true
                isDeleting = false
            }
        }
    }
    
    private func logDeletionReasonToFirebase(reason: String) {
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "reason": reason,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("Analytics").document("AccountDeletionReasons").collection("Reasons").addDocument(data: data) { error in
            if let error = error {
                print("Error logging deletion reason: \(error.localizedDescription)")
            } else {
                print("Deletion reason logged successfully")
            }
        }
    }
}
