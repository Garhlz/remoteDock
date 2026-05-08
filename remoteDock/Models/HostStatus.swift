//
//  HostStatus.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

enum HostStatus: String {
    case unknown = "Not checked"
    case checking = "Checking..."
    case online = "Online"
    case offline = "Offline"

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
