import Foundation

public struct JoinPlan: Equatable, Sendable {
    public let primary: URL
    public let fallback: URL?

    public init(primary: URL, fallback: URL?) {
        self.primary = primary
        self.fallback = fallback
    }
}

public enum JoinPlanner {
    public static func plan(for link: MeetingLink, accountEmail: String?) -> JoinPlan {
        switch link.service {
        case .zoom: return zoomPlan(link.url)
        case .googleMeet: return meetPlan(link.url, accountEmail: accountEmail)
        case .teams: return teamsPlan(link.url)
        }
    }

    private static func zoomPlan(_ url: URL) -> JoinPlan {
        let httpsOnly = JoinPlan(primary: url, fallback: nil)
        guard url.scheme?.lowercased() == "https",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host,
              !host.lowercased().contains("zoomgov")
        else { return httpsOnly }

        let parts = components.path.split(separator: "/")
        guard parts.count >= 2,
              ["j", "w"].contains(parts[0].lowercased()),
              !parts[1].isEmpty,
              parts[1].allSatisfy({ $0.isASCII && $0.isNumber })
        else { return httpsOnly }

        var native = URLComponents()
        native.scheme = "zoommtg"
        native.host = host
        native.path = "/join"
        var items = [URLQueryItem(name: "action", value: "join"), URLQueryItem(name: "confno", value: String(parts[1]))]
        if let pwd = components.queryItems?.first(where: { $0.name == "pwd" })?.value, !pwd.isEmpty {
            items.append(URLQueryItem(name: "pwd", value: pwd))
        }
        native.queryItems = items
        guard let nativeURL = native.url else { return httpsOnly }
        return JoinPlan(primary: nativeURL, fallback: url)
    }

    private static func meetPlan(_ url: URL, accountEmail: String?) -> JoinPlan {
        guard let accountEmail, !accountEmail.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return JoinPlan(primary: url, fallback: nil) }
        var items = (components.queryItems ?? []).filter { $0.name != "authuser" }
        items.append(URLQueryItem(name: "authuser", value: accountEmail))
        components.queryItems = items
        return JoinPlan(primary: components.url ?? url, fallback: nil)
    }

    private static func teamsPlan(_ url: URL) -> JoinPlan {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return JoinPlan(primary: url, fallback: nil)
        }
        components.scheme = "msteams"
        return JoinPlan(primary: components.url ?? url, fallback: url)
    }
}
