import Foundation

/// 负责生成默认终端使用的 `ssh://` URL。
///
/// 这个 builder 很小，但职责单一明确：
/// 把 `RemoteHost` 的 username / address / port 安全装配成 URL 结构，
/// 让 `DefaultTerminalService` 不必自己处理 URL 拼装细节。
public enum SSHURLBuilder {
    /// 根据主机配置构造 `ssh://user@host[:port]` URL。
    public static func url(for host: RemoteHost) -> URL? {
        var components = URLComponents()
        components.scheme = "ssh"
        components.user = host.username
        components.host = host.address
        components.port = host.port
        return components.url
    }
}
