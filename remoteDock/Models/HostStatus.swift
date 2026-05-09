//
//  HostStatus.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

/// 主机连通性在界面中的展示状态。
///
/// 这是一个纯 UI 语义层状态，不直接等同于网络协议状态。
/// 例如 `checking` 只是表示“界面正在等待一次 ping 结果”，
/// 而不是远端主机返回了某种正式协议状态码。
enum HostStatus: String {
    case unknown = "Not checked"
    case checking = "Checking..."
    case online = "Online"
    case offline = "Offline"

    /// 每种状态在界面中的主色，用于圆点、文字和 badge 背景。
    var color: Color {
        switch self {
        case .unknown:
            .secondary
        case .checking:
            .orange
        case .online:
            .green
        case .offline:
            .red
        }
    }

    /// 每种状态对应的 SF Symbols 图标。
    var systemImage: String {
        switch self {
        case .unknown:
            "circle"
        case .checking:
            "clock"
        case .online:
            "checkmark.circle.fill"
        case .offline:
            "xmark.circle.fill"
        }
    }
}
