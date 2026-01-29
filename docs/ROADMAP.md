# 🗺️ Wing iOS Native - Development Roadmap

> **Current Status**: Phase 7 (Settings & Polish) - Ready to Start
> **Target**: iOS 26.2+ | Swift 6.2 | SwiftUI | SwiftData
> **Last Updated**: 2026-01-30

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

## ✅ Phase 3: Core Services (The Brain) (Completed)
**Goal**: Port by migrating `aiService.ts` logic to Swift Actors and setting up secure preferences.

- [x] **3.1 Security Layer** (`Utils/KeychainHelper.swift`)
    - [x] Create `KeychainHelper` class (Singleton/Static).
    - [x] Implement `save`, `load`, `delete` using `kSecClassGenericPassword`.
- [x] **3.2 AI Service Engine** (`Services/AIService.swift`)
    - [x] Define `AIConfig` struct (API Key, Model, Provider).
    - [x] Create `actor AIService`.
    - [x] Implement `synthesizeJournalStream(fragments:config:) -> AsyncThrowingStream`.
    - [x] Port Prompt Engineering logic (from `aiService.ts`).
    - [x] Implement SSE (Server-Sent Events) manual parsing (OpenAI & Gemini).
- [x] **3.3 User Preferences & UI**
    - [x] Implement `SettingsManager` (SwiftData + Keychain).
    - [x] Create `SettingsEntryView` for AI Configuration.
    - [x] Verify persistence and security.

> 📖 技术回顾: [phase3-retrospective.md](.agent/memories/phase3-retrospective.md)

---

## ✅ Phase 4: UI Architecture (The Body) (Completed)
**Goal**: Establish navigation and app structure.

- [x] **4.1 Navigation Infrastructure**
    - [x] Define `AppRoute` enum (Chat, JournalDetail, Settings, etc.).
    - [x] Create `NavigationManager` (`@Observable` class) for state management.
- [x] **4.2 Main Tab View**
    - [x] Tab 1: **Today (当下)** - Chat/Recording Interface.
    - [x] Tab 2: **Journal (回忆)** - History List.
    - [x] Tab 3: **Settings (设置)**.

> 📖 技术回顾: [phase4-retrospective.md](.agent/memories/phase4-retrospective.md)

---

## ✅ Phase 5: Input Flow (The "Now") (Completed)
**Goal**: Recreate the chat-like recording experience.

- [x] **5.1 Chat Interface** (`Views/Chat/ChatView.swift`)
    - [x] Fetch today's `DailySession` using `@Query`.
    - [x] Implement `ScrollView` with `LazyVStack` for performance.
    - [x] Render `FragmentBubble` views (Text & Image).
- [x] **5.2 Input Area**
    - [x] Text Input Field (auto-expanding).
    - [x] **Photo Picker**: Integrate `PhotosPicker` (SwiftUI Native).
    - [x] **Haptics**: Add `UIImpactFeedbackGenerator` on send.
    - [x] **Date Navigation**: Robust date switching & calendar (`DateNavigator.swift`).

> 📖 技术回顾: [phase5-retrospective.md](.agent/memories/phase5-retrospective.md)

---

## ✅ Phase 6: Output Flow (The "Journal") (Completed)
**Goal**: Render the AI-synthesized entries.

- [x] **6.1 Markdown Rendering**
    - [x] Implement native `AttributedString(markdown:)` parser with paragraph separation.
    - [x] Style headers, lists, bold to match Wing's aesthetic.
- [x] **6.2 Journal Detail** (`Views/Journal/JournalDetailView.swift`)
    - [x] Cover photo section with tap-to-zoom.
    - [x] Display Metadata: Title, Date (with fallback).
    - [x] Display AI Insights ("Owl's Comment").
    - [x] Render Main Content with Markdown.
- [x] **6.3 Journal Synthesis**
    - [x] `JournalSynthesisService`: Orchestrate synthesis flow.
    - [x] `AIService.synthesizeJournal`: One-shot JSON mode.
    - [x] `SynthesisProgressView`: rotating encouragements + time estimate.
    - [x] **Fallback**: JSON parse failure → save as "无题日记".

> 📖 技术回顾: [phase6-retrospective.md](.agent/memories/phase6-retrospective.md)

---

## 📖 Phase 7: Settings & Polish
**Goal**: Complete settings UI and polish the app for release.

- [ ] **7.1 Settings Views**
    - [ ] AI Provider Configuration (API Key input -> Keychain).
    - [ ] Personality/Prompt Settings.
- [ ] **7.2 Data Management**
    - [ ] Export/Backup logic (JSON export).
- [ ] **7.3 Polish**
    - [ ] App Icon & Launch Screen.
    - [ ] Dark Mode refinements.
    - [ ] Real device testing (haptics, performance).

---

## 📝 Developer Guide

### Workflow
1. **Read Context**: Check this roadmap for current phase.
2. **Reference Web Code**: Look at `Wing-main` files for logic, implement using Swift patterns.
3. **Use Workflows**: Run `/add-service` for new services.
4. **Verify**: Run tests after major changes.

### Technical Retrospectives
Each phase has a retrospective document in `.agent/memories/`:
- `phase3-retrospective.md` - AI Service, Keychain, SSE
- `phase4-retrospective.md` - Navigation, Tab Architecture
- `phase5-retrospective.md` - DateNavigator, Image Compression
- `phase6-retrospective.md` - Swift 6 Concurrency, SwiftData Isolation