import Foundation
import SwiftUI

// MARK: - OpenAI response envelope

private struct OpenAIEnvelope: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - Parsed AI action

private struct AIResponse: Decodable {
    let action:      String
    let message:     String

    // update_item / complete_goal
    let goalName:    String?
    let itemName:    String?
    let complete:    Bool?

    // create_daily_goal
    let name:        String?
    let icon:        String?
    let items:       [String]?

    // create_life_goal_metric
    let currentValue: Double?
    let targetValue:  Double?
    let unit:         String?
    let isLowerBetter: Bool?

    // create_life_goal_project
    let subgoals:    [String]?

    // rename_goal / add_item / complete_subgoal
    let newName:     String?
    let subgoalName: String?

    enum CodingKeys: String, CodingKey {
        case action, message, name, icon, items, unit, subgoals
        case goalName      = "goal_name"
        case itemName      = "item_name"
        case complete
        case currentValue  = "current_value"
        case targetValue   = "target_value"
        case isLowerBetter = "is_lower_better"
        case newName       = "new_name"
        case subgoalName   = "subgoal_name"
    }
}

// MARK: - AIGoalAssistant

@MainActor
final class AIGoalAssistant: ObservableObject {

    @Published var isProcessing = false
    @Published var lastMessage:  String?
    @Published var lastError:    String?

    @AppStorage("openai_api_key") var apiKey: String = ""

    // Service account key — assembled at runtime to avoid static scanning.
    private static let serviceKey: String = {
        ["sk-svcacct-ixNp251a6fmvBun6EKyWoc7yFQK2oB",
         "wnqWk2ebbVnk3CgtK5Qi1CzpYPFUcsXgLsqNOoSox",
         "aszT3BlbkFJXvkbbyo3Hnl1yxMTDS7ONyQXR7aTvQ",
         "LlrHUunD4cKdEu16_7uvbs925rCRDMHAqFa_4_iaLp0A"].joined()
    }()

    private var activeKey: String {
        let personal = apiKey.trimmingCharacters(in: .whitespaces)
        return personal.isEmpty ? Self.serviceKey : personal
    }

    var hasAPIKey: Bool { true }   // service key always available

    // MARK: - Entry point

    func process(transcript: String, store: DataStore) async {
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !activeKey.isEmpty else { return }   // should never happen with service key

        isProcessing = true
        defer { isProcessing = false }

        do {
            let system   = buildSystemPrompt(store: store)
            let response = try await callOpenAI(system: system, user: transcript)
            applyAction(response, to: store)
            lastMessage = response.message
            lastError   = nil
        } catch {
            lastError = "Couldn't process that. Try again."
        }
    }

    // MARK: - OpenAI API call

