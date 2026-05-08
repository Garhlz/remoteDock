//
//  RemoteHost.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import Foundation

struct RemoteHost: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let username: String
    let address: String

    init(id: UUID = UUID(), name: String, username: String, address: String) {
        self.id = id
        self.name = name
        self.username = username
        self.address = address
    }

    var sshCommand: String {
        "ssh \(username)@\(address)"
    }

    var displayAddress: String {
        "\(username)@\(address)"
    }
}
