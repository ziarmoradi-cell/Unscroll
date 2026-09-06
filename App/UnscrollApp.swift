import SwiftUI

@main
struct UnscrollApp: App {
    @StateObject private var model = UnscrollModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.70, green: 0.96, blue: 0.39))
        }
    }
}
