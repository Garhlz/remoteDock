//
//  VSCodeService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit
import Foundation
import RemoteDockCore

/// 负责调用 VS Code CLI 打开 Remote SSH 工作区。
///
/// 和终端服务类似，这里把“用 VS Code 打开远程目录”封装成一个独立系统服务，
/// 让视图层不需要了解 `code --remote ...` 这些实现细节。
enum VSCodeService {
    enum Error: LocalizedError {
        case notInstalled
        case launchFailed(output: String?)
        case processError(String)

        /// 与终端服务一样，这里的错误文案会直接面向用户，而不是只给开发者看。
        var errorDescription: String? {
            switch self {
            case .notInstalled:
                "Visual Studio Code is not installed."
            case .launchFailed(let output):
                if let output, !output.isEmpty {
                    "Unable to launch Visual Studio Code: \(output)"
                } else {
                    "Unable to launch Visual Studio Code."
                }
            case .processError(let description):
                "Unable to launch Visual Studio Code: \(description)"
            }
        }
    }

    /// 打开链路：
    /// 1. 找到本机可用的 `code` 或 `code-insiders` 可执行文件；
    /// 2. 组装 Remote SSH 参数；
    /// 3. 启动子进程；
    /// 4. 如果 CLI 返回非 0，则把输出转成错误消息。
    ///
    /// 这里并不直接调用 `open -a "Visual Studio Code"`，
    /// 因为 Remote SSH 需要 CLI 参数才能把“目标主机 + 远端目录”一起传进去。
    static func openRemoteFolder(for host: RemoteHost) -> Error? {
        guard let cli = availableCLI else {
            return .notInstalled
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = cli.executableURL
        process.arguments = [
            "--new-window",
            "--remote",
            "ssh-remote+\(host.sshAuthority)",
            host.vscodeRemoteDirectory
        ]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let output = String(
                    data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines)

                return .launchFailed(output: output)
            }

            return nil
        } catch {
            return .processError(error.localizedDescription)
        }
    }

    /// 这里只保留当前实现真正需要的信息：CLI 的可执行路径。
    private struct VSCodeCLI {
        let executableURL: URL
    }

    private static let cliCandidates: [(bundleIdentifier: String, executableName: String)] = [
        ("com.microsoft.VSCode", "code"),
        ("com.microsoft.VSCodeInsiders", "code-insiders")
    ]

    /// 依次尝试 Stable 和 Insiders 两种安装形式，谁存在就用谁。
    ///
    /// 这里优先通过 Bundle Identifier 找应用，再拼出内部 CLI 路径，
    /// 比直接假设 `/usr/local/bin/code` 存在更稳，因为很多用户并没有手动安装 shell command。
    private static var availableCLI: VSCodeCLI? {
        cliCandidates.lazy.compactMap { candidate in
            guard let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: candidate.bundleIdentifier
            ) else {
                return nil
            }

            let executableURL = appURL
                .appendingPathComponent("Contents/Resources/app/bin", isDirectory: true)
                .appendingPathComponent(candidate.executableName, isDirectory: false)

            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                return nil
            }

            return VSCodeCLI(executableURL: executableURL)
        }
        .first
    }
}
