import SwiftUI

struct ButtonsView: View {
    @EnvironmentObject var model: ContentModel
    @State private var likeError: Error?
    @State private var showError = false
    @Binding var showMatchAnimation: Bool
    @State private var leftButtonColor = Color.white
    @State private var rightButtonColor = Color.white
    @Binding var matchedUser: User?

    
    private func handleMatch() async {
            showMatchAnimation = true
            // Play haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    
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
                                        let oldMatchCount = model.matches.count
                                        try await model.fetchMatches()
                                        if model.matches.count > oldMatchCount {
                                            await MainActor.run {
                                                matchedUser = topProfile  // Set the matched user
                                                showMatchAnimation = true
                                            }
                                        }
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
struct MatchAnimationView: View {
    @Binding var isPresented: Bool
    let matchedUser: User  // Add this to receive the matched user info
    
    @State private var starOpacities: [Double]
    @State private var starPositions: [CGPoint]
    @State private var cardScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var imageOpacity: Double = 0
    
    init(isPresented: Binding<Bool>, matchedUser: User) {
        _isPresented = isPresented
        self.matchedUser = matchedUser
        _starOpacities = State(initialValue: Array(repeating: 0, count: 12))
        _starPositions = State(initialValue: (0..<12).map { _ in
            CGPoint(
                x: CGFloat.random(in: 50...300),
                y: CGFloat.random(in: 50...600)
            )
        })
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Stars
            ForEach(0..<12) { index in
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 24))
                    .position(starPositions[index])
                    .opacity(starOpacities[index])
            }
            
            // Match card
            VStack(spacing: 20) {
                Text("It's a Match! 🎉")
                    .font(.system(size: 32, weight: .bold))
                
                // Profile image
                if let firstImageUrl = matchedUser.pictureURLs.first {
                    AsyncImage(url: URL(string: firstImageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        case .failure(_):
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .opacity(imageOpacity)
                }
                
                Text("You matched with \(matchedUser.firstName)!")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .scaleEffect(cardScale)
            .opacity(textOpacity)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Play haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Animate stars
        for index in 0..<12 {
            withAnimation(
                Animation
                    .easeOut(duration: 1.5)
                    .delay(Double.random(in: 0...0.5))
            ) {
                starOpacities[index] = 1
                starPositions[index] = CGPoint(
                    x: starPositions[index].x + CGFloat.random(in: -50...50),
                    y: starPositions[index].y + CGFloat.random(in: -50...50)
                )
            }
            
            withAnimation(
                Animation
                    .easeIn(duration: 0.8)
                    .delay(1.2)
            ) {
                starOpacities[index] = 0
            }
        }
        
        // Animate card and image
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            cardScale = 1
            textOpacity = 1
            imageOpacity = 1
        }
        
        // Dismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                isPresented = false
            }
        }
    }
}
