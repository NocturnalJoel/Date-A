import SwiftUI

struct ProfileCardView: View {
    let user: User
    @State private var currentIndex = 0
    
    @EnvironmentObject var model: ContentModel
    
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
            .allowsHitTesting(false)
        }
        .frame(width: 400, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 5)
    }
}//
