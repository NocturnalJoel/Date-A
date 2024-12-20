import SwiftUI

struct ProfileCardView: View {
    let user: User
    @State private var currentIndex = 0
    @State private var hasSharedApp = false
    @State private var showShareSheet = false
    
    @EnvironmentObject var model: ContentModel
    
    private func calculateRatio() -> Double {
        let total = user.timesLiked + user.timesDisliked
        guard total > 0 else { return 0 }
        return (Double(user.timesLiked) / Double(total)) * 100
    }
    
    var body: some View {
        ZStack {
            // Image carousel
            TabView(selection: $currentIndex) {
                ForEach(Array(user.pictureURLs.enumerated()), id: \.1) { index, url in
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            Image(systemName: "person.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding()
                                .foregroundColor(.orange)
                        case .empty:
                            Color.clear
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Overlay gradient for better text visibility
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.1)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
            }
            .allowsHitTesting(false)
            
            // Bottom overlay with user info and page indicators
            VStack {
                Spacer()
                VStack(spacing: 16) {
                    // User info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.firstName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("\(user.age)")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        
                        // Ratio Button/Display
                        ZStack {
                            Rectangle()
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .frame(width: 100, height: 50)
                            
                            if hasSharedApp {
                                // Show ratio when app has been shared
                                HStack(spacing: 4) {
                                    Text("\(Int(calculateRatio()))")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.black)
                            } else {
                                // Show share button when not shared
                                Button {
                                    showShareSheet = true
                                } label: {
                                    Text("See Ratio")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Page indicators
                    HStack(spacing: 4) {
                        ForEach(0..<user.pictureURLs.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 5)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(hasSharedApp: $hasSharedApp)
        }
    }
}
