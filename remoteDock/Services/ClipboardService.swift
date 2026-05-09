//
//  ClipboardService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit

/// 统一封装系统剪贴板写入。
///
/// 虽然这里只有两行代码，但单独抽出来有两个好处：
/// 1. 视图层不需要直接依赖 `NSPasteboard`；
/// 2. 将来如果要增加复制格式、日志或测试替身，会有稳定入口。
enum ClipboardService {
    static func copy(_ text: String) {
        /// 先清空再写入纯文本，避免旧内容或多类型粘贴板条目干扰结果。
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
