//
//  CallsignSettingsSheet.swift
//  EarthLord
//
//  呼号设置页面
//  Day 36 实现
//

import SwiftUI
import Supabase

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var callsign = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    private let client = supabase

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 呼号说明区
                        explanationSection

                        Divider()

                        // 输入区
                        inputSection

                        // 保存按钮
                        saveButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle("呼号设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("设置成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("呼号已保存")
            }
            .onAppear {
                loadCurrentCallsign()
            }
        }
    }

    // MARK: - Explanation Section

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("什么是呼号？")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("呼号是你在通讯系统中的身份标识，类似于电台呼号。其他生存者会通过呼号识别你。")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 格式示例
            VStack(alignment: .leading, spacing: 8) {
                Text("格式示例：")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                ForEach(["Alpha-01", "Survivor-42", "Base-Omega", "Ranger-99"], id: \.self) { example in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        Text(example)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(12)
            .background(ApocalypseTheme.primary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("输入呼号")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            TextField("例如：Alpha-01", text: $callsign)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(validationColor, lineWidth: 1)
                )

            // 验证提示
            if !callsign.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: isValidCallsign ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValidCallsign ? .green : .red)

                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(isValidCallsign ? .green : .red)
                }
            }

            // 规则说明
            VStack(alignment: .leading, spacing: 4) {
                Text("呼号规则：")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                ruleItem(text: "长度 3-20 个字符")
                ruleItem(text: "仅包含字母、数字和连字符（-）")
                ruleItem(text: "不允许空格或特殊符号")
            }
            .padding(12)
            .background(ApocalypseTheme.textSecondary.opacity(0.1))
            .cornerRadius(8)

            // 错误信息
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: saveCallsign) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("保存呼号")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValidCallsign ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isValidCallsign || isLoading)
    }

    // MARK: - Helper Views

    private func ruleItem(text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ApocalypseTheme.textSecondary)
                .frame(width: 4, height: 4)

            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Computed Properties

    private var isValidCallsign: Bool {
        let trimmed = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 20 else { return false }

        let regex = "^[A-Za-z0-9-]+$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: trimmed)
    }

    private var validationMessage: String {
        if isValidCallsign {
            return "呼号格式正确"
        } else if callsign.count < 3 {
            return "呼号至少 3 个字符"
        } else if callsign.count > 20 {
            return "呼号最多 20 个字符"
        } else {
            return "仅允许字母、数字和连字符"
        }
    }

    private var validationColor: Color {
        if callsign.isEmpty {
            return ApocalypseTheme.textSecondary.opacity(0.3)
        }
        return isValidCallsign ? .green : .red
    }

    // MARK: - Methods

    /// 加载当前呼号
    private func loadCurrentCallsign() {
        guard let userId = authManager.currentUser?.id else { return }

        Task {
            do {
                struct UserProfile: Codable {
                    let callsign: String?
                }

                let response: [UserProfile] = try await client
                    .from("user_profiles")
                    .select("callsign")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                if let profile = response.first, let existingCallsign = profile.callsign {
                    await MainActor.run {
                        callsign = existingCallsign
                    }
                }
            } catch {
                print("❌ [CallsignSettings] 加载呼号失败: \(error)")
            }
        }
    }

    /// 保存呼号
    private func saveCallsign() {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                struct ProfileUpsert: Encodable {
                    let user_id: String
                    let callsign: String
                }

                let upsertData = ProfileUpsert(
                    user_id: userId.uuidString,
                    callsign: callsign.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                try await client
                    .from("user_profiles")
                    .upsert(upsertData)
                    .execute()

                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true
                }

                print("✅ [CallsignSettings] 呼号保存成功: \(callsign)")
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "保存失败: \(error.localizedDescription)"
                }
                print("❌ [CallsignSettings] 保存呼号失败: \(error)")
            }
        }
    }
}

#Preview {
    CallsignSettingsSheet()
        .environmentObject(AuthManager())
}
