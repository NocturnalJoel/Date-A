import SwiftUI
import FirebaseAnalytics

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ContentModel
    
    let reasons = [
        "I found someone on the app",
        "Not enough matches",
        "Too many bugs",
        "I don't like the app's concept",
        "Other"
    ]
    
    @State private var selectedReason: String = ""
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
                
                // Reason Selection
                VStack(spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason)
                                    .foregroundColor(.black)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                            .background(selectedReason.isEmpty ? Color.gray : Color.red)
                            .cornerRadius(16)
                    }
                }
                .disabled(selectedReason.isEmpty || isDeleting)
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
        
        // Log the deletion reason to Firebase Analytics
        Analytics.logEvent("account_deletion", parameters: [
            "reason": selectedReason
        ])
        
        do {
            try await model.deleteAccount()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isDeleting = false
        }
    }
}
