import SwiftUI

struct RangeSlider: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: (maxValue - minValue) / (range.upperBound - range.lowerBound) * geometry.size.width,
                           height: 4)
                    .offset(x: (minValue - range.lowerBound) / (range.upperBound - range.lowerBound) * geometry.size.width)
                
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .shadow(radius: 2)
                        .offset(x: (minValue - range.lowerBound) / (range.upperBound - range.lowerBound) * geometry.size.width)
                        .gesture(DragGesture().onChanged { value in
                            let newValue = range.lowerBound + (value.location.x / geometry.size.width) * (range.upperBound - range.lowerBound)
                            minValue = min(max(newValue, range.lowerBound), maxValue - 1)
                        })
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .shadow(radius: 2)
                        .offset(x: (maxValue - range.lowerBound) / (range.upperBound - range.lowerBound) * geometry.size.width - 28)
                        .gesture(DragGesture().onChanged { value in
                            let newValue = range.lowerBound + (value.location.x / geometry.size.width) * (range.upperBound - range.lowerBound)
                            maxValue = max(min(newValue, range.upperBound), minValue + 1)
                        })
                }
            }
        }
        .frame(height: 44)
    }
}

#Preview {
    @State var min: Double = 20
    @State var max: Double = 80
    
    return RangeSlider(minValue: $min, maxValue: $max, range: 18...99)
        .padding()
}
