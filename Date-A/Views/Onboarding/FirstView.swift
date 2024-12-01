import SwiftUI

struct FirstView: View {
    @State private var showSignIn = false
    @State private var showCreateAccount = false
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("DATE-A")
                .font(.system(size: 55, weight: .heavy))
                .tracking(-1.5)
                .kerning(-0.8)
                .scaleEffect(x: 1.1, y: 1.0)
            
            Spacer()
            
            Button {
                showCreateAccount = true
            } label: {
                Text("CREATE ACCOUNT")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .padding()
            .buttonStyle(.plain)
            
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundColor(.gray)
                Button("Sign In") {
                    showSignIn = true
                }
                .foregroundColor(.black)
                .fontWeight(.medium)
            }
            .font(.system(size: 15))
            .padding(.top, 8)
            
            Spacer()
            
            Spacer()
            
            HStack {
                Text("A Product Of")
                    .foregroundColor(.gray)
                    
                Image("medialoopholelogo")
                    .resizable()
                    .frame(width: 75, height: 75)
                    .scaledToFit()
                    .cornerRadius(15)
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .fullScreenCover(isPresented: $showCreateAccount) {
            CreateAccountView()
        }
    }
}

#Preview {
    FirstView()
}
