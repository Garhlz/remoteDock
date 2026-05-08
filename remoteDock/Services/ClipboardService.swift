//
//  ClipboardService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit

enum ClipboardService {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
