import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum SidedModifierKey: String, Codable, CaseIterable, Comparable, Hashable {
    case leftShift, rightShift
    case leftControl, rightControl
    case leftOption, rightOption
    case leftCommand, rightCommand

    init?(keyCode: CGKeyCode) {
        switch keyCode {
        case 56: self = .leftShift
        case 60: self = .rightShift
        case 59: self = .leftControl
        case 62: self = .rightControl
        case 58: self = .leftOption
        case 61: self = .rightOption
        case 55: self = .leftCommand
        case 54: self = .rightCommand
        default: return nil
        }
    }

    var cgFlag: CGEventFlags {
        switch self {
        case .leftShift, .rightShift: return .maskShift
        case .leftControl, .rightControl: return .maskControl
        case .leftOption, .rightOption: return .maskAlternate
        case .leftCommand, .rightCommand: return .maskCommand
        }
    }

    var isPrimary: Bool {
        switch self {
        case .leftControl, .rightControl, .leftOption, .rightOption, .leftCommand, .rightCommand:
            return true
        case .leftShift, .rightShift:
            return false
        }
    }

    var isShift: Bool { cgFlag == .maskShift }

    var displayString: String {
        switch self {
        case .leftShift: return "L⇧"
        case .rightShift: return "R⇧"
        case .leftControl: return "L⌃"
        case .rightControl: return "R⌃"
        case .leftOption: return "L⌥"
        case .rightOption: return "R⌥"
        case .leftCommand: return "L⌘"
        case .rightCommand: return "R⌘"
        }
    }

    private var displayOrder: Int {
        switch self {
        case .leftControl: return 0
        case .rightControl: return 1
        case .leftOption: return 2
        case .rightOption: return 3
        case .leftShift: return 4
        case .rightShift: return 5
        case .leftCommand: return 6
        case .rightCommand: return 7
        }
    }

    static func < (lhs: SidedModifierKey, rhs: SidedModifierKey) -> Bool {
        lhs.displayOrder < rhs.displayOrder
    }

    static func flags(for modifiers: Set<SidedModifierKey>) -> CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { flags, modifier in
            flags.insert(modifier.cgFlag)
        }
    }

    static func sides(matching flags: CGEventFlags) -> Set<SidedModifierKey> {
        Set(allCases.filter { flags.contains($0.cgFlag) })
    }
}

