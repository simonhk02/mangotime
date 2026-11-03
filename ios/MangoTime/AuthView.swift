import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var api: APIClient
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var error: String?
    @State private var busy = false

    enum Mode { case login, register }

    var body: some View {
        VStack(spacing: 20) {
            Text("MangoTime")
                .font(.largeTitle)
                .fontWeight(.bold)

            if mode == .register {
                TextField("顯示名稱", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .nameEntryStyle()
            }
            TextField("電郵", text: $email)
                .textFieldStyle(.roundedBorder)
                .emailEntryStyle()
            SecureField("密碼", text: $password)
                .textFieldStyle(.roundedBorder)
                .passwordEntryStyle(newPassword: mode == .register)

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await submit() }
            } label: {
                Text(busy ? "…" : (mode == .login ? "登入" : "建立帳號"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy || email.isEmpty || password.isEmpty || (mode == .register && displayName.isEmpty))

            Button(mode == .login ? "未有帳號？註冊" : "已有帳號？登入") {
                mode = mode == .login ? .register : .login
                error = nil
            }
            .font(.footnote)
        }
        .padding(32)
    }

    private func submit() async {
        busy = true
        error = nil
        do {
            if mode == .login {
                try await api.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
            } else {
                try await api.register(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespaces)
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}

#Preview {
    AuthView().environmentObject(APIClient.shared)
}

// iOS-only text-input modifiers, gated so the CLT harness can typecheck on macOS.
private extension View {
    @ViewBuilder
    func nameEntryStyle() -> some View {
        #if os(iOS)
        self.textContentType(.name)
        #else
        self
        #endif
    }

    @ViewBuilder
    func emailEntryStyle() -> some View {
        #if os(iOS)
        self
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func passwordEntryStyle(newPassword: Bool) -> some View {
        #if os(iOS)
        self.textContentType(newPassword ? .newPassword : .password)
        #else
        self
        #endif
    }
}
