import Foundation

public enum SSHURLBuilder {
    public static func url(for host: RemoteHost) -> URL? {
        var components = URLComponents()
        components.scheme = "ssh"
        components.user = host.username
        components.host = host.address
        components.port = host.port
        return components.url
    }
}
