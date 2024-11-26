//  HomeView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//
import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var model: ContentModel
    
    
    // Sample user for preview

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationBarView()
                    .environmentObject(model)
                
                MoonSliderView(selectedLevel: $model.moonSliderLevel)
                    .environmentObject(model)
                
                Spacer()
                //
                ZStack {
                    if !model.profileStack.isEmpty {
                        // Show background cards without animation
                        ForEach(Array(model.profileStack.enumerated().reversed()), id: \.element.id) { _, user in
                                                                           ProfileCardView(
                                                                               user: user // Stack always stays centered
                                                                           )
                                                                       }
                                                                       
                                                                     

                    } else {
                                        // Only show this if we truly have no profiles
                                        if model.isLoadingProfiles {
                                            ProgressView()
                                        } else {
                                            VStack(spacing: 16) {
                                                Image(systemName: "person.slash")
                                                    .font(.system(size: 50))
                                                    .foregroundColor(.gray)
                                                
                                                Text("No More Profiles Available")
                                                    .font(.title3)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.gray)
                                                
                                                Text("Check back later for new matches")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray.opacity(0.8))
                                            }
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color(.systemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .shadow(radius: 5)
                                            .padding()
                                        }
                                    }
                                }
                                .frame(height: 500)
                //
                Spacer()
                
                ButtonsView()
                    .environmentObject(model)
            }
            .navigationBarHidden(true)
            //
            .onAppear { model.startFetchingProfiles() }
            //
        }
    }
}
