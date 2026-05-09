import SwiftUI
import RemoteDockCore

/// 用于管理主机分组的弹窗视图。
///
/// 和主机编辑器类似，这里也采用“草稿副本”策略：
/// 先把外部传入的 `groups` 复制到 `draftGroups`，
/// 用户在弹窗中的所有增删改排都先只改草稿，
/// 直到点击 Save 才一次性提交给上层。
struct GroupManagerView: View {
    let groups: [HostGroup]
    let hostCounts: [UUID: Int]
    let save: ([HostGroup]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftGroups: [HostGroup]
    @State private var newGroupName = ""
    @State private var validationMessage: String?

    /// 初始化时把输入分组复制到本地草稿，避免用户按 Cancel 时污染外部状态。
    init(groups: [HostGroup], hostCounts: [UUID: Int], save: @escaping ([HostGroup]) -> Void) {
        self.groups = groups
        self.hostCounts = hostCounts
        self.save = save
        _draftGroups = State(initialValue: groups)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Manage Groups")
                .font(.title2.bold())

            HStack(spacing: 10) {
                TextField("New group name", text: $newGroupName)

                Button("Add") {
                    addGroup()
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            /// 空状态和列表态分开处理，让第一次使用分组功能的用户也知道下一步该做什么。
            if draftGroups.isEmpty {
                ContentUnavailableView(
                    "No Groups",
                    systemImage: "folder.badge.plus",
                    description: Text("Create a group to organize hosts in the sidebar.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    /// 使用 `enumerated()` 是因为这里既需要 group 本身，也需要当前位置来支持上移/下移。
                    ForEach(Array(draftGroups.enumerated()), id: \.element.id) { index, group in
                        HStack(spacing: 10) {
                            TextField(
                                "Group Name",
                                text: Binding(
                                    get: { draftGroups[index].name },
                                    set: { draftGroups[index] = draftGroups[index].withName($0) }
                                )
                            )

                            Spacer(minLength: 8)

                            Text(hostCountText(for: group))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                moveGroup(at: index, by: -1)
                            } label: {
                                Image(systemName: "arrow.up")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)
                            .help("Move group up")

                            Button {
                                moveGroup(at: index, by: 1)
                            } label: {
                                Image(systemName: "arrow.down")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == draftGroups.count - 1)
                            .help("Move group down")

                            Button(role: .destructive) {
                                draftGroups.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete group")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    saveGroups()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: 420)
    }

    /// 新建分组时先做 trim，再做大小写不敏感去重。
    private func addGroup() {
        let trimmedName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        guard !draftGroups.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) else {
            validationMessage = "A group with this name already exists."
            return
        }

        draftGroups.append(HostGroup(name: trimmedName))
        newGroupName = ""
        validationMessage = nil
    }

    /// 分组排序通过交换数组元素实现；sidebar 会天然继承这个顺序。
    private func moveGroup(at index: Int, by offset: Int) {
        let destinationIndex = index + offset
        guard draftGroups.indices.contains(destinationIndex) else {
            return
        }

        draftGroups.swapAt(index, destinationIndex)
    }

    /// 保存前做两类校验：
    /// - 不能为空
    /// - 名称去掉大小写差异后必须唯一
    private func saveGroups() {
        let normalizedNames = draftGroups.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard normalizedNames.allSatisfy({ !$0.isEmpty }) else {
            validationMessage = "Group names cannot be empty."
            return
        }

        let loweredNames = normalizedNames.map(\.localizedLowercase)
        guard Set(loweredNames).count == loweredNames.count else {
            validationMessage = "Group names must be unique."
            return
        }

        save(draftGroups.map { $0.withName($0.name) })
        dismiss()
    }

    /// 用于在列表里提示每个分组当前挂了多少台主机，帮助用户谨慎删除。
    private func hostCountText(for group: HostGroup) -> String {
        let count = hostCounts[group.id, default: 0]
        return count == 1 ? "1 host" : "\(count) hosts"
    }
}