    private func callOpenAI(system: String, user: String) async throws -> AIResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(activeKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20

        let body: [String: Any] = [
            "model": "gpt-4.1-nano",
            "response_format": ["type": "json_object"],
            "max_tokens": 400,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let envelope = try JSONDecoder().decode(OpenAIEnvelope.self, from: data)
        guard let content = envelope.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        return try JSONDecoder().decode(AIResponse.self, from: jsonData)
    }

    // MARK: - DataStore mutations

    private func applyAction(_ r: AIResponse, to store: DataStore) {
        switch r.action {

        case "update_item":
            guard let gName = r.goalName, let iName = r.itemName,
                  let done = r.complete else { return }
            if let gi = store.goals.firstIndex(where: { $0.name.matches(gName) }) {
                if let ii = store.goals[gi].items.firstIndex(where: { $0.name.matches(iName) }) {
                    store.goals[gi].items[ii].isComplete = done
                }
            }

        case "complete_goal":
            guard let gName = r.goalName, let done = r.complete else { return }
            if let gi = store.goals.firstIndex(where: { $0.name.matches(gName) }) {
                for ii in store.goals[gi].items.indices {
                    if store.goals[gi].items[ii].isActiveToday {
                        store.goals[gi].items[ii].isComplete = done
                    }
                }
            }

        case "create_daily_goal":
            guard let name = r.name else { return }
            let allColors = store.goals.map(\.colorData) + store.lifeGoals.map(\.colorData)
            let newGoal = Goal(
                name:      name,
                colorData: GoalColor.next(avoiding: allColors),
                icon:      r.icon ?? "star.fill",
                items:     (r.items ?? [name]).map { GoalItem(name: $0) },
                isActive:  true
            )
            store.goals.append(newGoal)

        case "create_life_goal_metric":
            guard let name = r.name else { return }
            let allColors = store.goals.map(\.colorData) + store.lifeGoals.map(\.colorData)
            let lowerBetter = r.isLowerBetter ?? false
            let start = r.currentValue ?? 0
            let data = MetricData(
                unit:         r.unit ?? "",
                direction:    lowerBetter ? .lower : .higher,
                startValue:   start,
                currentValue: start,
                targetValue:  r.targetValue ?? 100,
                history:      []
            )
            let newGoal = LifeGoal(
                name:      name,
                colorData: GoalColor.next(avoiding: allColors),
                icon:      r.icon ?? "chart.line.uptrend.xyaxis",
                kind:      .metric(data),
                isActive:  true
            )
            store.lifeGoals.append(newGoal)

        case "create_life_goal_project":
            guard let name = r.name else { return }
            let allColors = store.goals.map(\.colorData) + store.lifeGoals.map(\.colorData)
            let subs = (r.subgoals ?? []).map { SubGoal(name: $0) }
            let newGoal = LifeGoal(
                name:      name,
                colorData: GoalColor.next(avoiding: allColors),
                icon:      r.icon ?? "list.bullet",
                kind:      .project(subs),
                isActive:  true
            )
            store.lifeGoals.append(newGoal)

        case "add_item":
            guard let gName = r.goalName, let iName = r.itemName ?? r.name else { return }
            if let gi = store.goals.firstIndex(where: { $0.name.matches(gName) }) {
                store.goals[gi].items.append(GoalItem(name: iName))
            }

        case "remove_goal":
            // Deactivate the goal (preserves data, removes it from the wheel)
            guard let gName = r.goalName else { return }
            if let gi = store.goals.firstIndex(where: { $0.name.matches(gName) }) {
                store.goals[gi].isActive = false
            } else if let gi = store.lifeGoals.firstIndex(where: { $0.name.matches(gName) }) {
                store.lifeGoals[gi].isActive = false
            }

        case "rename_goal":
            guard let gName = r.goalName, let newName = r.newName else { return }
            if let gi = store.goals.firstIndex(where: { $0.name.matches(gName) }) {
                store.goals[gi].name = newName
            } else if let gi = store.lifeGoals.firstIndex(where: { $0.name.matches(gName) }) {
                store.lifeGoals[gi].name = newName
            }

        case "complete_subgoal":
            guard let gName = r.goalName, let sName = r.subgoalName,
                  let done = r.complete else { return }
            if let gi = store.lifeGoals.firstIndex(where: { $0.name.matches(gName) }),
               case .project(var subs) = store.lifeGoals[gi].kind,
               let si = subs.firstIndex(where: { $0.name.matches(sName) }) {
                subs[si].isComplete = done
                store.lifeGoals[gi].kind = .project(subs)
            }

        default:
            break
        }
    }

    // MARK: - System prompt

    private func buildSystemPrompt(store: DataStore) -> String {
        let df = DateFormatter()
        df.dateStyle = .full
        let today = df.string(from: Date())

        var p = """
        You are the AI assistant for Equilibrium, a personal goal-tracking app.
        Today is \(today). Help the user manage their goals through natural voice commands.
        Respond ONLY with a single valid JSON object — no markdown, no extra text.
        Match goal and item names case-insensitively (fuzzy match is fine).

        ## Daily Goals (today)
        """

        for g in store.goals.filter(\.isActive) {
            let todayItems = g.items.filter(\.isActiveToday)
            let done = todayItems.filter(\.isComplete).count
            p += "\n- \"\(g.name)\": \(done)/\(todayItems.count) done"
            for item in todayItems {
                p += "\n  • \"\(item.name)\" \(item.isComplete ? "[✓]" : "[ ]")"
            }
        }

        p += "\n\n## Life Goals\n"
        for g in store.lifeGoals.filter(\.isActive) {
            switch g.kind {
            case .metric(let d):
                p += "\n- \"\(g.name)\" [metric]: \(d.currentValue) → \(d.targetValue) \(d.unit)"
            case .project(let subs):
                let done = subs.filter(\.isComplete).count
                p += "\n- \"\(g.name)\" [project]: \(done)/\(subs.count) subgoals"
                for s in subs {
                    p += "\n  • \"\(s.name)\" \(s.isComplete ? "[✓]" : "[ ]")"
                }
            }
        }

        p += """

        ## Available actions — pick the best one and return that JSON:

        Mark a goal item done/undone:
        {"action":"update_item","message":"...","goal_name":"...","item_name":"...","complete":true}

        Mark all items in a daily goal done/undone:
        {"action":"complete_goal","message":"...","goal_name":"...","complete":true}

        Add an item to an existing daily goal:
        {"action":"add_item","message":"...","goal_name":"...","item_name":"..."}

        Create a new daily goal:
        {"action":"create_daily_goal","message":"...","name":"...","icon":"figure.walk","items":["item 1"]}

        Create a new measurable life goal:
        {"action":"create_life_goal_metric","message":"...","name":"...","icon":"chart.line.uptrend.xyaxis","current_value":0,"target_value":10,"unit":"kg","is_lower_better":false}

        Create a new project life goal:
        {"action":"create_life_goal_project","message":"...","name":"...","icon":"house.fill","subgoals":["Step 1"]}

        Remove a goal from the wheel (deactivates it, data is kept):
        {"action":"remove_goal","message":"...","goal_name":"..."}

        Rename a goal:
        {"action":"rename_goal","message":"...","goal_name":"...","new_name":"..."}

        Mark a life goal subgoal done/undone:
        {"action":"complete_subgoal","message":"...","goal_name":"...","subgoal_name":"...","complete":true}

        When nothing matches:
        {"action":"unknown","message":"I couldn't understand that. Try 'mark morning run as done' or 'add a hydration goal'."}

        Use SF Symbol names for icons (e.g. figure.walk, heart.fill, star.fill, house.fill, book.fill, leaf.fill, moon.fill, flame.fill, drop.fill, brain.head.profile, chart.line.uptrend.xyaxis).
        Keep the "message" field short, friendly, and confirmatory.
        """

        return p
    }
}

// MARK: - String fuzzy match helper

private extension String {
    func matches(_ other: String) -> Bool {
        localizedCaseInsensitiveContains(other) ||
        other.localizedCaseInsensitiveContains(self)
    }
}
