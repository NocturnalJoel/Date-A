//
//  HomeView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//
import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var model: ContentModel
    // Sample user for preview
    let sampleUser = User(
        id: "1",
        firstName: "Emma",
        age: 28,
        gender: .female,
        genderPreference: .male,
        email: "emma@example.com",
        pictureURLs: [
            "https://example.com/photo1.jpg",
            "https://example.com/photo2.jpg",
            "https://example.com/photo3.jpg"
        ],
        timesShown: 0,
        timesLiked: 0,
        minAgePreference: 18,
        maxAgePreference: 99
    )
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationBarView()
                    .environmentObject(model)
                
                MoonSliderView()
                    .environmentObject(model)
                
                Spacer()
                
                ProfileCardView(user: sampleUser)
                    .environmentObject(model)
                
                Spacer()
                
                ButtonsView()
                    .environmentObject(model)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HomeView()
}
