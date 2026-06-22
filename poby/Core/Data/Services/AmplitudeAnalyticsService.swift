import Foundation
import AmplitudeSwift

final class AmplitudeAnalyticsService: AnalyticsService {
    private let amplitude: Amplitude?

    init(apiKey: String = AppAnalyticsConfig.amplitudeAPIKey) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            #if DEBUG
            print("[Analytics] Amplitude disabled: API key is empty")
            #endif
            self.amplitude = nil
            return
        }

        #if DEBUG
        print("[Analytics] Amplitude enabled: API key suffix \(trimmedAPIKey.suffix(4))")
        #endif

        self.amplitude = Amplitude(
            configuration: Configuration(
                apiKey: trimmedAPIKey,
                flushQueueSize: 1,
                flushIntervalMillis: 1_000,
                autocapture: [.sessions, .appLifecycles]
            )
        )
    }

    func log(_ event: String, properties: [String: Any]? = nil) {
        #if DEBUG
        print("[Analytics]", event, properties ?? [:])
        #endif
        amplitude?
            .track(eventType: event, eventProperties: properties)
            .flush()
    }
}
