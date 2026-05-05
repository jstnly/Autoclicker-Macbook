import Foundation

struct Settings: Codable, Equatable {
    var cps: Double = 10.0
    var mode: ClickMode = .followCursor
    var button: MouseButton = .left
    var points: [ClickPoint] = []
    var hotkey: HotkeyConfig = .default
    var jitterPercent: Double = 0.0
    var downUpGapMs: Int = 0
    var restoreCursorAfterCycle: Bool = false

    static let userDefaultsKey = "com.user.autoclicker.settings.v1"

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return Settings()
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Settings.userDefaultsKey)
    }
}
