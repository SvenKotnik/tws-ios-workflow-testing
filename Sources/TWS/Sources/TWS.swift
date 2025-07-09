import Foundation
import SwiftUI
import Combine
@_exported import TWSModels
internal import TWSCore
internal import ComposableArchitecture
internal import TWSLogger
internal import TWSSnippets
internal import TWSSnippet

/// A class that manages all communication between your app and the TWS portal. It handles the state and updates of snippets and provides various methods for interacting with the SDK.
///
/// ## Initialization
///
/// You can create an instance of the manager by using the ``TWSFactory/new(with:)`` method on the ``TWSFactory``, manager created this way still needs to be registered with ``registerManager()``, to connect it with remote services.
///
/// Alternatively, you can utilize SwiftUI View extension ``SwiftUICore/View/twsRegister(configuration:)``. This extension creates the manager internally using the factory and injects it into the view hierarchy and registers it with remote services.
///
/// > Note: You are responsible for keeping the instance alive. When using the SwiftUI extension, the instance will remain alive as long as the view is active.
///
/// ## Displaying Snippets
///
/// To iterate over and observe the snippets, use the ``TWSManager/snippets`` property. Leverage the ``TWSView`` to display them in your SwiftUI views.
///
/// ```swift
/// import SwiftUI
/// import TWS
///
/// struct HomeView: View {
///
///     @Environment(TWSManager.self) var tws
///
///     var  body: some View {
///         TabView {
///             ForEach(tws.snippets()) { snippet in
///                 TWSView(snippet: snippet)
///             }
///         }
///     }
/// }
/// ```
@MainActor
@Observable
public final class TWSManager: Identifiable {

    /// The configuration object used to initialize the manager.
    public let configuration: any TWSConfiguration

    /// A property that provides access to the list of loaded snippets and their current loading state.
    ///
    /// The snippets are wrapped in a ``TWSOutcome`` object, which contains:
    /// - `items`: The current list of snippets.
    /// - `state`: The loading state of the snippets, represented by ``TWSLoadingState``.
    ///
    /// Use this property to observe changes to the snippets or their state, and to display them in the UI.
    public internal(set) var snippets: TWSOutcome<[TWSSnippet]>

    let observer: AnyPublisher<TWSStreamEvent, Never>
    let store: StoreOf<TWSCoreFeature>
    let snippetHeightProvider: SnippetHeightProvider
    let navigationProvider: NavigationProvider

    private let initDate: Date
    private let _id = UUID().uuidString.suffix(4)
    private var _stateSync: AnyCancellable?
    private var isSetup = false
    private var isRegistered = false

    init(
        store: StoreOf<TWSCoreFeature>,
        observer: AnyPublisher<TWSStreamEvent, Never>,
        configuration: any TWSConfiguration
    ) {
        self.store = store
        self.observer = observer.share().eraseToAnyPublisher()
        self.configuration = configuration
        self.initDate = Date()
        self.snippetHeightProvider = SnippetHeightProviderImpl()
        self.navigationProvider = NavigationProviderImpl()

        let items = store.snippets.snippets.elements.map(\.snippet)
        let state = store.snippets.state
        self.snippets = .init(
            items: items,
            state: state
        )

        logger.info("INIT TWSManager \(_id)")
    }
    
    public func registerManager() {
        if !isRegistered {
            logger.info("TWSManager \(_id) registered with remote services")
            _syncState()
            _run()
            isRegistered = true
        }
    }

    deinit {
        logger.info("DEINIT TWSManager \(_id)")
        MainActor.assumeIsolated { TWSFactory.destroy(configuration: configuration) }
    }

    // MARK: - Public

    /// Triggers a manual refresh of the snippets, forcing them to reload from the source.
    public func forceRefresh() {
        store.send(.snippets(.business(.load)))
    }
    
    
    /// Sends a custom event to remote services, searching for corresponding snippets.
    /// - Parameter event: name of an event, that can be assosiated with snippets.
    ///
    /// When this function is called with a new event for the first time, the event will become visible in your projects web portal dashboard.
    /// Afterwards if this function is called and a snippet is assosiated with it, the snippet will be opened as a full screen overlay.
    public func logEvent(_ event: String) {
        guard isRegistered else {
            logger.warn("Log Event ignored, TWSManager is not registered with remote services.")
            return
        }
        
        store.send(.snippets(.business(.sendTrigger(event))))
    }

    /// Starts listening for updates from the SDK. This method provides a callback that is triggered for each event.
    ///
    /// - Parameter onEvent: A callback function executed on the main thread for every event update.
    ///
    /// To start observing events:
    ///
    /// ```swift
    /// ZStack {
    ///     ...
    /// }
    /// // Bind it to the lifetime of the view
    /// .task {
    ///    await twsManager.observe() { event in
    ///     switch event {
    ///         ...
    ///     }
    ///    }
    /// }
    /// ```
    ///
    /// > note: If you only need to listen for updates to snippets, you can use ``TWSManager/snippets`` instead.
    ///
    /// ## Cancellation
    ///
    /// Automatically stops listening when the parent task is canceled. For event types, see the ``TWSStreamEvent`` enum.
    ///
    public func observe(onEvent: @MainActor @Sendable @escaping (TWSStreamEvent) -> Void) async {
        precondition(Thread.isMainThread, "`observe` can only be called on main thread")
        let adapter = CombineToAsyncStreamAdapter(upstream: observer)
        await adapter.listen(onEvent: onEvent)
    }

