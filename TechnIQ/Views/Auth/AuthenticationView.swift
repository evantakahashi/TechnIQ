import SwiftUI

// MARK: - Sign-in (Touchline 7a)
//
// Landing: a 470 pt pitch header that fades into the base surface, app mark + wordmark top-left,
// eyebrow, 60 pt headline, one-paragraph pitch, then Apple (inverse) / Google (raised) /
// Email (raised) buttons, "Train as a guest →" as text, and the legal line. Email pushes the
// existing email form onto its own screen.

struct AuthenticationView: View {
    var body: some View {
        NavigationStack {
            SignInLandingView()
                .navigationDestination(for: AuthRouteToken.self) { route in
                    switch route {
                    case .email: EmailAuthView()
                    }
                }
        }
    }
}

// MARK: - Landing

struct SignInLandingView: View {
    @EnvironmentObject private var authManager: AuthenticationManager

    private let headerHeight: CGFloat = 470
    private let copyOverlap: CGFloat = 108   // eyebrow sits inside the header's fade (mock y ≈ 362)

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(topInset: proxy.safeAreaInsets.top)

                    VStack(alignment: .leading, spacing: 0) {
                        TQEyebrow("Your AI soccer coach", size: 13)
                            .padding(.bottom, 10)
                        TQDisplayTitle("Train with\na plan", size: .hero)
                            .padding(.bottom, 12)
                        Text("A weekly plan built around your position and weak spots, drills with diagrams, and every session tracked.")
                            .font(Font.system(size: 16, weight: .regular))
                            .foregroundColor(DesignSystem.Colors.mutedIvory)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 22)

                        if !authManager.errorMessage.isEmpty {
                            TQBanner(.error, message: authManager.errorMessage)
                                .padding(.bottom, 12)
                        }

                        VStack(spacing: 10) {
                            TQButton("Continue with Apple", icon: "apple.logo", style: .inverse, size: .auth, face: .text, isLoading: authManager.isLoading) {
                                Task { await authManager.signInWithApple() }
                            }
                            .accessibilityIdentifier("signin.apple")
                            TQButton("Continue with Google", icon: "g.circle", style: .raised, size: .auth, face: .text) {
                                Task { await authManager.signInWithGoogle() }
                            }
                            .accessibilityIdentifier("signin.google")
                            NavigationLink(value: AuthRouteToken.email) {
                                TQButtonLabel("Continue with email")
                            }
                            .buttonStyle(TQPressStyle(fill: DesignSystem.Colors.surfaceRaised, pressedFill: DesignSystem.Colors.surfaceHighlight, cornerRadius: DesignSystem.CornerRadius.button))
                            .accessibilityIdentifier("signin.email")
                        }
                        .disabled(authManager.isLoading)

                        HStack {
                            Spacer()
                            TQTextLink("Train as a guest") {
                                Task { await authManager.signInAnonymously() }
                            }
                            .disabled(authManager.isLoading)
                            .accessibilityIdentifier("signin.guest")
                            Spacer()
                        }
                        .padding(.top, 2)

