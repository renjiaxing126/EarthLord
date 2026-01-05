# 认证系统使用指南

## 概览

AuthManager 是《地球新主》的核心认证管理器，支持三种认证流程：
1. **注册流程**（OTP验证 → 设置密码）
2. **登录流程**（邮箱 + 密码）
3. **找回密码流程**（OTP验证 → 重置密码）

## 架构

```
SupabaseService (全局单例)
       ↓
AuthManager (@MainActor + ObservableObject)
       ↓
SwiftUI Views
```

## 初始化

```swift
import SwiftUI

@main
struct EarthLordApp: App {
    // 创建 AuthManager 实例
    @StateObject private var authManager = AuthManager(
        supabase: SupabaseService.shared
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
```

## 使用示例

### 1. 注册流程

```swift
struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var otp = ""
    @State private var password = ""

    var body: some View {
        VStack {
            if !authManager.otpSent {
                // 步骤 1: 发送验证码
                TextField("邮箱", text: $email)
                Button("发送验证码") {
                    Task {
                        await authManager.sendRegisterOTP(email: email)
                    }
                }
            } else if !authManager.otpVerified {
                // 步骤 2: 验证验证码
                TextField("验证码", text: $otp)
                Button("验证") {
                    Task {
                        await authManager.verifyRegisterOTP(email: email, code: otp)
                    }
                }
            } else if authManager.needsPasswordSetup {
                // 步骤 3: 设置密码
                SecureField("设置密码", text: $password)
                Button("完成注册") {
                    Task {
                        await authManager.completeRegistration(password: password)
                    }
                }
            }

            // 错误提示
            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            // 加载指示器
            if authManager.isLoading {
                ProgressView()
            }
        }
    }
}
```

### 2. 登录流程

```swift
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack {
            TextField("邮箱", text: $email)
            SecureField("密码", text: $password)

            Button("登录") {
                Task {
                    await authManager.signIn(email: email, password: password)
                }
            }
            .disabled(authManager.isLoading)

            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            if authManager.isLoading {
                ProgressView()
            }
        }
    }
}
```

### 3. 找回密码流程

```swift
struct ForgotPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var otp = ""
    @State private var newPassword = ""

    var body: some View {
        VStack {
            if !authManager.otpSent {
                // 步骤 1: 发送重置验证码
                TextField("邮箱", text: $email)
                Button("发送重置码") {
                    Task {
                        await authManager.sendResetOTP(email: email)
                    }
                }
            } else if !authManager.otpVerified {
                // 步骤 2: 验证重置码
                TextField("验证码", text: $otp)
                Button("验证") {
                    Task {
                        await authManager.verifyResetOTP(email: email, code: otp)
                    }
                }
            } else if authManager.needsPasswordSetup {
                // 步骤 3: 设置新密码
                SecureField("新密码", text: $newPassword)
                Button("重置密码") {
                    Task {
                        await authManager.resetPassword(newPassword: newPassword)
                    }
                }
            }
        }
    }
}
```

### 4. 根视图（认证状态路由）

```swift
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // 已完全认证 → 主界面
                MainTabView()
            } else if authManager.needsPasswordSetup {
                // OTP 已验证但需要设置密码
                SetPasswordView()
            } else {
                // 未登录 → 登录/注册界面
                AuthenticationView()
            }
        }
    }
}
```

## 状态说明

### Published 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `isAuthenticated` | Bool | 用户是否已完全认证（登录且完成所有步骤） |
| `needsPasswordSetup` | Bool | 是否需要设置密码（OTP验证后） |
| `currentUser` | User? | 当前登录用户信息 |
| `isLoading` | Bool | 是否正在执行异步操作 |
| `errorMessage` | String? | 错误消息 |
| `otpSent` | Bool | 验证码是否已发送 |
| `otpVerified` | Bool | 验证码是否已验证 |

### 状态流转图

#### 注册流程
```
未登录 → [发送OTP] → otpSent=true
       → [验证OTP] → otpVerified=true, needsPasswordSetup=true, isAuthenticated=false
       → [设置密码] → isAuthenticated=true, needsPasswordSetup=false
```

#### 登录流程
```
未登录 → [邮箱密码登录] → isAuthenticated=true
```

#### 找回密码流程
```
未登录 → [发送重置OTP] → otpSent=true
       → [验证重置OTP (type: .recovery)] → otpVerified=true, needsPasswordSetup=true
       → [重置密码] → isAuthenticated=true, needsPasswordSetup=false
```

## 重要注意事项

### ⚠️ OTP 验证类型

- **注册流程**：使用 `type: .email`
- **找回密码流程**：使用 `type: .recovery`（这是关键区别！）

### ⚠️ 注册流程的特殊逻辑

验证 OTP 成功后，用户**已经登录到 Supabase**，但 `isAuthenticated` 仍为 `false`。
只有完成密码设置后，`isAuthenticated` 才会变为 `true`。

这样设计的原因：
- 强制用户在注册时必须设置密码
- 防止只通过 OTP 就能访问应用的安全问题

### ⚠️ 会话管理

应用启动时会自动调用 `checkSession()`，检查是否有有效会话。
如果有，会自动恢复登录状态。

## 辅助方法

```swift
// 登出
await authManager.signOut()

// 清除错误消息
authManager.clearError()

// 重置 OTP 状态（用于重新发送验证码）
authManager.resetOTPState()
```

## 第三方登录（待实现）

```swift
// Apple 登录（预留）
await authManager.signInWithApple()

// Google 登录（预留）
await authManager.signInWithGoogle()
```

## 错误处理

所有异步方法都会捕获错误并更新 `errorMessage` 属性。
界面应该监听该属性并显示错误提示。

```swift
if let error = authManager.errorMessage {
    Text(error)
        .foregroundColor(.red)
}
```

## Supabase 配置

确保在 Supabase Dashboard 中配置了正确的邮件模板：
1. **Magic Link** - 用于注册 OTP
2. **Reset Password** - 用于密码重置 OTP

## 安全建议

1. ✅ 使用 HTTPS 连接
2. ✅ Publishable Key 是公开的，可以放在客户端
3. ✅ 所有敏感操作通过 RLS（Row Level Security）保护
4. ⚠️ 不要在客户端存储 Service Role Key
5. ⚠️ 密码强度验证应在设置密码前进行

## 示例项目结构

```
EarthLord/
├── Services/
│   └── SupabaseService.swift      # Supabase 客户端配置
├── Managers/
│   └── AuthManager.swift           # 认证管理器
├── Views/
│   ├── Auth/
│   │   ├── RegisterView.swift     # 注册界面
│   │   ├── LoginView.swift        # 登录界面
│   │   └── ForgotPasswordView.swift # 找回密码界面
│   └── RootView.swift              # 根视图（路由）
└── Models/
    └── User.swift                  # 用户模型（已在 AuthManager 中定义）
```
