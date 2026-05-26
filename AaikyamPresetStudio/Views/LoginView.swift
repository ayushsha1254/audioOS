import SwiftUI
import Supabase

struct LoginView: View {
    @State private var email:        String = ""
    @State private var password:     String = ""
    @State private var isLoading:    Bool = false
    @State private var errorMessage: String?

    private let supabase: SupabaseClient
    var onAuthenticated: (UUID) -> Void

    init(supabase: SupabaseClient, onAuthenticated: @escaping (UUID) -> Void) {
        self.supabase = supabase
        self.onAuthenticated = onAuthenticated
    }

    var body: some View {
        ZStack {
            Color.warmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo area
                VStack(spacing: 8) {
                    Text("🎙")
                        .font(.system(size: 60))
                    Text("Aaikyam")
                        .font(.custom("Syne-Bold", size: 34))
                        .foregroundColor(.warmPrimaryText)
                    Text("Preset Studio")
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(.warmSecondaryText)
                }
                .padding(.bottom, 48)

                // Form
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textFieldStyle(WarmTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Password", text: $password)
                        .textFieldStyle(WarmTextFieldStyle())
                        .textContentType(.password)

                    if let err = errorMessage {
                        Text(err)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.warmAccent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    Button(action: { Task { await signIn() } }) {
                        HStack(spacing: 8) {
                            if isLoading { ProgressView().tint(.white).scaleEffect(0.85) }
                            Text(isLoading ? "Signing in…" : "Sign In")
                                .font(.custom("Syne-Bold", size: 16))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            (email.isEmpty || password.isEmpty || isLoading)
                                ? Color.warmSecondaryText
                                : Color.warmPrimaryText
                        )
                        .cornerRadius(14)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("Sign up at aaikyam.com")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(.warmSecondaryText)
                    .padding(.bottom, 36)
            }
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            // sound_presets.artist_id references artist_profiles.id (NOT auth.uid()).
            // Must look up the correct UUID or every INSERT will fail RLS.
            let artistProfileId = try await fetchArtistProfileId(for: session.user.id)
            onAuthenticated(artistProfileId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Text field style

struct WarmTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.custom("DMSans-Regular", size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.warmCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warmTrack, lineWidth: 1))
    }
}
