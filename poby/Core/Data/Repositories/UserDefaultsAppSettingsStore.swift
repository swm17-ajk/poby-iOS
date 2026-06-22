import Foundation

final class UserDefaultsAppSettingsStore {
    private enum Keys {
        static let settings = "poby.appSettings"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: Keys.settings),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .defaults
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Keys.settings)
    }

    func markOnboardingCompleted() {
        var settings = load()
        settings.hasCompletedOnboarding = true
        save(settings)
    }

    func completeTutorial() {
        var settings = load()
        if !settings.hasSeenTutorialDetail {
            settings.pendingOpenAddGuideDialog = true
        }
        settings.hasCompletedOnboarding = true
        settings.hasSeenTutorialDetail = true
        save(settings)
    }

    func consumePendingOpenAddGuideDialog() -> Bool {
        var settings = load()
        let pending = settings.pendingOpenAddGuideDialog
        settings.pendingOpenAddGuideDialog = false
        save(settings)
        return pending
    }
}