    /// Adds a custom set of local properties to a specific snippet. This will affect all views displaying the snippet.
    ///
    /// - Parameters:
    ///   - localProps: A dictionary containing the local properties to inject.
    ///   - id: The identifier of the snippet to associate with this dictionary.
    ///
    /// This method attaches the specified properties to the snippet, which will be used for mustache processing in all views displaying it.
    ///
    /// > important: This setting is not persisted between app launches. Ensure the correct properties are set during each app launch.
    ///
    /// ### Local view changes
    ///
    /// If you want to modify a snippet for a specific view only, update the snippet directly instead:
    ///
    /// ```swift
    /// var snippet = snippet
    /// snippet.props = .dictionary([
    ///    "firstName": .string("John"),
    ///    "lastName": .string("Smith"),
    ///    "age": .int(42)
    /// ])
    /// return TWSView(snippet: snippet)
    /// ```
    ///
    /// ## See Also
    /// * [Mustache Manual](https://mustache.github.io/mustache.5.html)
    public func set(localProps: [String: TWSSnippet.Props], to id: TWSSnippet.ID) {
        precondition(Thread.isMainThread, "`set(customProps:,to:)` can only be called on main thread")
        store.send(.snippets(.business(.setLocalProps(props: (id, localProps)))))
    }

    /// Generates a report of all logs from the current session and returns a file URL.
    /// - Parameter reportFiltering: A function to filter and transform log entries into strings for the report file
    /// - Returns: An optional URL pointing to the generated log file
    /// - Throws: An error if the bundle identifier is unavailable or the report generation fails.
    public func getLogsReport(reportFiltering: @Sendable @escaping (TWSLogEntryLog) -> String) async throws -> URL? {

        let bundleId = Bundle.main.bundleIdentifier
        if let bundleId {
            let logReporter = LogReporter()
            return try await logReporter.generateReport(
                bundleId: bundleId,
                date: initDate.addingTimeInterval(-60),
                reportFiltering: { input in
                    let log = TWSLogEntryLog(from: input)
                    return reportFiltering(log)
                }
            )
        }
        throw LoggerError.bundleIdNotAvailable
    }

    /// Handles universal links related to snippets
    /// - Parameter url: The universal link to process.
    ///
    /// ## Discussion
    ///
    /// When an app is opened with an universal link, forward the call to ``TWS`` to give it an opportunity to parse the URL.
    ///
    /// ```swift
    /// .onOpenURL(perform: { url in
    ///    twsViewModel.handleIncomingUrl(url)
    /// })
    /// // This is needed when a link is opened by scanning a QR code with the camera app.
    /// // In that case, the `onOpenURL` is not called.
    /// .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: { userActivity in
    ///    guard let url = userActivity.webpageURL
    ///    else { return }
    ///    twsViewModel.handleIncomingUrl(url)
    /// })
    /// ```
    ///
    /// If the link is a valid TWS universal link, it will be parsed and you will be notified about it by subscribing to the ``TWSManager/observe(onEvent:)`` queue:
    ///
    /// ```swift
    /// ZStack {
    ///     ...
    /// }
    /// // Bind it to the lifetime of the view
    /// .task {
    ///    await twsManager.observe() { event in
    ///     switch event {
    ///         ...
    ///     }
    ///    }
    /// }
    /// ```
    public func handleIncomingUrl(_ url: URL) {
        precondition(Thread.isMainThread, "`handleIncomingUrl(url:)` can only be called on main thread")
        store.send(.universalLinks(.business(.onUniversalLink(url))))
    }

    // MARK: - Helpers

    private func _run() {
        precondition(Thread.isMainThread, "`run()` can only be called on main thread")
        defer { isSetup = true }
        guard !isSetup else { return }
        
        store.send(.snippets(.business(.load)))
    }

    private func _syncState() {
        _stateSync = observer
            .compactMap {
                switch $0 {
                case .snippetsUpdated: return _React.snippets
                case .universalLinkConfigurationLoaded: return nil
                case .stateChanged: return .state
                case .shouldOpenCampaign: return nil
                }
            }
            .sink(receiveValue: { [weak self] react in
                guard let weakSelf = self else { return }
                switch react {
                case .snippets:
                    let items = weakSelf.store.snippets.snippets.filter(\.isVisible).elements.map(\.snippet)
                    weakSelf.snippets.items = items

                case .state:
                    weakSelf.snippets.state = weakSelf.store.snippets.state
                }
            })
    }
}

private enum _React { case snippets, state }
