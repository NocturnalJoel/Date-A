import SwiftUI

struct ButtonsView: View {
    @EnvironmentObject var model: ContentModel
    @State private var likeError: Error?
    @State private var showError = false
    
    @State private var leftButtonColor = Color.white
    @State private var rightButtonColor = Color.white
    
    var body: some View {
        HStack(spacing: 40) {
            // Dislike Button
            Button(action: {
                flashButton(isLike: false)
                
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
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .fill(leftButtonColor)
                        .frame(width: 62, height: 62)
                    
                    Image(systemName: "xmark")
                        .font(.title)
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)
            
            // Like Button
            Button(action: {
                flashButton(isLike: true)
                
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
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .fill(rightButtonColor)
                        .frame(width: 62, height: 62)
                    
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .animation(.easeInOut(duration: 0.3), value: leftButtonColor)
        .animation(.easeInOut(duration: 0.3), value: rightButtonColor)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -2)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(likeError?.localizedDescription ?? "Unknown error occurred")
        }
    }
    
    private func flashButton(isLike: Bool) {
        if isLike {
            rightButtonColor = .green.opacity(0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                rightButtonColor = .white
            }
        } else {
            leftButtonColor = .red.opacity(0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                leftButtonColor = .white
            }
        }
    }
}
