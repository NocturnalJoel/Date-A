import SwiftUI

struct ProfileCardView: View {
    let user: User
    @State private var currentIndex = 0
    @State private var hasSharedApp = false
    @State private var showShareSheet = false
    @Binding var stampType: StampType?
    
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
                    if let preloadedImage = model.getPreloadedImage(for: url) {
                        // Use preloaded image
                        Image(uiImage: preloadedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .tag(index)
                    } else {
                        // Fallback to AsyncImage if not preloaded
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
                        .onAppear {
                            // Try to preload if not already loaded
                            if !model.areImagesPreloaded(for: user) {
                                Task {
                                    await model.preloadImagesForUser(user)
                                }
                            }
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Rest of the view remains the same
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
            
            // Bottom overlay with user info
            VStack {
                Spacer()
                VStack(spacing: 16) {
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
                        
                        ZStack {
                            Rectangle()
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .frame(width: 100, height: 50)
                            
                            if hasSharedApp {
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
            
            if let stamp = stampType {
                Circle()
                    .stroke(stamp == .like ? Color.green : Color.red, lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: stamp == .like ? "heart.fill" : "xmark")
                            .font(.system(size: 60))
                            .foregroundColor(stamp == .like ? .green : .red)
                    )
                    .opacity(0.8)
                    .transition(.scale)
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
