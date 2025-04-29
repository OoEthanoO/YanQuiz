//
//  AccountView.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import SwiftUI
import SwiftData

struct AccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var quizzes: [Quiz]
    
    @State private var isLoggedIn = false
    @State private var showingLoginSheet = false
    @State private var user: User?
    
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isRegistering = false
    @State private var rememberMe = false
    
    @AppStorage("isLoggedIn") private var isLoggedInStorage = false
    @AppStorage("userData") private var userDataString: String = ""
    
    private let networkService = NetworkService()
    
    init() {
        if isLoggedInStorage, !userDataString.isEmpty {
            if let userData = userDataString.data(using: .utf8),
               let storedUser = try? JSONDecoder().decode(User.self, from: userData) {
                _user = State(initialValue: storedUser)
                _isLoggedIn = State(initialValue: true)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoggedIn {
                    // Logged in user profile view
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // User profile header
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(userInitials)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user?.name ?? "User")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text(user?.email ?? "")
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5)
                            
                            // Stats section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Statistics")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                HStack {
                                    StatView(value: "\(quizzes.count)", label: "Quizzes")
                                    Divider()
                                    StatView(value: "\(getTotalQuestions())", label: "Questions")
                                    Divider()
                                    StatView(value: "\(getCompletedQuizzes())", label: "Completed")
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5)
                            }
                            
                            // Settings section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Account Settings")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                SettingRow(icon: "person.fill", title: "Edit Profile", color: .blue)
                                SettingRow(icon: "bell.fill", title: "Notifications", color: .orange)
                                SettingRow(icon: "lock.fill", title: "Privacy & Security", color: .green)
                                SettingRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .purple)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5)
                            
                            // Logout button
                            Button(action: logout) {
                                HStack {
                                    Spacer()
                                    Label("Sign Out", systemImage: "arrow.right.doc.on.clipboard")
                                        .padding()
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Login prompt view
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "person.crop.circle.fill.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text("Sign in to access your quizzes")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Create an account to save your quizzes and access them on all your devices.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showingLoginSheet = true
                        }) {
                            Text("Sign In or Create Account")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showingLoginSheet) {
                loginView
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var userInitials: String {
        if let name = user?.name, !name.isEmpty {
            let components = name.components(separatedBy: " ")
            if components.count > 1, let first = components.first?.first, let last = components.last?.first {
                return "\(first)\(last)"
            } else if let first = components.first?.first {
                return "\(first)"
            }
        }
        return "U"
    }
    
    private func getTotalQuestions() -> Int {
        return quizzes.reduce(0) { $0 + ($1.questions?.count ?? 0) }
    }
    
    private func getCompletedQuizzes() -> Int {
        // This is a placeholder. In a real app, you would track quiz completion status
        return 0
    }
    
    private var loginView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(isRegistering ? "Create Account" : "Sign In")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    if isRegistering {
                        TextField("Name", text: $name)
                            .textContentType(.name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    SecureField("Password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Toggle("Remember me", isOn: $rememberMe)
                        .padding(.vertical, 8)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Button(action: {
                            isRegistering ? register() : login()
                        }) {
                            Text(isRegistering ? "Create Account" : "Sign In")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(email.isEmpty || password.isEmpty || (isRegistering && name.isEmpty))
                        
                        Button(action: {
                            isRegistering.toggle()
                            // Clear fields when switching modes
                            email = ""
                            password = ""
                            name = ""
                        }) {
                            Text(isRegistering ? "Already have an account? Sign in" : "Don't have an account? Register")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingLoginSheet = false
                    }
                }
            }
        }
    }
    
    private func login() {
        isLoading = true
        
        Task {
            do {
                let loggedInUser = try await networkService.loginUser(email: email, password: password)
                await MainActor.run {
                    self.user = loggedInUser
                    self.isLoggedIn = true
                    
                    if rememberMe {
                        KeychainManager.save(key: "authToken", value: networkService.authToken ?? "")
                        
                        if let userData = try? JSONEncoder().encode(loggedInUser), let userString = String(data: userData, encoding: .utf8) {
                            userDataString = userString
                        }
                        
                        isLoggedInStorage = true
                    }
                    
                    self.showingLoginSheet = false
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Login failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func register() {
        isLoading = true
        
        Task {
            do {
                let registeredUser = try await networkService.registerUser(email: email, password: password, name: name)
                await MainActor.run {
                    self.user = registeredUser
                    self.isLoggedIn = true
                    self.showingLoginSheet = false
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Registration failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func logout() {
        KeychainManager.delete(key: "authToken")
        userDataString = ""
        isLoggedInStorage = false
        
        networkService.logout()
        isLoggedIn = false
        user = nil
    }
}

struct StatView: View {
    var value: String
    var label: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingRow: View {
    var icon: String
    var title: String
    var color: Color
    
    var body: some View {
        Button(action: {
            // Handle setting tap
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .imageScale(.small)
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    AccountView()
        .modelContainer(for: Quiz.self, inMemory: true)
}
