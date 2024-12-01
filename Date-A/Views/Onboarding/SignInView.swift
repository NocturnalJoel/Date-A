//
//  SignInView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-12-01.
//

// SignInView.swift
import SwiftUI

struct SignInView: View {
    @EnvironmentObject var model: ContentModel
    @Environment(\.dismiss) var dismiss
    
    @State private var signInEmail = ""
    @State private var signInPassword = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Welcome Back")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                        TextField("", text: $signInEmail)
                            .font(.system(size: 17))
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                        SecureField("", text: $signInPassword)
                            .font(.system(size: 17))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                Button {
                    Task {
                        do {
                            try await model.signIn(
                                email: signInEmail,
                                password: signInPassword
                            )
                            dismiss()
                        } catch {
                            // Error is handled in ContentModel
                        }
                    }
                } label: {
                    Text("Sign In")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(16)
                }
                .disabled(model.isLoading)
                .buttonStyle(.plain)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(!model.errorMessage.isEmpty)) {
                Button("OK") {
                    model.errorMessage = ""
                }
            } message: {
                Text(model.errorMessage)
            }
        }
    }
}
