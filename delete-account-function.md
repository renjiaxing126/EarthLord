# Delete Account 边缘函数使用指南

## ✅ 部署完成

**函数名称**：`delete-account`
**函数 ID**：`3e09027f-3f12-4254-b9c7-e4dd4af55478`
**状态**：ACTIVE ✅
**版本**：1
**JWT 验证**：已启用 ✅

---

## 📡 API 端点

### 端点 URL

```
https://fbisbjxlwucmxgunkcxh.supabase.co/functions/v1/delete-account
```

### 请求方法

```
POST
```

---

## 🔐 身份验证

函数启用了 JWT 验证，请求必须包含有效的 Authorization header。

### Headers

```
Authorization: Bearer <用户的 JWT token>
Content-Type: application/json
```

---

## 📝 功能说明

### 工作流程

1. **验证请求者身份**
   - 从 `Authorization` header 获取 JWT token
   - 使用 Supabase Auth 验证 token 有效性
   - 获取当前登录用户的信息

2. **删除用户数据**
   - 使用 `service_role` key 删除 `profiles` 表中的用户记录
   - 处理级联删除（如果有外键关联）

3. **删除用户账户**
   - 使用管理员权限调用 `auth.admin.deleteUser()`
   - 永久删除用户认证账户

4. **返回响应**
   - 成功：返回 200 + 成功信息
   - 失败：返回错误码 + 错误详情

---

## 💻 客户端调用示例

### Swift (iOS)

```swift
import Supabase

/// 删除用户账户
func deleteAccount() async throws {
    // 获取当前用户的 session
    let session = try await supabase.auth.session

    // 调用边缘函数
    let response = try await supabase.functions.invoke(
        "delete-account",
        options: FunctionInvokeOptions(
            headers: ["Authorization": "Bearer \(session.accessToken)"]
        )
    )

    // 解析响应
    let decoder = JSONDecoder()
    let result = try decoder.decode(DeleteAccountResponse.self, from: response.data)

    print("账户删除成功: \(result.message)")
}

// 响应模型
struct DeleteAccountResponse: Codable {
    let success: Bool
    let message: String
    let user_id: String
}
```

### JavaScript / TypeScript

```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

async function deleteAccount() {
  // 获取当前用户的 session
  const { data: { session } } = await supabase.auth.getSession()

  if (!session) {
    throw new Error('用户未登录')
  }

  // 调用边缘函数
  const { data, error } = await supabase.functions.invoke('delete-account', {
    headers: {
      Authorization: `Bearer ${session.access_token}`,
    },
  })

  if (error) {
    console.error('删除账户失败:', error)
    throw error
  }

  console.log('账户删除成功:', data)
  return data
}
```

### cURL

