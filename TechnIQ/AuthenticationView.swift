import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isSignUp = false
    
    var body: some View {
        ZStack {
            // Adaptive background (gradient light, solid dark)
            AdaptiveBackground()
                .ignoresSafeArea()
            
            if isSignUp {
                ModernSignUpView(isSignUp: $isSignUp)
            } else {
                ModernSignInView(isSignUp: $isSignUp)
            }
        }
    }
}

struct ModernSignInView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    
    private var isLoginEnabled: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                HStack {
                    Text("Sign In")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: DesignSystem.Icons.settings)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.md)
                
                Spacer(minLength: DesignSystem.Spacing.xl)
                
                // Logo and Title Section
                VStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // Modern logo with soccer ball
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "soccerball")
                                .font(.largeTitle)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                            
                            Text("TechnIQ")
                                .font(DesignSystem.Typography.displaySmall)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                        .pulseAnimation()
                        
                        Text("Master Your Soccer Skills")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Modern Login Form
                    ModernCard(padding: DesignSystem.Spacing.lg) {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ModernTextField(
                                "Email",
                                text: $email,
                                placeholder: "Enter your email",
                                icon: DesignSystem.Icons.email
                            )
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            
                            ModernTextField(
                                "Password",
                                text: $password,
                                placeholder: "Enter your password",
                                icon: DesignSystem.Icons.password,
                                isSecure: true
                            )
                            
                            // Error Message
                            if !authManager.errorMessage.isEmpty {
                                HStack {
                                    Image(systemName: DesignSystem.Icons.xmark)
                                        .foregroundColor(DesignSystem.Colors.error)
                                    Text(authManager.errorMessage)
                                        .font(DesignSystem.Typography.bodySmall)
                                        .foregroundColor(DesignSystem.Colors.error)
                                    Spacer()
                                }
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                            }
                            
                            // Login Button
                            Button(action: {
                                Task {
                                    await authManager.signIn(email: email, password: password)
                                }
                            }) {
                                HStack {
                                    if authManager.isLoading {
                                        SoccerBallSpinner()
                                    }
                                    Text("LOGIN")
                                        .font(DesignSystem.Typography.labelLarge)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(DesignSystem.Spacing.buttonPadding)
                                .background(
                                    isLoginEnabled 
                                        ? DesignSystem.Colors.primaryGradient 
                                        : LinearGradient(colors: [DesignSystem.Colors.neutral400], startPoint: .top, endPoint: .bottom)
                                )
                                .cornerRadius(DesignSystem.CornerRadius.button)
                                .customShadow(DesignSystem.Shadow.medium)
                            }
                            .disabled(!isLoginEnabled || authManager.isLoading)
                            .pressAnimation()
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(DesignSystem.Colors.neutral300)
                                    .frame(height: 1)
                                Text("or")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Rectangle()
                                    .fill(DesignSystem.Colors.neutral300)
                                    .frame(height: 1)
                            }
                            
                            // Google Sign-In Button
                            ModernButton("CONTINUE WITH GOOGLE", icon: "globe", style: .secondary) {
                                Task {
                                    await authManager.signInWithGoogle()
                                }
                            }
                            .disabled(authManager.isLoading)
                            
                            // Forgot Password
                            Button("Forgot password?") {
                                if !email.isEmpty {
                                    Task {
                                        await authManager.resetPassword(email: email)
                                    }
                                }
                            }
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                
                Spacer(minLength: DesignSystem.Spacing.xl)
                
                // Create Account Section
                ModernButton("CREATE AN ACCOUNT", icon: "person.crop.circle.badge.plus", style: .ghost) {
                    withAnimation(DesignSystem.Animation.smooth) {
                        isSignUp = true
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
    }
}

struct ModernSignUpView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isSignUp: Bool
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        VStack(spacing: 0) {
            // Modern Header
            HStack {
                Button(action: {
                    withAnimation(DesignSystem.Animation.smooth) {
                        isSignUp = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .frame(width: 40, height: 40)
                        .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                Spacer()

                Text("Sign Up")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: {}) {
                    Image(systemName: DesignSystem.Icons.settings)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, DesignSystem.Spacing.md)

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    modernDataStep
                }
                .padding(.top, DesignSystem.Spacing.xl)
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
    }
    
    private var modernDataStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Profile Avatar Section
            VStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person")
                        .font(.system(size: 40))
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
                .pulseAnimation()
                
                Text("Profile Setup")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            // Form Fields in Card
            ModernCard(padding: DesignSystem.Spacing.lg) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ModernTextField(
                        "Username",
                        text: $username,
                        placeholder: "Choose username",
                        icon: "person"
                    )
                    
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ModernTextField(
                            "First Name",
                            text: $firstName,
                            placeholder: "First name"
                        )
                        
                        ModernTextField(
                            "Last Name",
                            text: $lastName,
                            placeholder: "Last name"
                        )
                    }
                    
                    ModernTextField(
                        "Email",
                        text: $email,
                        placeholder: "your.email@example.com",
                        icon: DesignSystem.Icons.email
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    ModernTextField(
                        "Password",
                        text: $password,
                        placeholder: "Create password",
                        icon: DesignSystem.Icons.password,
                        isSecure: true
                    )
                    
                    ModernTextField(
                        "Confirm Password",
                        text: $confirmPassword,
                        placeholder: "Confirm password",
                        icon: DesignSystem.Icons.password,
                        isSecure: true
                    )
                }
            }
            
            // Error Message
            if !authManager.errorMessage.isEmpty {
                HStack {
                    Image(systemName: DesignSystem.Icons.xmark)
                        .foregroundColor(DesignSystem.Colors.error)
                    Text(authManager.errorMessage)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.error)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }

            // Create Account Button
            ModernButton("CREATE ACCOUNT", icon: "checkmark") {
                let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                if !fullName.isEmpty {
                    UserDefaults.standard.set(fullName, forKey: "onboarding_prefill_name")
                }
                Task {
                    await authManager.signUp(email: email, password: password)
                }
            }
            .disabled(!fieldsAreValid || authManager.isLoading)

            // Legal Links
            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Terms of Service") {
                    if let url = URL(string: "https://techniq-b9a27.web.app/terms-of-service.html") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("·")
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Button("Privacy Policy") {
                    if let url = URL(string: "https://techniq-b9a27.web.app/privacy-policy.html") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    private var fieldsAreValid: Bool {
        !username.isEmpty && !firstName.isEmpty && !lastName.isEmpty && 
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager.shared)
}