/// User-rebindable keyboard binding.
struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt16
    /// CGEventFlags raw value of the modifier mask required for the binding.
    var modifiersRaw: UInt64
    /// Nil means legacy/generic modifiers. Non-nil stores exact left/right modifier keys.
    var sidedModifiers: Set<SidedModifierKey>? = nil

    var cgFlags: CGEventFlags { CGEventFlags(rawValue: modifiersRaw) }
    var isEmpty: Bool { keyCode == Self.modifierOnlyKeyCode && modifiersRaw == 0 }
    var isModifierOnly: Bool { keyCode == Self.modifierOnlyKeyCode && modifiersRaw != 0 }

    static let modifierOnlyKeyCode = UInt16.max
    static let empty = HotkeyBinding(keyCode: modifierOnlyKeyCode, modifiersRaw: 0)
    static let allModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
    static let primaryModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]

    static let defaultAllWindows = HotkeyBinding(
        keyCode: 48, // Tab
        modifiersRaw: CGEventFlags.maskCommand.rawValue
    )

    static let defaultCurrentApp = HotkeyBinding(
        keyCode: 50, // Backtick
        modifiersRaw: CGEventFlags.maskAlternate.rawValue
    )

    static let defaultAllWindowsForward = HotkeyBinding(
        keyCode: 48, // Tab
        modifiersRaw: 0
    )

    static let defaultAllWindowsBackward = HotkeyBinding(
        keyCode: 48, // Tab
        modifiersRaw: CGEventFlags.maskShift.rawValue
    )

    static let defaultCurrentAppForward = HotkeyBinding(
        keyCode: 50, // Backtick
        modifiersRaw: 0
    )

    static let defaultCurrentAppBackward = HotkeyBinding(
        keyCode: 50, // Backtick
        modifiersRaw: CGEventFlags.maskShift.rawValue
    )

    static func modifierOnly(_ flags: CGEventFlags) -> HotkeyBinding {
        HotkeyBinding(keyCode: modifierOnlyKeyCode, modifiersRaw: flags.rawValue)
    }

    static func modifierOnly(_ modifiers: Set<SidedModifierKey>) -> HotkeyBinding {
        HotkeyBinding(
            keyCode: modifierOnlyKeyCode,
            modifiersRaw: SidedModifierKey.flags(for: modifiers).rawValue,
            sidedModifiers: modifiers
        )
    }

    /// Whether the primary arming modifiers are still held.
    func modifiersHeld(_ flags: CGEventFlags, activeSidedModifiers: Set<SidedModifierKey>) -> Bool {
        if let sidedModifiers {
            let needed = Set(sidedModifiers.filter(\.isPrimary))
            return !needed.isEmpty && activeSidedModifiers.isSuperset(of: needed)
        }
        let needNeeded = cgFlags.intersection(Self.primaryModifiers)
        let havNeeded = flags.intersection(Self.primaryModifiers)
        return havNeeded.contains(needNeeded) && needNeeded.rawValue != 0
    }

    /// Match a keyDown trigger: required modifiers held, no extra primary modifiers, key matches.
    /// Shift is ignored so Shift-modified summon chords still arm the same mode.
    func matchesTrigger(keyCode: CGKeyCode, flags: CGEventFlags, activeSidedModifiers: Set<SidedModifierKey>) -> Bool {
        guard CGKeyCode(self.keyCode) == keyCode else { return false }
        if let sidedModifiers {
            return sidedModifiersMatch(sidedModifiers, active: activeSidedModifiers)
        }
        let needed = cgFlags.intersection(Self.allModifiers)
        if needed.contains(.maskShift) {
            return flags.intersection(Self.allModifiers) == needed
        }
        return flags.intersection(Self.primaryModifiers) == needed.intersection(Self.primaryModifiers)
    }

    var displayString: String {
        if let sidedModifiers {
            let modifiers = sidedModifiers.sorted().map(\.displayString).joined()
            if isModifierOnly || isEmpty { return modifiers }
            return modifiers + KeyName.string(for: keyCode)
        }
        var s = ""
        if cgFlags.contains(.maskControl) { s += "⌃" }
        if cgFlags.contains(.maskAlternate) { s += "⌥" }
        if cgFlags.contains(.maskShift) { s += "⇧" }
        if cgFlags.contains(.maskCommand) { s += "⌘" }
        if isModifierOnly || isEmpty { return s }
        s += KeyName.string(for: keyCode)
        return s
    }

    private func sidedModifiersMatch(_ required: Set<SidedModifierKey>, active: Set<SidedModifierKey>) -> Bool {
        if required.contains(where: \.isShift) {
            return active == required
        }
        let activePrimary = Set(active.filter { !$0.isShift })
        return activePrimary == required
    }
}

/// Persistent hotkey config. Singleton to allow lock-free reads from the event tap.
final class HotkeyConfig {
    static let shared = HotkeyConfig()

    private let defaults = UserDefaults.standard
    private let allKey = "switch.hotkey.allWindows"
    private let appKey = "switch.hotkey.currentApp"
    private let stickyKey = "switch.hotkey.stickyToggle"
    private let allForwardKey = "switch.hotkey.allWindows.forward"
    private let allBackwardKey = "switch.hotkey.allWindows.backward"
    private let appForwardKey = "switch.hotkey.currentApp.forward"
    private let appBackwardKey = "switch.hotkey.currentApp.backward"

    static let didChangeNotification = Notification.Name("com.sanyamgarg.switch.hotkeyConfigDidChange")

    private init() {}

    var allWindows: HotkeyBinding {
        get { load(allKey) ?? .defaultAllWindows }
        set { save(newValue, key: allKey) }
    }

    var currentApp: HotkeyBinding {
        get { load(appKey) ?? .defaultCurrentApp }
        set { save(newValue, key: appKey) }
    }