                        legalLine
                            .padding(.bottom, 8)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, -copyOverlap)
                }
                .frame(minHeight: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom, alignment: .top)
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // The pitch header: solid pitch under the markings, fading into the base surface over the
    // bottom third so the headline sits on the base colour.
    private func header(topInset: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            DesignSystem.Colors.pitch
            TQPitchMarkings(preset: .signIn)
            LinearGradient(
                stops: [
                    .init(color: DesignSystem.Colors.surfaceBase.opacity(0), location: 0.5),
                    .init(color: DesignSystem.Colors.surfaceBase, location: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            HStack(spacing: 10) {
                TQAppMark()
                Text("TechnIQ")
                    .font(Font.system(size: 22, weight: .bold).width(.condensed))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
            }
            .padding(.leading, DesignSystem.Spacing.screenPadding)
            .padding(.top, max(topInset, 20) + 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("TechnIQ")
        }
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var legalLine: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("By continuing you agree to the ")
            Button("Terms") { open("https://techniq-b9a27.web.app/terms-of-service.html") }
                .foregroundColor(DesignSystem.Colors.mutedIvory)
            Text(" and ")
            Button("Privacy Policy") { open("https://techniq-b9a27.web.app/privacy-policy.html") }
                .foregroundColor(DesignSystem.Colors.mutedIvory)
            Text(".")
            Spacer()
        }
        .font(Font.system(size: 12, weight: .regular))
        .foregroundColor(DesignSystem.Colors.textTertiary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Route token shared with `AuthenticationView`'s destination switch.
enum AuthRouteToken: Hashable { case email }

/// Raised, full-width label matching `TQButton(size: .auth, face: .text)` for use inside a
/// `NavigationLink`.
private struct TQButtonLabel: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(Font.system(size: 17, weight: .semibold))
            .foregroundColor(DesignSystem.Colors.chalkWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
    }
}

// MARK: - Email form (own screen)

struct EmailAuthView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var showResetAlert = false
    @State private var resetAlertMessage = ""
    @State private var modeIndex = 0

    private var canSubmit: Bool {
        guard !email.isEmpty, password.count >= 6 else { return false }
        return isSignUp ? password == confirmPassword && !fullName.trimmingCharacters(in: .whitespaces).isEmpty : true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionLarge) {
                TQNavBar("Email") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }

                TQDisplayTitle(isSignUp ? "Create your account" : "Welcome back", size: .small)

                TQSegment(options: ["Sign in", "Create account"], selectedIndex: $modeIndex)
                    .onChange(of: modeIndex) { _, newValue in
                        withAnimation(DesignSystem.Animation.quick) { isSignUp = newValue == 1 }
                        authManager.errorMessage = ""
                    }

                VStack(spacing: 12) {
                    if isSignUp {
                        TQFormField("Name", text: $fullName, placeholder: "Your name", contentType: .name)
                    }
                    TQFormField("Email", text: $email, placeholder: "you@example.com", contentType: .emailAddress, keyboard: .emailAddress)
                    TQFormField("Password", text: $password, placeholder: isSignUp ? "At least 6 characters" : "Your password", isSecure: true, contentType: isSignUp ? .newPassword : .password)
                    if isSignUp {
                        TQFormField("Confirm password", text: $confirmPassword, placeholder: "Repeat your password", isSecure: true, contentType: .newPassword)
                    }
                }

                if !authManager.errorMessage.isEmpty {
                    TQBanner(.error, message: authManager.errorMessage)
                }

                TQButton(isSignUp ? "Create account" : "Sign in", size: .auth, isLoading: authManager.isLoading) {
                    submit()
                }
                .disabled(!canSubmit)
                .accessibilityIdentifier("email.submit")

                if !isSignUp {
                    HStack {
                        Spacer()
                        TQTextLink("Forgot password?", arrow: false) { resetPassword() }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("Password reset", isPresented: $showResetAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resetAlertMessage)
        }
        .onDisappear { authManager.errorMessage = "" }
    }

    private func submit() {
        let name = fullName.trimmingCharacters(in: .whitespaces)
        if isSignUp, !name.isEmpty {
            UserDefaults.standard.set(name, forKey: "onboarding_prefill_name")
        }
        Task {
            if isSignUp {
                await authManager.signUp(email: email, password: password)
            } else {
                await authManager.signIn(email: email, password: password)
            }
        }
    }

    private func resetPassword() {
        guard !email.isEmpty else {
            resetAlertMessage = "Enter your email first to reset your password."
            showResetAlert = true
            return
        }
        Task {
            await authManager.resetPassword(email: email)
            resetAlertMessage = authManager.errorMessage.isEmpty
                ? "Reset email sent — check your inbox."
                : authManager.errorMessage
            showResetAlert = true
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager.shared)
}
