import Foundation

/// `dodu://` links from widgets, the Live Activity and Quick Add; the app does the writing.
enum DeepLink: String {
    case toggleTimer = "dodu://timer/toggle"
    case today = "dodu://today"
    case tasks = "dodu://tasks"

    var url: URL { URL(string: rawValue)! }

    init?(_ url: URL) { self.init(rawValue: url.absoluteString) }
}