```bash
# 获取用户的 JWT token（通过登录获取）
TOKEN="your_jwt_token_here"

# 调用边缘函数
curl -X POST \
  https://fbisbjxlwucmxgunkcxh.supabase.co/functions/v1/delete-account \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

---

## 📊 响应格式

### 成功响应 (200)

```json
{
  "success": true,
  "message": "账户已成功删除",
  "user_id": "5358a1e6-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### 错误响应

#### 401 - 缺少 Authorization header

```json
{
  "error": "缺少 Authorization header"
}
```

#### 401 - 身份验证失败

```json
{
  "error": "身份验证失败",
  "details": "Invalid JWT token"
}
```

#### 500 - 删除失败

```json
{
  "error": "删除账户失败",
  "details": "User not found"
}
```

#### 500 - 服务器错误

```json
{
  "error": "服务器内部错误",
  "details": "具体错误信息"
}
```

---

## 🔧 集成到 EarthLord 应用

### 1. 在 AuthManager 中添加删除账户方法

```swift
// AuthManager.swift

/// 删除用户账户
func deleteAccount() async throws {
    isLoading = true
    errorMessage = nil

    do {
        // 获取当前 session
        let session = try await supabase.auth.session

        // 调用边缘函数
        let response = try await supabase.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"]
            )
        )

        print("✅ 账户删除成功")

        // 清理本地状态
        isAuthenticated = false
        needsPasswordSetup = false
        currentUser = nil
        otpSent = false
        otpVerified = false

    } catch {
        errorMessage = "删除账户失败: \(error.localizedDescription)"
        print("❌ 删除账户失败: \(error)")
        throw error
    }

    isLoading = false
}
```

### 2. 在个人页面添加删除账户按钮

```swift
// ProfileTabView.swift

@State private var showDeleteConfirmation = false

var body: some View {
    // ... 其他内容

    // 删除账户按钮（危险操作）
    Button {
        showDeleteConfirmation = true
    } label: {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
            Text("删除账户")
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.red.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red, lineWidth: 2)
        )
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .alert("删除账户", isPresented: $showDeleteConfirmation) {
        Button("取消", role: .cancel) {}
        Button("删除", role: .destructive) {
            Task {
                do {
                    try await authManager.deleteAccount()
                } catch {
                    // 错误已在 AuthManager 中处理
                }
            }
        }
    } message: {
        Text("此操作将永久删除您的账户和所有数据，且无法恢复。确定要继续吗？")
    }
}
```

### 3. 添加二次确认（推荐）

```swift
// 更安全的删除流程

@State private var showDeleteConfirmation = false
@State private var showFinalConfirmation = false
@State private var confirmationText = ""

// 第一次确认
.alert("删除账户", isPresented: $showDeleteConfirmation) {
    Button("取消", role: .cancel) {}
    Button("继续", role: .destructive) {
        showFinalConfirmation = true
    }
} message: {
    Text("此操作将永久删除您的账户和所有数据，且无法恢复。")
}

// 第二次确认（输入确认文字）
.alert("最终确认", isPresented: $showFinalConfirmation) {
    TextField("输入 '删除账户' 以确认", text: $confirmationText)
    Button("取消", role: .cancel) {
        confirmationText = ""
    }
    Button("删除", role: .destructive) {
        if confirmationText == "删除账户" {
            Task {
                do {
                    try await authManager.deleteAccount()
                } catch {
                    // 错误处理
                }
            }
        }
        confirmationText = ""
    }
    .disabled(confirmationText != "删除账户")
} message: {
    Text("请输入 '删除账户' 以确认此操作")
}
```

---

## 🗑️ 数据删除说明

### 自动删除的数据

当调用此函数时，会自动删除：

1. **profiles 表**
   - 用户的个人资料记录
   - `user_id` 匹配的所有记录

2. **auth.users 表**
   - 用户的认证账户
   - 登录凭证
   - 邮箱信息

### 级联删除（需要配置）

如果你的数据库表有外键关联到 `profiles.user_id`，需要设置级联删除：

```sql
-- 示例：territories 表
ALTER TABLE territories
DROP CONSTRAINT IF EXISTS territories_user_id_fkey;

ALTER TABLE territories
ADD CONSTRAINT territories_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES profiles(user_id)
ON DELETE CASCADE;  -- ← 级联删除

-- 示例：pois 表
ALTER TABLE pois
DROP CONSTRAINT IF EXISTS pois_discovered_by_fkey;

ALTER TABLE pois
ADD CONSTRAINT pois_discovered_by_fkey
FOREIGN KEY (discovered_by)
REFERENCES profiles(user_id)
ON DELETE CASCADE;  -- ← 级联删除
```

### 手动删除其他数据

如果有其他表需要删除，在边缘函数中添加删除逻辑：

```typescript
// index.ts 中添加

// 删除 territories 表中的记录
const { error: territoriesError } = await supabaseAdmin
  .from('territories')
  .delete()
  .eq('user_id', user.id);

// 删除 pois 表中的记录
const { error: poisError } = await supabaseAdmin
  .from('pois')
  .delete()
  .eq('discovered_by', user.id);
```

---

## 🔒 安全注意事项

### 1. JWT 验证已启用

- ✅ 函数自动验证 JWT token 有效性
- ✅ 只有已登录用户可以调用
- ✅ 用户只能删除自己的账户

### 2. Service Role Key 安全

- ✅ Service Role Key 存储在 Supabase 环境变量中
- ✅ 不会暴露给客户端
- ✅ 只在服务器端使用

### 3. 建议的安全措施

#### 添加冷静期（推荐）

```typescript
// 在删除前添加 30 天冷静期
const { error: updateError } = await supabaseAdmin
  .from('profiles')
  .update({
    deletion_requested_at: new Date().toISOString(),
    status: 'pending_deletion'
  })
  .eq('user_id', user.id);

// 30 天后才真正删除
// 可以使用 Supabase 定时任务实现
```

#### 发送确认邮件

```typescript
// 在删除前发送邮件确认
await fetch('https://api.sendgrid.com/v3/mail/send', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${SENDGRID_API_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    personalizations: [{
      to: [{ email: user.email }],
    }],
    from: { email: 'noreply@earthlord.com' },
    subject: '账户删除确认',
    content: [{
      type: 'text/plain',
      value: '您的账户已被删除。如果这不是您本人操作，请立即联系我们。',
    }],
  }),
});
```

#### 记录删除日志

```typescript
// 在删除前记录到日志表
await supabaseAdmin
  .from('deletion_logs')
  .insert({
    user_id: user.id,
    email: user.email,
    deleted_at: new Date().toISOString(),
    ip_address: req.headers.get('x-forwarded-for'),
  });
```

---

## 📊 监控和日志

### 查看函数日志

在 Supabase Dashboard 中：
1. 进入 **Edge Functions** 页面
2. 点击 `delete-account` 函数
3. 查看 **Logs** 标签

### 日志内容

函数会输出以下日志：
```
✅ 用户 <user_id> 请求删除账户
❌ 删除 profile 失败: <error>
✅ 用户 <user_id> 账户删除成功
❌ 删除用户失败: <error>
❌ 未知错误: <error>
```

---

## 🧪 测试

### 测试流程

1. **登录测试账号**
   ```swift
   await authManager.signIn(
       email: "test@example.com",
       password: "testpassword"
   )
   ```

2. **调用删除函数**
   ```swift
   try await authManager.deleteAccount()
   ```

3. **验证删除结果**
   - 检查用户是否被登出
   - 尝试重新登录（应该失败）
   - 检查数据库中的记录是否已删除

### 测试用例

#### 测试 1：成功删除

**步骤**：
1. 使用有效的 JWT token 调用函数
2. 验证返回 200 状态码
3. 验证响应包含成功信息

**预期结果**：
```json
{
  "success": true,
  "message": "账户已成功删除",
  "user_id": "xxx"
}
```

#### 测试 2：未登录调用

**步骤**：
1. 不提供 Authorization header
2. 调用函数

**预期结果**：
```json
{
  "error": "缺少 Authorization header"
}
```
状态码：401

#### 测试 3：无效 Token

**步骤**：
1. 提供无效的 JWT token
2. 调用函数

**预期结果**：
```json
{
  "error": "身份验证失败",
  "details": "..."
}
```
状态码：401

---

## 🔄 更新函数

如果需要修改函数逻辑，使用以下命令重新部署：

```bash
# 使用 Supabase CLI
supabase functions deploy delete-account

# 或使用 MCP 工具（在 Claude Code 中）
mcp__supabase__deploy_edge_function(
    project_id: "fbisbjxlwucmxgunkcxh",
    name: "delete-account",
    files: [...]
)
```

---

## 📞 故障排除

### 问题 1：调用函数返回 404

**原因**：函数未正确部署或 URL 错误

**解决方案**：
- 检查函数 URL 是否正确
- 确认函数状态为 ACTIVE
- 使用 `list_edge_functions` 查看函数列表

### 问题 2：返回 401 错误

**原因**：JWT token 无效或过期

**解决方案**：
- 重新登录获取新 token
- 检查 token 是否正确传递
- 确认用户会话未过期

### 问题 3：删除失败返回 500

**原因**：Service Role Key 未配置或数据库错误

**解决方案**：
- 检查 Supabase 环境变量
- 查看函数日志获取详细错误信息
- 确认用户在数据库中存在

---

## 🎉 总结

### 已部署功能

✅ **delete-account 边缘函数**
- 身份验证（JWT）
- 数据删除（profiles 表）
- 账户删除（auth.users）
- 错误处理
- CORS 支持

### 使用建议

1. **添加二次确认**：防止误操作
2. **发送确认邮件**：通知用户删除操作
3. **记录删除日志**：审计和安全
4. **添加冷静期**：给用户后悔的机会
5. **配置级联删除**：自动清理关联数据

### 后续优化

- ⏳ 添加软删除功能（标记删除，30天后真正删除）
- ⏳ 导出用户数据功能（GDPR 合规）
- ⏳ 删除前备份用户数据
- ⏳ 批量删除相关数据（territories、pois 等）

---

**部署时间**：2026-01-05 18:45
**函数版本**：v1
**项目**：地球新主 (EarthLord)
**开发者**：Claude Code
