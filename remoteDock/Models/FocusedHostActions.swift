import SwiftUI

/// 把“按默认方式打开当前主机”的动作暴露给命令系统。
///
/// `FocusedValueKey` 可以理解成 SwiftUI 场景里的“上下文插槽定义”：
/// 先定义插槽，再由某个视图把值放进去，最后由菜单命令等上游位置读出来。
struct FocusedOpenSelectedHostActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

/// 把“Ping 当前主机”的动作暴露给命令系统。
struct FocusedPingSelectedHostActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

/// 暴露当前选中主机名称，便于动态生成菜单标题。
struct FocusedSelectedHostNameKey: FocusedValueKey {
    typealias Value = String
}

extension FocusedValues {
    /// 这几个计算属性让外部不需要直接接触 key 类型，
    /// 可以像访问普通属性一样读写当前场景中的 focused value。
    var openSelectedHost: (() -> Void)? {
        get { self[FocusedOpenSelectedHostActionKey.self] }
        set { self[FocusedOpenSelectedHostActionKey.self] = newValue }
    }

    var pingSelectedHost: (() -> Void)? {
        get { self[FocusedPingSelectedHostActionKey.self] }
        set { self[FocusedPingSelectedHostActionKey.self] = newValue }
    }

    var selectedHostName: String? {
        get { self[FocusedSelectedHostNameKey.self] }
        set { self[FocusedSelectedHostNameKey.self] = newValue }
    }
}
