import SwiftUI

@main
struct ClinicalTrialHealthApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(onReplaySplash: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = true
                    }
                })

                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
