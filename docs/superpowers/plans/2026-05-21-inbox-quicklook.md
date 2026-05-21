# Inbox and Quick Look Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a top-level Canvas Inbox with read/unread/archive actions and replace downloaded-file preview with a native macOS Quick Look sheet.

**Architecture:** Add conversation models in `DataStructure.swift`, Canvas API calls in `NetworkManager`, and inbox state/actions in `CanvasStore`. Add `InboxView` as a top-level SwiftUI page and `QuickLookPreviewView` as a focused AppKit wrapper used by existing download actions.

**Tech Stack:** Swift 5, SwiftUI, AppKit, QuickLook `QLPreviewView`, Foundation `URLSession`, Swift Testing, existing macOS Xcode project.

---

## File Structure

- Modify `Events Tracker/Models/DataStructure.swift`
  - Add conversation models, workflow state enum, and helper methods.
- Modify `Events Tracker/Models/NetworkManager.swift`
  - Add list and workflow-state update APIs for Canvas conversations.
- Modify `Events Tracker/Models/CanvasStore.swift`
  - Own inbox state and expose conversation actions plus Quick Look URL validation.
- Modify `Events Tracker/Views/ContentView.swift`
  - Add top-level `Inbox` sidebar section.
- Create `Events Tracker/Views/InboxView.swift`
  - Inbox page with summary cards, filters, search, and row actions.
- Create `Events Tracker/Views/QuickLookPreviewView.swift`
  - macOS Quick Look wrapper.
- Modify `Events Tracker/Views/DownloadsView.swift`
  - Present Quick Look sheet from downloaded records and keep Open/Reveal/Canvas fallbacks.
- Modify `Events Tracker/Views/CoursesView.swift`
  - Pass Quick Look preview action through file rows.
- Modify `Events TrackerTests/Events_TrackerTests.swift`
  - Add model and network tests.

Do not create git commits unless the user explicitly asks for commits.

---

### Task 1: Conversation Models

**Files:**
- Modify: `Events Tracker/Models/DataStructure.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [x] **Step 1: Write failing conversation model tests**

Test decoding a representative Canvas conversation, extracting course IDs from `audience_contexts`, participant summary, unread/archive helpers, search matching, and Canvas fallback URL creation.

- [x] **Step 2: Run tests to verify model symbols fail**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```

Expected: compile failure for missing `CanvasConversation` model APIs.

- [x] **Step 3: Implement conversation models**

Add:

```swift
enum CanvasConversationWorkflowState: String, Codable, CaseIterable, Identifiable
struct CanvasConversationParticipant: Codable, Identifiable, Hashable
struct CanvasConversationAudienceContexts: Codable, Hashable
struct CanvasConversation: Codable, Identifiable, Hashable
```

Keep decoding tolerant for optional Canvas fields.

---

### Task 2: Conversation Network APIs

**Files:**
- Modify: `Events Tracker/Models/NetworkManager.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [x] **Step 1: Write failing network tests**

Verify:

- `fetchConversations(scope:filterCourseID:)` calls `/api/v1/conversations`;
- includes `per_page=100`;
- includes `include[]=participant_avatars`;
- includes `filter[]=course_<id>` when a course ID is provided;
- decodes and sorts newest first;
- `updateConversationWorkflowState` calls `/api/v1/conversations/<id>` with workflow state.

- [x] **Step 2: Run tests to verify network APIs fail**

Expected: compile failure for missing `NetworkManager` methods.

- [x] **Step 3: Implement network APIs**

Use existing request helpers where possible. Add a focused private request method if a non-GET update body is required.

---

### Task 3: Store Inbox And Quick Look State

**Files:**
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [x] **Step 1: Add store-level tests where practical**

Add pure tests for `FileDownloadRecord`/store-adjacent URL validation if access allows. Avoid brittle UI tests.

- [x] **Step 2: Add published state**

Add inbox conversations, loading flag, and selected Quick Look record/URL state.

- [x] **Step 3: Add inbox load and action methods**

Add `loadInboxConversations`, `refreshInboxConversations`, `markConversationRead`, `markConversationUnread`, and `archiveConversation`.

- [x] **Step 4: Add Quick Look validation helper**

Add a method that returns a local file URL only if the record is downloaded and the file exists; otherwise mark missing and set `errorMessage`.

- [x] **Step 5: Clear inbox state on account reset**

Reset inbox state in `clearLocalData()`.

---

### Task 4: Inbox UI

**Files:**
- Modify: `Events Tracker/Views/ContentView.swift`
- Create: `Events Tracker/Views/InboxView.swift`

- [x] **Step 1: Add `inbox` app section**

Add sidebar label and route to `InboxView`.

- [x] **Step 2: Implement `InboxView`**

Use `DownloadsView`/`GlobalSearchView` patterns:

- title and explanatory subtitle;
- summary cards;
- search field;
- course picker;
- status picker;
- refresh button;
- empty states;
- conversation rows.

- [x] **Step 3: Wire row actions**

Rows call store actions for read/unread/archive and use Canvas fallback links.

---

### Task 5: Quick Look UI

**Files:**
- Create: `Events Tracker/Views/QuickLookPreviewView.swift`
- Modify: `Events Tracker/Views/DownloadsView.swift`
- Modify: `Events Tracker/Views/CoursesView.swift`

- [x] **Step 1: Add Quick Look wrapper**

Wrap `QLPreviewView` in `NSViewRepresentable`.

- [x] **Step 2: Present preview sheet from `DownloadsView`**

Track selected record locally, ask store for a valid local URL, and present `QuickLookPreviewSheet`.

- [x] **Step 3: Reuse preview action in course file rows**

Keep button behavior consistent between `DownloadsView` and `Courses > Files`.

- [x] **Step 4: Keep fallbacks**

Keep `Open`, `Reveal`, and `Canvas` actions available.

---

### Task 6: Verification

**Files:**
- All edited files

- [x] **Step 1: Run source typecheck**

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

- [x] **Step 2: Run unit tests**

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```

- [x] **Step 3: Inspect git status**

Run `git status --short --branch` and ensure only expected files changed.

---

## Self-Review

- Spec coverage: Inbox light management, Canvas filters/actions, Quick Look preview, fallbacks, and verification are covered.
- Placeholder scan: no unresolved TODO/TBD.
- Type consistency: model, manager, store, and UI names are consistent.
- Scope: composing/replying and background notifications remain out of scope.
