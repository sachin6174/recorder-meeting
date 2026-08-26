import Foundation

final class WeatherService: @unchecked Sendable {
    static let shared = WeatherService()

    private(set) var currentWeather: String = "Weather: Loading..."
    private var lastFetch: Date?
    private var isFetching = false

    init() {
        fetchWeather()
    }

    func fetchWeather(force: Bool = false) {
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < 300 {
            return
        }
        guard !isFetching else { return }
        isFetching = true

        Task {
            defer { self.isFetching = false }
            do {
                guard let url = URL(string: "https://wttr.in/?format=%l:+%c+%t") else { return }
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                request.setValue("curl/8.0.0", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else {
                    return
                }

                let clean = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
                DispatchQueue.main.async {
                    self.currentWeather = clean
                    self.lastFetch = Date()
                }
            } catch {
                DispatchQueue.main.async {
                    if self.lastFetch == nil {
                        self.currentWeather = "Weather: Unavailable"
                    }
                }
            }
        }
    }
}
