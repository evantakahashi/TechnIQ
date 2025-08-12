import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isSignUp = false
    
    var body: some View {
        ZStack {
            // Modern gradient background
            DesignSystem.Colors.backgroundGradient
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
    @State private var currentStep = 0
    @State private var selectedPositions: Set<String> = []
    @State private var selectedStyle = "Balanced"
    @State private var selectedFoot = "Right"
    
    private let positions = ["GK", "CB", "LB", "RB", "CDM", "CM", "CAM", "LW", "RW", "ST"]
    private let styles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast", "Playmaker", "Box-to-Box", "Target Man", "Poacher", "Sweeper"]
    private let feet = ["Left", "Right", "Both"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern Header
            HStack {
                Button(action: { 
                    withAnimation(DesignSystem.Animation.smooth) {
                        if currentStep > 0 {
                            currentStep -= 1
                        } else {
                            isSignUp = false
                        }
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
            
            // Modern Progress Indicator
            HStack(spacing: DesignSystem.Spacing.sm) {
                StepIndicator(title: "Your data", isActive: currentStep == 0, isCompleted: currentStep > 0)
                
                ProgressLine(isCompleted: currentStep > 0)
                
                StepIndicator(title: "Configuration", isActive: currentStep == 1, isCompleted: false)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, DesignSystem.Spacing.xl)
            
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    if currentStep == 0 {
                        modernDataStep
                    } else {
                        modernConfigurationStep
                    }
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
            
            // Continue Button
            ModernButton("CONTINUE", icon: "arrow.right") {
                withAnimation(DesignSystem.Animation.smooth) {
                    currentStep = 1
                }
            }
            .disabled(!fieldsAreValid)
            
            // Terms Link
            Button("Terms and Conditions of Use") {
                // Handle terms
            }
            .font(DesignSystem.Typography.bodySmall)
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    private var modernConfigurationStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Header
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "soccerball")
                    .font(.largeTitle)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .pulseAnimation()
                
                Text("Soccer Profile Setup")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            
            // Configuration Form
            ModernCard(padding: DesignSystem.Spacing.lg) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Position Selector (Multi-select)
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Positions (Select all that apply)")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        MultiSelectPillSelector(options: positions, selectedOptions: $selectedPositions, columns: 5)
                    }
                    
                    // Playing Style Selector
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Playing Style")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        PillSelector(options: styles, selectedIndex: Binding(
                            get: { styles.firstIndex(of: selectedStyle) ?? 0 },
                            set: { selectedStyle = styles[$0] }
                        ), columns: 3)
                    }
                    
                    // Dominant Foot Selector
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Dominant Foot")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        PillSelector(options: feet, selectedIndex: Binding(
                            get: { feet.firstIndex(of: selectedFoot) ?? 0 },
                            set: { selectedFoot = feet[$0] }
                        ), columns: 3)
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
                    }
                }
            }
            
            // Create Account Button
            ModernButton("CREATE ACCOUNT", icon: "checkmark") {
                Task {
                    await authManager.signUp(email: email, password: password)
                }
            }
            .disabled(authManager.isLoading)
        }
    }
    
    private var fieldsAreValid: Bool {
        !username.isEmpty && !firstName.isEmpty && !lastName.isEmpty && 
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }
}

// MARK: - Step Indicator Components
struct StepIndicator: View {
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(circleColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                )
            
            Text(title)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(textColor)
                .fontWeight(isActive ? .semibold : .regular)
        }
        .animation(DesignSystem.Animation.quick, value: isActive)
        .animation(DesignSystem.Animation.quick, value: isCompleted)
    }
    
    private var circleColor: Color {
        if isCompleted {
            return DesignSystem.Colors.primaryGreen
        } else if isActive {
            return DesignSystem.Colors.primaryGreen
        } else {
            return DesignSystem.Colors.background
        }
    }
    
    private var borderColor: Color {
        if isCompleted || isActive {
            return DesignSystem.Colors.primaryGreen
        } else {
            return DesignSystem.Colors.neutral300
        }
    }
    
    private var textColor: Color {
        if isActive {
            return DesignSystem.Colors.primaryGreen
        } else {
            return DesignSystem.Colors.textSecondary
        }
    }
}

struct ProgressLine: View {
    let isCompleted: Bool
    
    var body: some View {
        Rectangle()
            .fill(isCompleted ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300)
            .frame(height: 2)
            .animation(DesignSystem.Animation.smooth, value: isCompleted)
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager.shared)
}