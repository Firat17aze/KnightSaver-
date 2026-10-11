import SwiftUI
import CryptoKit

enum AccountRole: String, Codable, CaseIterable, Identifiable {
    case student = "Student"
    case business = "Business"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .student: "Student"
        case .business: "Business owner"
        }
    }

    var icon: String {
        switch self {
        case .student: "graduationcap.fill"
        case .business: "storefront.fill"
        }
    }
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
    @Published private(set) var accessToken: String?
    @Published var errorMessage: String?
    @Published private(set) var isWorking = false

    private let credentialsKey = "knightsaver.localCredentials.v1"
    private let activeAccountKey = "knightsaver.activeAccountID.v1"
    private var credentials: [LocalCredential] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: credentialsKey),
           let decoded = try? JSONDecoder().decode([LocalCredential].self, from: data) {
            credentials = decoded
        }
        seedDemoAccounts()
        if let activeID = UserDefaults.standard.string(forKey: activeAccountKey),
           let credential = credentials.first(where: { $0.account.id.uuidString == activeID }) {
            account = credential.account
        }
    }

    /// Signs in to the side the person chose. A student account can't open the business
    /// side, and a business account can't open the student side.
    func signIn(email: String, password: String, as role: AccountRole) async {
        errorMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isWorking = true
        defer { isWorking = false }

        do {
            let session = try await KnightSaverBackend.shared.signIn(
                email: normalizedEmail,
                password: password
            )
            let backendRole = try await KnightSaverBackend.shared.bootstrapIdentity(
                accessToken: session.accessToken
            )
            let resolvedRole: AccountRole = backendRole == "business" ? .business : .student
            guard resolvedRole == role else {
                errorMessage = resolvedRole == .business
                    ? "This is a business account. Go back and choose Business owner."
                    : "This is a student account. Go back and choose Student."
                return
            }

            let passToken = (try? await KnightSaverBackend.shared.knightPassToken(
                accessToken: session.accessToken
            )) ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
            let displayName = normalizedEmail == "alex@ucf.edu"
                ? "Alex Knight"
                : normalizedEmail == "manager@knightros.example" ? "Jordan Manager" : normalizedEmail.split(separator: "@").first.map(String.init) ?? "KnightSaver member"
            let remoteAccount = AppAccount(
                id: session.user.id,
                displayName: displayName,
                email: session.user.email ?? normalizedEmail,
                role: resolvedRole,
                businessName: resolvedRole == .business ? "Knightro's Kitchen" : nil,
                campusName: "UCF Main Campus",
                passToken: passToken
            )
            accessToken = session.accessToken
            setActive(remoteAccount)
            return
        } catch {
            // The built-in demo remains usable offline at judging time.
            if signInLocally(email: normalizedEmail, password: password, as: role) { return }
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    private func signInLocally(email normalizedEmail: String, password: String, as role: AccountRole) -> Bool {
        guard let credential = credentials.first(where: { $0.account.email == normalizedEmail }) else {
            return false
        }
        guard credential.passwordDigest == digest(password) else {
            return false
        }
        guard credential.account.role == role else {
            errorMessage = credential.account.role == .business
                ? "This is a business account. Go back and choose Business owner."
                : "This is a student account. Go back and choose Student."
            return true
        }
        accessToken = nil
        setActive(credential.account)
        return true
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

    /// Signs into the two auto-confirmed hackathon accounts in Supabase.
    func signInDemo(as role: AccountRole) async {
        let email = role == .student ? "alex@ucf.edu" : "manager@knightros.example"
        await signIn(email: email, password: "KnightSaverDemo!2026", as: role)
    }

    private func seedDemoAccounts() {
        let demos = [
            AppAccount(
                id: UUID(uuidString: "B13A07AB-347E-4AF4-86A2-847C18B32A15")!,
                displayName: "Alex Knight",
                email: "alex@ucf.edu",
                role: .student,
                phoneNumber: "(407) 555-0142",
                campusName: "UCF Main Campus",
                passToken: "demo-7F4C92B1A8E6"
            ),
            AppAccount(
                id: UUID(uuidString: "91DA268C-493A-4C0C-8B79-10D1EDC76184")!,
                displayName: "Jordan Manager",
                email: "manager@knightros.example",
                role: .business,
                businessName: "Knightro's Kitchen",
                phoneNumber: "(407) 555-0188",
                campusName: "UCF Main Campus",
                passToken: "demo-business-session"
            )
        ]
        let missing = demos.filter { demo in !credentials.contains { $0.account.email == demo.email } }
        guard !missing.isEmpty else { return }
        credentials += missing.map { LocalCredential(account: $0, passwordDigest: digest("knightsaver")) }
        saveCredentials()
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
        accessToken = nil
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

/// First screen: choose Student or Business owner, then sign in or sign up for that side.
struct AuthenticationView: View {
    @ObservedObject var store: SessionStore
    @State private var role: AccountRole?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let role {
                RoleAuthenticationView(store: store, role: role) {
                    store.errorMessage = nil
                    self.role = nil
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                RoleChoiceView { role = $0 }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: role)
        .background(KnightTheme.paper.ignoresSafeArea())
    }
}

private struct RoleChoiceView: View {
    let onChoose: (AccountRole) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 14) {
                    KnightSaverBrandBar()
                    Text("Save good food.\nMake an impact.")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("How will you use KnightSaver?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }

                VStack(spacing: 14) {
                    RoleCard(
                        role: .student,
                        title: "I'm a student"
                    ) { onChoose(.student) }

                    RoleCard(
                        role: .business,
                        title: "I'm a business owner"
                    ) { onChoose(.business) }
                }
            }
            .padding(.horizontal, KnightTheme.screenPadding)
            .padding(.vertical, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct RoleCard: View {
    let role: AccountRole
    let title: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RoleIcon(role: role, size: 64)

                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(KnightTheme.muted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                    .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(title)
    }
}

/// Student: graduation cap. Business: the sprout storefront used for the Kitchen tab.
private struct RoleIcon: View {
    let role: AccountRole
    let size: CGFloat

    var body: some View {
        Group {
            if role == .business {
                Image("TabKitchenFill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.48, height: size * 0.48)
            } else {
                Image(systemName: role.icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
            }
        }
        .foregroundStyle(KnightTheme.onAccent)
        .frame(width: size, height: size)
        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Sign in or create an account for one side of the app.
private struct RoleAuthenticationView: View {
    @ObservedObject var store: SessionStore
    let role: AccountRole
    let onBack: () -> Void

    @State private var mode: AuthenticationMode = .signIn
    @State private var name = ""
    @State private var businessName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Choose student or business owner")

                header

                VStack(spacing: 18) {
                    Picker("Account action", selection: $mode) {
                        ForEach(AuthenticationMode.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .createAccount {
                        AuthField(
                            title: role == .business ? "Your full name" : "Full name",
                            icon: "person",
                            text: $name
                        )

                        if role == .business {
                            AuthField(title: "Business name", icon: "storefront", text: $businessName)
                        }
                    }

                    AuthField(
                        title: role == .student ? "UCF email" : "Business email",
                        icon: "envelope",
                        text: $email,
                        keyboard: .emailAddress
                    )

                    HStack(spacing: 11) {
                        Image(systemName: "lock")
                            .foregroundStyle(KnightTheme.muted)
                            .frame(width: 20)
                        SecureField("Password", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                    }
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

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(store.isWorking ? "Connecting…" : mode.rawValue)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isWorking)

                    if mode == .signIn {
                        Button {
                            Task { await store.signInDemo(as: role) }
                        } label: {
                            Label(role == .student ? "Skip, use demo student" : "Skip, use demo business", systemImage: "bolt.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(KnightTheme.ink)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                                        .stroke(KnightTheme.line, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isWorking)
                    }
                }
            }
            .padding(.horizontal, KnightTheme.screenPadding)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: mode) { _, _ in store.errorMessage = nil }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            RoleIcon(role: role, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(role.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
                Text(mode == .signIn ? "Welcome back" : "Create your account")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(role == .student
                     ? "Use your UCF email to reserve bags."
                     : "Manage your listings and pickups.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }
        }
    }

    private func submit() async {
        if mode == .signIn {
            await store.signIn(email: email, password: password, as: role)
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
