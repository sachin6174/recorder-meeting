import Foundation

final class WeatherService: @unchecked Sendable {
    static let shared = WeatherService()

    private(set) var chandigarhWeather: String = "Chandigarh: ⛅ Loading..."
    private(set) var karnatakaWeather: String = "Karnataka: 🌦️ Loading..."
    private var lastFetch: Date?
    private var isFetching = false

    init() {
        fetchWeather()
    }

    func weather(forRecording isRecording: Bool) -> String {
        return isRecording ? karnatakaWeather : chandigarhWeather
    }

    func fetchWeather(force: Bool = false) {
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < 300 {
            return
        }
        guard !isFetching else { return }
        isFetching = true

        Task {
            defer { self.isFetching = false }
            async let chd = self.fetchLocation("Chandigarh")
            async let kar = self.fetchLocation("Karnataka")

            let (chdResult, karResult) = await (chd, kar)

            DispatchQueue.main.async {
                if let chdResult {
                    self.chandigarhWeather = chdResult
                }
                if let karResult {
                    self.karnatakaWeather = karResult
                }
                self.lastFetch = Date()
            }
        }
    }

    private func fetchLocation(_ location: String) async -> String? {
        guard let url = URL(string: "https://wttr.in/\(location)?format=%l:+%c+%t") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("curl/8.0.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        } catch {
            return nil
        }
    }
}
