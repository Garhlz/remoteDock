import SwiftUI

struct FocusedOpenSelectedHostActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct FocusedPingSelectedHostActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct FocusedSelectedHostNameKey: FocusedValueKey {
    typealias Value = String
}

extension FocusedValues {
    var openSelectedHost: (() -> Void)? {
        get { self[FocusedOpenSelectedHostActionKey.self] }
        set { self[FocusedOpenSelectedHostActionKey.self] = newValue }
    }

    var pingSelectedHost: (() -> Void)? {
        get { self[FocusedPingSelectedHostActionKey.self] }
        set { self[FocusedPingSelectedHostActionKey.self] = newValue }
    }

    var selectedHostName: String? {
        get { self[FocusedSelectedHostNameKey.self] }
        set { self[FocusedSelectedHostNameKey.self] = newValue }
    }
}