    var stickyToggle: HotkeyBinding? {
        get { load(stickyKey) }
        set {
            if let nv = newValue {
                save(nv, key: stickyKey)
            } else {
                defaults.removeObject(forKey: stickyKey)
                NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
            }
        }
    }

    var allWindowsForward: HotkeyBinding {
        get { load(allForwardKey) ?? .defaultAllWindowsForward }
        set { save(newValue, key: allForwardKey) }
    }

    var allWindowsBackward: HotkeyBinding {
        get { load(allBackwardKey) ?? .defaultAllWindowsBackward }
        set { save(newValue, key: allBackwardKey) }
    }

    var currentAppForward: HotkeyBinding {
        get { load(appForwardKey) ?? .defaultCurrentAppForward }
        set { save(newValue, key: appForwardKey) }
    }

    var currentAppBackward: HotkeyBinding {
        get { load(appBackwardKey) ?? .defaultCurrentAppBackward }
        set { save(newValue, key: appBackwardKey) }
    }

    func resetToDefaults() {
        defaults.removeObject(forKey: allKey)
        defaults.removeObject(forKey: appKey)
        defaults.removeObject(forKey: stickyKey)
        defaults.removeObject(forKey: allForwardKey)
        defaults.removeObject(forKey: allBackwardKey)
        defaults.removeObject(forKey: appForwardKey)
        defaults.removeObject(forKey: appBackwardKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func load(_ key: String) -> HotkeyBinding? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }

    private func save(_ b: HotkeyBinding, key: String) {
        if let data = try? JSONEncoder().encode(b) {
            defaults.set(data, forKey: key)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}

/// Reserved combos we refuse to rebind onto (would break the system or the user's other shortcuts).
enum HotkeyValidator {
    private static let reserved: [(keyCode: UInt16, flags: CGEventFlags)] = [
        (12, .maskCommand),  // ⌘Q
        (13, .maskCommand),  // ⌘W
        (1,  .maskCommand),  // ⌘S
        (8,  .maskCommand),  // ⌘C
        (9,  .maskCommand),  // ⌘V
        (7,  .maskCommand),  // ⌘X
        (6,  .maskCommand),  // ⌘Z
        (15, .maskCommand),  // ⌘R
        (3,  .maskCommand),  // ⌘F
        (53, [])             // bare Esc
    ]

    /// Returns nil if the combo is allowed; otherwise a short human reason.
    static func reject(keyCode: UInt16, flags: CGEventFlags) -> String? {
        let mask: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let cleaned = flags.intersection(mask)
        if cleaned.intersection([.maskCommand, .maskAlternate, .maskControl]).rawValue == 0 {
            return "Needs at least one modifier (⌘, ⌥, or ⌃)."
        }
        for (rk, rf) in reserved where rk == keyCode && rf == cleaned {
            return "That combo is reserved by macOS or common apps."
        }
        return nil
    }
}

enum NavigationKeyValidator {
    private static let reservedKeyCodes: Set<UInt16> = [
        53, // Esc
        36, // Return
        76  // Enter
    ]

    static func reject(keyCode: UInt16, flags: CGEventFlags) -> String? {
        let mask: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let cleaned = flags.intersection(mask)
        if keyCode == HotkeyBinding.modifierOnlyKeyCode {
            return cleaned.rawValue == 0 ? "Press a key or modifier." : nil
        }
        if reservedKeyCodes.contains(keyCode) {
            return "That key is reserved while the picker is open."
        }
        return nil
    }
}

enum KeyName {
    /// Human-readable key name (single char where possible, "Tab" / "F1" etc otherwise).
    static func string(for code: UInt16) -> String {
        if let s = special[code] { return s }
        // Fall back to NSEvent.charactersByApplyingModifiers for printable keys.
        if let cs = chars(for: code) { return cs.uppercased() }
        return "Key \(code)"
    }

    private static let special: [UInt16: String] = [
        48: "Tab",
        49: "Space",
        50: "`",
        53: "Esc",
        36: "Return",
        76: "Enter",
        51: "Delete",
        117: "Fwd Del",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    private static func chars(for code: UInt16) -> String? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> OSStatus in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return -1
            }
            return UCKeyTranslate(
                base,
                code,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
