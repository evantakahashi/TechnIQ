import SwiftUI

struct AuthenticationView: View {
    @State private var isSignUp = false
    @Binding var isAuthenticated: Bool
    
    init(isAuthenticated: Binding<Bool> = .constant(false)) {
        self._isAuthenticated = isAuthenticated
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if isSignUp {
                SignUpView(isSignUp: $isSignUp, isAuthenticated: $isAuthenticated)
            } else {
                SignInView(isSignUp: $isSignUp, isAuthenticated: $isAuthenticated)
            }
        }
    }
}

struct SignInView: View {
    @Binding var isSignUp: Bool
    @Binding var isAuthenticated: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sign In")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Logo and Title
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    Text("TechnIQ")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                    
                    Text("Master Your Soccer Skills")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Login Form
                VStack(spacing: 20) {
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your username", text: $username)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if showPassword {
                                TextField("Enter your password", text: $password)
                            } else {
                                SecureField("Enter your password", text: $password)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // Login Button
                    Button(action: {
                        // For demo purposes, any credentials work
                        isAuthenticated = true
                    }) {
                        Text("LOGIN")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black)
                            .cornerRadius(28)
                    }
                    .padding(.top, 10)
                    
                    // Forgot Password
                    Button("Forgot password?") {
                        // Handle forgot password
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Create Account
            VStack(spacing: 16) {
                Button(action: { isSignUp = true }) {
                    HStack {
                        Text("CREATE AN ACCOUNT")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray6))
                    .cornerRadius(28)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 34)
        }
    }
}

struct SignUpView: View {
    @Binding var isSignUp: Bool
    @Binding var isAuthenticated: Bool
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { 
                    if currentStep > 0 {
                        currentStep -= 1
                    } else {
                        isSignUp = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Sign Up")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Progress Steps
            HStack(spacing: 8) {
                Text("Your data")
                    .font(.subheadline)
                    .fontWeight(currentStep == 0 ? .semibold : .regular)
                    .foregroundColor(currentStep == 0 ? .primary : .secondary)
                
                Rectangle()
                    .fill(currentStep == 0 ? Color.primary : Color.secondary)
                    .frame(height: 2)
                
                Text("Configuration")
                    .font(.subheadline)
                    .fontWeight(currentStep == 1 ? .semibold : .regular)
                    .foregroundColor(currentStep == 1 ? .primary : .secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            if currentStep == 0 {
                dataStep
            } else {
                configurationStep
            }
            
            Spacer()
        }
    }
    
    private var dataStep: some View {
        VStack(spacing: 32) {
            // Profile Image
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                }
                
                // Username
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Choose username", text: $username)
                        
                        if !username.isEmpty {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .onTapGesture { username = "" }
                        }
                    }
                    .textFieldStyle(CustomTextFieldStyle())
                }
            }
            
            // Form Fields
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("First name", text: $firstName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Surname")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("E-mail")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("your.email@example.com", text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    SecureField("Create password", text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    SecureField("Confirm password", text: $confirmPassword)
                        .textFieldStyle(CustomTextFieldStyle())
                }
            }
            
            // Continue Button
            Button(action: { currentStep = 1 }) {
                Text("CONTINUE")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(fieldsAreValid ? Color.black : Color.gray)
                    .cornerRadius(28)
            }
            .disabled(!fieldsAreValid)
            
            Button("Terms and Conditions of Use") {
                // Handle terms
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
    }
    
    private var configurationStep: some View {
        VStack(spacing: 32) {
            Text("Soccer Profile Setup")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 20) {
                // Position
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        Button("Goalkeeper") { }
                        Button("Defender") { }
                        Button("Midfielder") { }
                        Button("Forward") { }
                    } label: {
                        HStack {
                            Text("Select position")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Playing Style
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playing Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        Button("Aggressive") { }
                        Button("Defensive") { }
                        Button("Balanced") { }
                        Button("Creative") { }
                        Button("Fast") { }
                    } label: {
                        HStack {
                            Text("Select style")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Dominant Foot
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dominant Foot")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        Button("Left") { }
                        Button("Right") { }
                        Button("Both") { }
                    } label: {
                        HStack {
                            Text("Select foot")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            
            // Create Account Button
            Button(action: {
                // For demo purposes, complete signup
                isAuthenticated = true
            }) {
                Text("CREATE ACCOUNT")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(28)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var fieldsAreValid: Bool {
        !username.isEmpty && !firstName.isEmpty && !lastName.isEmpty && 
        !email.isEmpty && !password.isEmpty && password == confirmPassword
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .font(.body)
    }
}

#Preview {
    AuthenticationView()
}