import Foundation

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home

    func open(_ tab: AppTab) {
        selectedTab = tab
    }
}

enum AppTab: Hashable {
    case home
    case scanner
    case tailoring
    case tracker
    case settings
}

enum CVRoute: Hashable {
    case onboarding
    case atsDetails
    case interviewPrep
    case paywall
}
