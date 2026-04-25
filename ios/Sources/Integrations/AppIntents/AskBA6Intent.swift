import Foundation
import AppIntents

/// "Hey Siri, ask BA6 …" entry point.
///
/// Runs in-process when invoked by Shortcuts or Siri. Uses the shared
/// `InferenceEngine` registered in `Ba6AiApp.init` via
/// `AppDependencyManager`. Returns the answer as both a value (for
/// chaining in Shortcuts) and a spoken dialog (for Siri).
struct AskBA6Intent: AppIntent {
    static let title: LocalizedStringResource = "Ask BA6"
    static let description = IntentDescription(
        "Ask BA6 AI a question and get a private, on-device response."
    )

    @Parameter(
        title: "Question",
        description: "What you want to ask BA6.",
        requestValueDialog: "What should I ask BA6?"
    )
    var question: String

    /// `false` = run silently in the background. Set to true if a
    /// future intent should bring the chat surface to the foreground.
    static var openAppWhenRun: Bool { false }

    @Dependency private var router: BA6IntentRouter

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let answer = try await router.answer(question)
        return .result(
            value: answer,
            dialog: IntentDialog(stringLiteral: answer)
        )
    }
}

/// Surfaces shortcut phrases the system uses for auto-complete and
/// "Suggested Shortcuts". Phrases must include the app name.
struct BA6Shortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskBA6Intent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) \(\.$question)",
                "\(.applicationName) tell me about \(\.$question)"
            ],
            shortTitle: "Ask BA6",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: RememberFactIntent(),
            phrases: [
                "\(.applicationName) remember \(\.$fact)",
                "Tell \(.applicationName) to remember \(\.$fact)"
            ],
            shortTitle: "Remember",
            systemImageName: "brain"
        )
    }
}

/// "Hey Siri, BA6 remember that I'm allergic to peanuts."
struct RememberFactIntent: AppIntent {
    static let title: LocalizedStringResource = "Remember a fact"
    static let description = IntentDescription(
        "Save a fact to BA6's local memory so it can use it later."
    )

    @Parameter(
        title: "Fact",
        description: "The thing BA6 should remember.",
        requestValueDialog: "What should I remember?"
    )
    var fact: String

    static var openAppWhenRun: Bool { false }

    @Dependency private var router: BA6IntentRouter

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await router.remember(fact)
        return .result(dialog: "Got it. I'll remember that.")
    }
}
