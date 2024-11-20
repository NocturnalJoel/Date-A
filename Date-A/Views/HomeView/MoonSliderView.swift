import SwiftUI

struct MoonSliderView: View {
    @Binding var selectedLevel: Int // Default to middle level (40-60)
    
    private let moonPhases = ["🌑", "🌘", "🌗", "🌖", "🌕"]
    private let ranges = ["0-20", "20-40", "40-60", "60-80", "80-100"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Moon phases row
            HStack {
                ForEach(0..<5) { index in
                    Button(action: {
                        selectedLevel = index
                    }) {
                        VStack(spacing: 4) {
                            Text(moonPhases[index])
                                .font(.title)
                                .opacity(selectedLevel == index ? 1.0 : 0.5)
                            
                            Text(ranges[index])
                                .font(.caption)
                                .foregroundColor(.black)
                                .opacity(selectedLevel == index ? 1.0 : 0.5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Continuous bar with segments
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background continuous bar
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    // Selected segment
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width / 5)
                        .offset(x: CGFloat(selectedLevel) * (geometry.size.width / 5))
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
}

