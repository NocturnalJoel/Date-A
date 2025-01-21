import SwiftUI

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let description: String
    var emojiSize: CGFloat = 80
    var additionalLines: [String] = []
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    
    let slides: [OnboardingSlide] = [
        OnboardingSlide(
            emoji: "✨",
            title: "Welcome to DATE-A",
            description: "The dating app that lets you find exactly who you want"
        ),
        OnboardingSlide(
            emoji: "💯",
            title: "The Holy Ratio",
            description: "Everyone on the app has a ratio which represents how many people out of 100 have liked your profile (you can see yours or someone else's by sharing the app with a friend)."
        ),
        OnboardingSlide(
            emoji: "🌖",
            title: "Let the Moons Guide You",
            description: "Along with other criterias, you can search through profiles based on their ratio. There are 5 groups represented by a different phase of the moon:",
            additionalLines: [
                "🌑  0% - 20%",
                "🌘  20% - 40%",
                "🌗  40% - 60%",
                "🌖  60% - 80%",
                "🌕  80% - 100%"
            ]
        ),
        OnboardingSlide(
            emoji: "😳",
            title: "No More Uncertainty",
            description: "When chatting with a match, when you're ready to go on a date or exchange social media, you can let the app know via the Manage button. ",
            additionalLines: [
                "If they have already done the same or if they do so later, you will both be notified at that time. No more awkward requests that can lead to rejection."
            ]
        ),
        OnboardingSlide(
            emoji: "💬",
            title: "Your Chat Game Matters",
            description: "When you unmatch someone, you will be able to rate the overall quality of conversation you had with that person (speed of replies, level of humor, respect, etc.) ",
            additionalLines: [
                "When someone unmatches you, you also get to rate the person who unmatched you. These ratings are anonymous. In an upcoming update, you will be able to filter people via this rating."
            ]
        ),
        OnboardingSlide(
            emoji: "🎯",
            title: "This Is Only the Beginning",
            description: "Our eventual goal is to let you search through profiles with every detail you can think of that aren't available on other dating apps like highest level of studies reached, income, quality of conversation, ethnicity or even hair/eye color."
            ,
            additionalLines: [
                "By using this app, you are helping us build the most precise tool on the market to find your soulmate."
            ]
        ),
        OnboardingSlide(
            emoji: "✅",
            title: "You're All Set!",
            description: "Let's create your profile and start your journey."
        )
    ]
    
    var body: some View {
            ZStack {
                if currentPage < slides.count {
                    VStack(spacing: 40) {
                        
                        
                        
                            Text(slides[currentPage].emoji)
                                .font(.system(size: slides[currentPage].emojiSize))
                        
                        
                        VStack(spacing: 25) {
                            Text(slides[currentPage].title)
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)

                            VStack(spacing: 16) {
                                                        Text(slides[currentPage].description)
                                                            .font(.system(size: 17))
                                                            .foregroundColor(.gray)
                                                            .multilineTextAlignment(.center)
                                                            .padding(.horizontal, 32)
                                                        
                                                        if !slides[currentPage].additionalLines.isEmpty {
                                                            VStack(spacing: 8) {
                                                                ForEach(slides[currentPage].additionalLines, id: \.self) { line in
                                                                    Text(line)
                                                                        .font(.system(size: 17))
                                                                        .foregroundColor(.gray)
                                                                        .multilineTextAlignment(.center)
                                                                        .padding(.horizontal, 32)
                                                                }
                                                            }
                                                            .padding(.top, 8)
                                                        }
                                                    }
                        }
                        
                        
                        // Progress dots
                        HStack(spacing: 8) {
                            ForEach(0..<slides.count, id: \.self) { index in
                                Circle()
                                    .fill(currentPage == index ? Color.black : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        Button {
                            if currentPage < slides.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                currentPage += 1
                            }
                        } label: {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                        .buttonStyle(.plain)
                        
                        if currentPage == 0 {
                            Button {
                                currentPage = slides.count
                            } label: {
                                Text("Skip")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 16)
                        }
                        
                        Spacer()
                            .frame(height: 50)
                    }
                } else {
                    CreateAccountView()
                }
            }
        }
}
