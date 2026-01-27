# 🗺️ Wing iOS Native - Development Roadmap

> **Current Status**: Phase 3 (Core Services) - Ready to Start
> **Target**: iOS 26.2+ | Swift 6.2 | SwiftUI | SwiftData
> **Last Updated**: 2026-01-28

## 📌 Project Overview
Wing is an AI-powered diary application being refactored from React/TypeScript to Native iOS.
It uses **SwiftData** for local persistence, **SwiftUI** for the interface, and **LLMs (Gemini/OpenAI)** for journal synthesis.

---

## 🏗️ Architecture Standards (For Cursor)

* **Design Pattern**: MVVM (Model-View-ViewModel) + Services (Actor-based).
* **Concurrency**: Strict `async/await`. Use `Task` and `Actor` for thread safety.
* **Data Layer**:
    * **SwiftData**: `@Model` for persistence.
    * **Images**: Must use `@Attribute(.externalStorage) var data: Data?` to prevent DB bloat.
    * **IDs**: Always use `UUID`.
* **Security**: API Keys must be stored in **Keychain** (via `KeychainHelper`), NEVER in UserDefaults or code.
* **UI**: Pure SwiftUI. Use `NavigationStack` for routing.
* **Testing**:
    * `@Test` (Swift Testing) for Logic/Models.
    * `XCTest` for UI/Integration.

---

## ✅ Phase 1: Environment & Setup (Completed)
- [x] **Project Initialization**: Xcode 26.2, Swift 6.2.
- [x] **Configuration**: `.cursorrules` established for iOS context.
- [x] **Git**: Repository initialized and clean.

## ✅ Phase 2: Data Layer Foundation (Completed)
- [x] **Core Models (`WingModels.swift`)**:
    - `RawFragment` (with external image storage).
    - `DailySession` (cascade delete configured).
    - `WingEntry` (computed properties for JSON structs).
    - `AppSettings` & `Memory` models.
- [x] **Model Container**: Configured in `WingApp.swift`.
- [x] **Verification (`ModelTests.swift`)**:
    - CRUD operations verified.
    - Image external storage verified.
    - Cascade deletion verified.
    - Complex data types (JSON) verified.

---

## 🚧 Phase 3: Core Services (The Brain)
**Goal**: Port `aiService.ts` logic to Swift Actors.

- [ ] **3.1 Security Layer** (`Utils/KeychainHelper.swift`)
    - [ ] Create `KeychainHelper` class (Singleton/Static).
    - [ ] Implement `save`, `load`, `delete` using `kSecClassGenericPassword`.
- [ ] **3.2 AI Service Engine** (`Services/AIService.swift`)
    - [ ] Define `AIConfig` struct (API Key, Model, Provider).
    - [ ] Create `actor AIService`.
    - [ ] Implement `synthesizeJournalStream(fragments:config:) -> AsyncThrowingStream`.
    - [ ] Port Prompt Engineering logic (from `aiService.ts`).
    - [ ] Implement SSE (Server-Sent Events) manual parsing.
- [ ] **3.3 Smoke Test**
    - [ ] Add a temporary button in `ContentView` to trigger a fake AI call and print tokens to console.

---

## 📅 Phase 4: UI Architecture (The Body)
**Goal**: Establish navigation and app structure.

- [ ] **4.1 Navigation Infrastructure**
    - [ ] Define `AppRoute` enum (Chat, JournalDetail, Settings, etc.).
    - [ ] Create `AppNavigation` environment object or logic.
- [ ] **4.2 Main Tab View**
    - [ ] Tab 1: **Today (当下)** - Chat/Recording Interface.
    - [ ] Tab 2: **Journal (回忆)** - History List.
    - [ ] Tab 3: **Settings (设置)**.

---

## 💬 Phase 5: Input Flow (The "Now")
**Goal**: Recreate the chat-like recording experience.

- [ ] **5.1 Chat Interface** (`Views/Chat/ChatView.swift`)
    - [ ] Fetch today's `DailySession` using `@Query`.
    - [ ] Implement `ScrollView` with `LazyVStack` for performance.
    - [ ] Render `FragmentBubble` views (Text & Image).
- [ ] **5.2 Input Area**
    - [ ] Text Input Field (auto-expanding).
    - [ ] **Photo Picker**: Integrate `PhotosPicker` (SwiftUI Native).
    - [ ] **Haptics**: Add `UIImpactFeedbackGenerator` on send.

---

## 📖 Phase 6: Output Flow (The "Journal")
**Goal**: Render the AI-synthesized entries.

- [ ] **6.1 Markdown Rendering**
    - [ ] Integrate `swift-markdown-ui` (or implement custom `AttributedString` parser).
    - [ ] Style headers, blockquotes, and lists to match Wing's aesthetic.
- [ ] **6.2 Journal Detail** (`Views/Journal/JournalDetailView.swift`)
    - [ ] Display Metadata: Mood, Weather, Date.
    - [ ] Display AI Insights ("Owl's Comment").
    - [ ] Render Main Content.

---

## ⚙️ Phase 7: Settings & Polish
- [ ] **7.1 Settings Views**
    - [ ] AI Provider Configuration (API Key input -> Keychain).
    - [ ] Personality/Prompt Settings.
- [ ] **7.2 Data Management**
    - [ ] Export/Backup logic (JSON export).
- [ ] **7.3 Polish**
    - [ ] App Icon & Launch Screen.
    - [ ] Dark Mode refinements.

---

## 📝 Workflow Guide for Cursor
1.  **Read Context**: Before starting a task, check this roadmap to see active phase.
2.  **Reference Web Code**: When porting logic, look at `Wing-main` files (e.g., `aiService.ts`, `ChatView.tsx`) for logic, but implement using **SwiftUI/Swift patterns**.
3.  **Verify**: After implementing a major component (Service or Model change), request to run/update Tests.