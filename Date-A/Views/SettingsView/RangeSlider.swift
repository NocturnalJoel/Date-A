import SwiftUI

struct RangeSlider: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let range: ClosedRange<Double>
    
    private let circleSize: CGFloat = 28
    private let trackHeight: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (circleSize / 2) // Account for only right circle padding
            
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: trackHeight)
                
                // Active track
                Rectangle()
                    .fill(Color.black)
                    .frame(width: ((maxValue - minValue) / (range.upperBound - range.lowerBound)) * availableWidth,
                           height: trackHeight)
                    .offset(x: ((minValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * availableWidth)
                
                // Slider handles
                HStack(spacing: 0) {
                    // Minimum value handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(radius: 2)
                        .offset(x: ((minValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * availableWidth)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = range.lowerBound + (value.location.x / availableWidth) * (range.upperBound - range.lowerBound)
                                    minValue = min(max(newValue, range.lowerBound), maxValue - 1)
                                }
                        )
                    
                    // Maximum value handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(radius: 2)
                        .offset(x: ((maxValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * availableWidth - circleSize)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = range.lowerBound + (value.location.x / availableWidth) * (range.upperBound - range.lowerBound)
                                    maxValue = max(min(newValue, range.upperBound), minValue + 1)
                                }
                        )
                }
            }
        }
        .frame(height: 44)
        .offset(x: -10)
    }
}
