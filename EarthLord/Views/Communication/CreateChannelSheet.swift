//
//  CreateChannelSheet.swift
//  EarthLord
//
//  创建频道页面
//  允许用户创建新的通讯频道
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedType: ChannelType = .public
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false

    // 可创建的频道类型（排除 official）
    private let creatableTypes: [ChannelType] = [.public, .walkie, .camp, .satellite]

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    channelTypeSection

                    // 频道名称
                    channelNameSection

                    // 频道描述
                    channelDescriptionSection

                    // 创建按钮
                    createButton

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Channel Type Section

    private var channelTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("频道类型")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(creatableTypes, id: \.self) { type in
                    ChannelTypeCard(
                        type: type,
                        isSelected: selectedType == type,
                        isAvailable: isTypeAvailable(type)
                    )
                    .onTapGesture {
                        if isTypeAvailable(type) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedType = type
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Channel Name Section

    private var channelNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道名称")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(channelName.count)/50")
                    .font(.caption)
                    .foregroundColor(isNameValid ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)
            }

            TextField("输入频道名称（2-50字符）", text: $channelName)
                .textFieldStyle(ApocalypseTextFieldStyle())
                .onChange(of: channelName) { _, newValue in
                    if newValue.count > 50 {
                        channelName = String(newValue.prefix(50))
                    }
                }

            if !channelName.isEmpty && channelName.count < 2 {
                Text("频道名称至少需要2个字符")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
    }

    // MARK: - Channel Description Section

    private var channelDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道描述")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("（可选）")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(channelDescription.count)/200")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            TextEditor(text: $channelDescription)
                .frame(height: 100)
                .padding(8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .onChange(of: channelDescription) { _, newValue in
                    if newValue.count > 200 {
                        channelDescription = String(newValue.prefix(200))
                    }
                }
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: createChannel) {
            HStack {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                Text(isCreating ? "创建中..." : "创建频道")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreate || isCreating)
    }

    // MARK: - Validation

    private var isNameValid: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    private var canCreate: Bool {
        isNameValid && isTypeAvailable(selectedType)
    }

    private func isTypeAvailable(_ type: ChannelType) -> Bool {
        guard let requiredDevice = type.requiredDevice else {
            return true
        }
        return manager.isDeviceUnlocked(requiredDevice)
    }

    // MARK: - Actions

    private func createChannel() {
        guard let userId = authManager.currentUser?.id else { return }

        isCreating = true

        Task {
            let result = await manager.createChannel(
                userId: userId,
                channelType: selectedType,
                name: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: channelDescription.isEmpty ? nil : channelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            isCreating = false

            if result != nil {
                dismiss()
            }
        }
    }
}

// MARK: - Channel Type Card

struct ChannelTypeCard: View {
    let type: ChannelType
    let isSelected: Bool
    let isAvailable: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(typeColor.opacity(isAvailable ? 0.2 : 0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: type.iconName)
                    .font(.title2)
                    .foregroundColor(isAvailable ? typeColor : ApocalypseTheme.textSecondary.opacity(0.5))
            }

            Text(type.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isAvailable ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary.opacity(0.5))

            Text(type.description)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !isAvailable {
                Text("需解锁设备")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.warning)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? typeColor : Color.clear, lineWidth: 2)
                )
        )
        .opacity(isAvailable ? 1 : 0.6)
    }

    private var typeColor: Color {
        switch type {
        case .official: return .yellow
        case .public: return .green
        case .walkie: return .blue
        case .camp: return .orange
        case .satellite: return .purple
        }
    }
}

// MARK: - Custom TextField Style

struct ApocalypseTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .foregroundColor(ApocalypseTheme.textPrimary)
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager())
}
