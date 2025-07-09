import SwiftUI
import TWS

@main
struct SampleApp: App {
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .twsRegister(configuration: TWSBasicConfiguration(id: "<TWS_PROJECT>"))
                .onAppear {
                    UIPageControl.appearance().currentPageIndicatorTintColor = .red
                    UIPageControl.appearance().pageIndicatorTintColor = UIColor.red.withAlphaComponent(0.2)
                }
        }
    }
}
