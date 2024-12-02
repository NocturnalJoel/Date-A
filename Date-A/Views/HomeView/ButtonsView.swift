import SwiftUI

struct ButtonsView: View {
    @EnvironmentObject var model: ContentModel
    @State private var likeError: Error?
    @State private var showError = false
    
    @State private var backgroundColor = Color.white
    
    var body: some View {
        HStack(spacing: 40) {
            // Dislike Button
            Button(action: {
                
                flashBackground(color: .red.opacity(0.8))
                
                
                guard !model.profileStack.isEmpty else { return }
                let topProfile = model.profileStack[0]
                
                
                
                Task {
                    do {
                        try await model.dislikeUser(topProfile)
                    } catch {
                        print("Dislike error: \(error)")
                        likeError = error
                        showError = true
                    }
                }
            }) {
                Image(systemName: "xmark")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .buttonStyle(.plain)
            
            // Like Button
            Button(action: {
                
                flashBackground(color: .green.opacity(0.8))
                
                
                guard !model.profileStack.isEmpty else { return }
                let topProfile = model.profileStack[0]
                
                
                
                Task {
                    do {
                        try await model.likeUser(topProfile)
                    } catch {
                        print("Like error: \(error)")
                        likeError = error
                        showError = true
                    }
                }
            }) {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)  // Changed from Color.white to backgroundColor
        .animation(.easeInOut(duration: 0.3), value: backgroundColor)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -2)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(likeError?.localizedDescription ?? "Unknown error occurred")
        }
    }
    
    private func flashBackground(color: Color) {
        backgroundColor = color
        
        // Reset back to white after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            backgroundColor = .white
        }
    }
}
