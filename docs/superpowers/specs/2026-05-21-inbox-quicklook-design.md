# Inbox and Quick Look Preview Design

## Goal

Add two student-facing native improvements:

- a top-level Inbox page for Canvas conversations with light management actions;
- a native macOS Quick Look preview sheet for downloaded files.

The Inbox should help students triage Canvas messages without replacing the full Canvas messaging experience. Quick Look should make downloaded PDFs, images, documents, and text files feel native without removing the existing Canvas and Finder fallbacks.

## Current Context

The app already has top-level SwiftUI sections in `ContentView`, Canvas API calls in `NetworkManager`, app state in `CanvasStore`, and reusable summary/row components in `SharedComponents`. Recent work added `DownloadsView`, `FileDownloadManager`, and downloaded file actions. The current Preview action calls `NSWorkspace.shared.open`, which opens the default app instead of showing an in-app preview.

Canvas conversations are not modeled yet. Canvas exposes `GET /api/v1/conversations`, supports `scope=unread|starred|archived`, supports course/user/group filters using `filter[]`, and exposes fields such as `subject`, `workflow_state`, `last_message`, `last_message_at`, `message_count`, `participants`, `audience_contexts`, `avatar_url`, and `context_name`. Conversation workflow state can be updated through the conversation update endpoint.

## Product Design

### Inbox Page

Add `Inbox` as a top-level sidebar item.

The page should show:

- summary cards for total visible messages, unread messages, archived messages, and last refreshed time;
- controls for search, course filter, and status filter;
- a refresh button;
- conversation rows with subject, last message preview, participants, context/course, relative timestamp, unread badge, and message count;
- row actions for Mark Read, Mark Unread, Archive, and Open in Canvas.

The first version is light management only. It should not support composing, replying, attachment sending, or deleting conversations.

### Inbox Filtering

Filters are local after loading a broad conversation list:

- `All`;
- `Unread`;
- `Read`;
- `Archived`.

Course filtering should use the app's loaded courses. A conversation can match a course when Canvas `audience_contexts.courses` contains that course ID. If that structure is missing, the row can still show `context_name` but may not match a course filter.

### Inbox Actions

Mark Read, Mark Unread, and Archive should call Canvas and then update local state. If an action fails, keep the previous local state and show the existing store-level error banner.

Open in Canvas should use the best known Canvas URL:

```text
<baseURL>/conversations/<id>
```

This URL is a fallback and should not block the native list if Canvas changes its web routes.

### Quick Look Preview

Replace "Preview" behavior for downloaded files with an in-app sheet backed by Quick Look.

The Preview button should:

- validate that the downloaded local file exists;
- open a sheet using a `QLPreviewView` wrapper on macOS;
- show the file name in the sheet toolbar/title;
- keep existing `Open`/Canvas/Finder fallback actions available.

If the local file is missing, mark the record failed using the existing missing-file behavior and show an error.

## Technical Design

### Models

Add conversation models to `DataStructure.swift`:

- `CanvasConversation`;
- `CanvasConversationParticipant`;
- `CanvasConversationAudienceContexts`;
- `CanvasConversationWorkflowState`;
- `InboxStatusFilter`.

Helpers should cover:

- `isUnread`;
- `isArchived`;
- `participantSummary`;
- `courseIDs`;
- `matchesSearch`;
- `canvasURL(baseURL:)`.

### Network

Add `NetworkManager` methods:

- `fetchConversations(scope:filterCourseID:using:)`;
- `updateConversationWorkflowState(conversationID:state:using:)`.

Use existing authorized request and pagination helpers. The update call should encode the workflow state as form data or JSON according to what Canvas accepts in the current code style. Tests should assert the path and key request parameters/body.

### Store

Extend `CanvasStore` with:

- `@Published private(set) var inboxConversations`;
- `@Published private(set) var loadingInbox`;
- `@Published var selectedQuickLookRecord`;
- `loadInboxConversations()`;
- `refreshInboxConversations()`;
- `markConversationRead(_:)`;
- `markConversationUnread(_:)`;
- `archiveConversation(_:)`;
- `quickLookURL(for:)`.

Credential changes should clear inbox state with other account-specific data.

### UI

Create `InboxView.swift` using existing visual patterns from `DownloadsView` and `GlobalSearchView`.

Create `QuickLookPreviewView.swift` using `QuickLook.QLPreviewView` wrapped in `NSViewRepresentable`. Present it from `DownloadsView` and course file rows via shared `DownloadActions`.

### Testing

Add tests for:

- conversation decoding and search helpers;
- course ID extraction from audience contexts;
- conversation API list path/query/include parameters;
- conversation workflow-state update body/path;
- local Quick Look URL validation for downloaded vs missing files;
- inbox filtering behavior where practical through pure model helpers.

Verification commands:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```

## Out Of Scope

- composing new messages;
- replying to conversations;
- sending attachments;
- deleting conversations;
- system notification delivery;
- background polling while the app is closed;
- previewing remote files before explicit download.

## Self-Review

- Placeholder scan: no TODO/TBD placeholders.
- Scope check: Inbox light management and Quick Look preview are separate but small and share no risky data model coupling.
- Consistency check: the design follows existing `NetworkManager` + `CanvasStore` + top-level SwiftUI page patterns.
- Ambiguity check: native reply and background notifications are explicitly out of scope.
