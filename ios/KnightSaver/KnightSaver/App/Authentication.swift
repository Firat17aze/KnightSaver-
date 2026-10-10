import SwiftUI
import CryptoKit

enum AccountRole: String, Codable, CaseIterable, Identifiable {
    case student = "Student"
    case business = "Business"

    var id: String { rawValue }
}

struct AppAccount: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var email: String
    var role: AccountRole
    var businessName: String?
    var phoneNumber: String? = nil
    var campusName: String? = nil
    let passToken: String

    var knightPass: KnightPass {
        KnightPass(
            memberID: "KNIGHT-\(id.uuidString.prefix(4).uppercased())",
            displayName: displayName,
            campusName: campusName ?? "UCF Main Campus",
            verificationToken: passToken
        )
    }
}

private struct LocalCredential: Codable {
    let account: AppAccount
    let passwordDigest: String
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var account: AppAccount?
    @Published var errorMessage: String?

    private let credentialsKey = "knightsaver.localCredentials.v1"
    private let activeAccountKey = "knightsaver.activeAccountID.v1"
    private var credentials: [LocalCredential] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: credentialsKey),
           let decoded = try? JSONDecoder().decode([LocalCredential].self, from: data) {
            credentials = decoded
        }
        if let activeID = UserDefaults.standard.string(forKey: activeAccountKey),
           let credential = credentials.first(where: { $0.account.id.uuidString == activeID }) {
            account = credential.account
        }
    }

    func signIn(email: String, password: String) {
        errorMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let credential = credentials.first(where: { $0.account.email == normalizedEmail }) else {
            errorMessage = "No local account uses that email. Create an account or use a demo account."
            return
        }
        guard credential.passwordDigest == digest(password) else {
            errorMessage = "That password doesn’t match this account."
            return
        }
        setActive(credential.account)
    }

    func register(
        role: AccountRole,
        name: String,
        email: String,
        password: String,
        businessName: String?
    ) {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedBusiness = businessName?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.count >= 2 else {
            errorMessage = "Enter your full name."
            return
        }
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            errorMessage = "Enter a valid email address."
            return
        }
        if role == .student && !normalizedEmail.hasSuffix("@ucf.edu") {
            errorMessage = "Student accounts require a UCF email address."
            return
        }
        if role == .business && (trimmedBusiness?.isEmpty ?? true) {
            errorMessage = "Enter the business name."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Use at least 8 characters for the password."
            return
        }
        guard !credentials.contains(where: { $0.account.email == normalizedEmail }) else {
            errorMessage = "An account already uses that email."
            return
        }

        let newAccount = AppAccount(
            id: UUID(),
            displayName: trimmedName,
            email: normalizedEmail,
            role: role,
            businessName: role == .business ? trimmedBusiness : nil,
            passToken: UUID().uuidString.replacingOccurrences(of: "-", with: "")
        )
        credentials.append(LocalCredential(account: newAccount, passwordDigest: digest(password)))
        saveCredentials()
        setActive(newAccount)
    }

    func useDemo(_ role: AccountRole) {
        let demo = AppAccount(
            id: role == .student
                ? UUID(uuidString: "B13A07AB-347E-4AF4-86A2-847C18B32A15")!
                : UUID(uuidString: "91DA268C-493A-4C0C-8B79-10D1EDC76184")!,
            displayName: role == .student ? "Alex Knight" : "Jordan Manager",
            email: role == .student ? "alex@ucf.edu" : "manager@knightros.example",
            role: role,
            businessName: role == .business ? "Knightro's Kitchen" : nil,
            phoneNumber: role == .student ? "(407) 555-0142" : "(407) 555-0188",
            campusName: "UCF Main Campus",
            passToken: role == .student ? "demo-7F4C92B1A8E6" : "demo-business-session"
        )
        setActive(demo)
    }

    /// Updates the signed-in profile immediately and persists it for locally created accounts.
    /// Returns a user-facing validation error, or nil when the save succeeds.
    func updateProfile(displayName: String, email: String, phoneNumber: String, campusName: String) -> String? {
        guard var updated = account else { return "Sign in again to update your profile." }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneDigits = trimmedPhone.filter(\.isNumber)

        guard trimmedName.count >= 2 else { return "Enter your full name." }
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            return "Enter a valid email address."
        }
        if updated.role == .student && !normalizedEmail.hasSuffix("@ucf.edu") {
            return "Student accounts require a UCF email address."
        }
        if !trimmedPhone.isEmpty && phoneDigits.count < 10 {
            return "Enter a complete phone number or leave it blank."
        }
        if credentials.contains(where: { $0.account.id != updated.id && $0.account.email == normalizedEmail }) {
            return "Another account already uses that email."
        }

        updated.displayName = trimmedName
        updated.email = normalizedEmail
        updated.phoneNumber = trimmedPhone.isEmpty ? nil : trimmedPhone
        updated.campusName = campusName

        if let index = credentials.firstIndex(where: { $0.account.id == updated.id }) {
            credentials[index] = LocalCredential(
                account: updated,
                passwordDigest: credentials[index].passwordDigest
            )
            saveCredentials()
        }
        setActive(updated)
        return nil
    }

    func signOut() {
        account = nil
        UserDefaults.standard.removeObject(forKey: activeAccountKey)
    }

    private func setActive(_ account: AppAccount) {
        self.account = account
        UserDefaults.standard.set(account.id.uuidString, forKey: activeAccountKey)
    }

    private func saveCredentials() {
        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: credentialsKey)
        }
    }

    private func digest(_ password: String) -> String {
        SHA256.hash(data: Data(password.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private enum AuthenticationMode: String, CaseIterable, Identifiable {
    case signIn = "Sign in"
    case createAccount = "Create account"

    var id: String { rawValue }
}

struct AuthenticationView: View {
    @ObservedObject var store: SessionStore

    @State private var mode: AuthenticationMode = .signIn
    @State private var role: AccountRole = .student
    @State private var name = ""
    @State private var businessName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                VStack(spacing: 18) {
                    Picker("Account action", selection: $mode) {
                        ForEach(AuthenticationMode.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .createAccount {
                        Picker("Account type", selection: $role) {
                            ForEach(AccountRole.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        AuthField(title: "Full name", icon: "person", text: $name)

                        if role == .business {
                            AuthField(title: "Business name", icon: "storefront", text: $businessName)
                        }
                    }

                    AuthField(
                        title: mode == .createAccount && role == .student ? "UCF email" : "Email",
                        icon: "envelope",
                        text: $email,
                        keyboard: .emailAddress
                    )

                    SecureField("Password", text: $password)
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                                .stroke(KnightTheme.line, lineWidth: 1)
                        }

                    if let error = store.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(KnightTheme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Account error: \(error)")
                    }

                    Button(action: submit) {
                        Text(mode.rawValue)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("TRY THE PROTOTYPE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(KnightTheme.muted)

                    HStack(spacing: 12) {
                        DemoAccountButton(title: "Student demo", icon: "graduationcap") {
                            store.useDemo(.student)
                        }
                        DemoAccountButton(title: "Business demo", icon: "storefront") {
                            store.useDemo(.business)
                        }
                    }

                    Text("Accounts created here stay on this device. Production sign-in will connect to the KnightSaver backend and business approval service.")
                        .font(.system(size: 12))
                        .foregroundStyle(KnightTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, KnightTheme.screenPadding)
            .padding(.vertical, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(KnightTheme.paper.ignoresSafeArea())
        .onChange(of: mode) { _, _ in store.errorMessage = nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                KnightMark()
                Spacer()
                Text("PICKUP ONLY")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(KnightTheme.goldDeep)
            }
            Text("Save good food.\nMake an impact.")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text("Sign in as a student, or manage surplus through an authorized business account.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
        }
    }

    private func submit() {
        if mode == .signIn {
            store.signIn(email: email, password: password)
        } else {
            store.register(
                role: role,
                name: name,
                email: email,
                password: password,
                businessName: businessName
            )
        }
    }
}

private struct AuthField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(KnightTheme.muted)
                .frame(width: 20)
            TextField(title, text: $text)
                .textContentType(keyboard == .emailAddress ? .emailAddress : .name)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .keyboardType(keyboard)
                .autocorrectionDisabled(keyboard == .emailAddress)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }
}

private struct DemoAccountButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                        .stroke(KnightTheme.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
