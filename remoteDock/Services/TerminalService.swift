//
//  TerminalService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit
import Foundation
import RemoteDockCore

/// 负责通过 Ghostty 的 AppleScript 自动化打开 SSH 会话。
///
/// 这层存在的原因是：SwiftUI 视图本身不应该直接拼装系统进程和 AppleScript。
/// 视图只表达“我要打开 SSH”，而这里负责把这个意图翻译成 macOS 能执行的自动化命令。
enum TerminalService {
    enum Error: LocalizedError {
        case ghosttyNotInstalled
        case automationPermissionDenied
        case automationFailed(output: String?, exitCode: Int32)
        case processError(String)

        /// 错误文案会直接进入页面反馈条，所以这里尽量使用“下一步可行动”的表述。
        var errorDescription: String? {
            switch self {
            case .ghosttyNotInstalled:
                "Ghostty is not installed. Install Ghostty first, or use Copy SSH instead."
            case .automationPermissionDenied:
                """
                RemoteDock is not allowed to control Ghostty yet.
                Open System Settings > Privacy & Security > Automation, then allow RemoteDock to control Ghostty.
                """
            case .automationFailed(let output, let exitCode):
                if let output, !output.isEmpty {
                    "Ghostty automation failed: \(output)"
                } else {
                    "Ghostty automation failed with exit code \(exitCode)."
                }
            case .processError(let description):
                "Unable to automate Ghostty: \(description)"
            }
        }
    }

    private static let ghosttyBundleIdentifier = "com.mitchellh.ghostty"

    /// 打开链路：
    /// 1. 先确认 Ghostty 是否已安装；
    /// 2. 生成 AppleScript 参数；
    /// 3. 调用 `osascript` 执行；
    /// 4. 将脚本失败翻译成更友好的错误信息。
    ///
    /// 这一层最难的边界不是“SSH 命令对不对”，而是 macOS 自动化权限：
    /// 即使命令本身没问题，用户第一次调用时也可能被系统权限拦住。
    static func openSSHSession(for host: RemoteHost) -> Error? {
        guard isGhosttyInstalled else {
            return .ghosttyNotInstalled
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = appleScriptArguments(for: host)
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

                if let output {
                    if isAutomationPermissionError(output) {
                        return .automationPermissionDenied
                    }
                }

                return .automationFailed(output: output, exitCode: process.terminationStatus)
            }

            return nil
        } catch {
            return .processError(error.localizedDescription)
        }
    }

    /// 通过 bundle identifier 查找应用，而不是假设它安装在固定路径。
    private static var isGhosttyInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: ghosttyBundleIdentifier) != nil
    }

    /// 根据 Ghostty 当前是否已运行，生成两套略有不同的 AppleScript。
    /// 已运行时直接新开窗口；未运行时先激活应用，再等待前台窗口可用。
    ///
    /// 之所以要分支处理，是因为很多终端应用在“尚未启动”时还没有可操作的窗口对象；
    /// 如果直接复用运行中脚本，AppleScript 往往会在窗口引用阶段失败。
    private static func appleScriptArguments(for host: RemoteHost) -> [String] {
        let sshCommand = SSHCommandBuilder.command(for: host)
        let isGhosttyRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: ghosttyBundleIdentifier)
            .isEmpty

        if isGhosttyRunning {
            return [
                "-e",
                "tell application \"Ghostty\" to set win to new window",
                "-e",
                "tell application \"Ghostty\" to set term to focused terminal of selected tab of win",
                "-e",
                "tell application \"Ghostty\" to input text \(appleScriptQuoted(sshCommand)) to term",
                "-e",
                "tell application \"Ghostty\" to send key \"enter\" to term"
            ]
        }

        return [
            "-e",
            "tell application \"Ghostty\" to activate",
            "-e",
            "delay 0.2",
            "-e",
            "tell application \"Ghostty\" to set term to focused terminal of selected tab of front window",
            "-e",
            "tell application \"Ghostty\" to input text \(appleScriptQuoted(sshCommand)) to term",
            "-e",
            "tell application \"Ghostty\" to send key \"enter\" to term"
        ]
    }

    /// 对 shell 命令中的反斜杠和双引号做转义，避免注入到 AppleScript 字符串时破坏语法。
    private static func appleScriptQuoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    /// 识别常见的 Apple Events 权限报错，方便在 UI 上给出明确指引。
    ///
    /// 这里做关键字识别，而不是只看退出码，
    /// 是因为 `osascript` 在不同系统版本下返回的权限失败文本并不完全一致。
    private static func isAutomationPermissionError(_ output: String) -> Bool {
        output.contains("-1743") ||
        output.localizedCaseInsensitiveContains("Not authorized to send Apple events") ||
        output.localizedCaseInsensitiveContains("not allowed assistive access") ||
        output.localizedCaseInsensitiveContains("automation")
    }
}
