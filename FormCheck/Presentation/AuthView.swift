import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthManager

    private enum Mode { case logIn, signUp }
    @State private var mode: Mode = .logIn
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accent)
                    Text("FormCheck")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("See your lift the way a coach would.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)

                Picker("Mode", selection: $mode) {
                    Text("Log In").tag(Mode.logIn)
                    Text("Sign Up").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in auth.lastError = nil }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                    SecureField(mode == .signUp ? "Password (8+ characters)" : "Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { submit() }
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }

                if let error = auth.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 14) {
                    Button {
                        submit()
                    } label: {
                        Text(mode == .signUp ? "Create Account" : "Log In")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(email.isEmpty || password.isEmpty)

                    Button("Continue without an account") {
                        auth.continueAsGuest()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
    }

    private func submit() {
        switch mode {
        case .logIn: auth.logIn(email: email, password: password)
        case .signUp: auth.signUp(email: email, password: password)
        }
    }
}
