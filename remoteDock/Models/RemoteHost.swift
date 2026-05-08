//
//  RemoteHost.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import Foundation

struct RemoteHost: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let address: String

    var sshCommand: String {
        "ssh \(username)@\(address)"
    }

    var displayAddress: String {
        "\(username)@\(address)"
    }
}
