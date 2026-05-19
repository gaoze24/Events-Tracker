# Native Module Details and Course Preferences Design

## Goal

Add native read-only detail pages for Canvas module items that currently only link out to Canvas, and persist course-level UI preferences so the app remembers how each student wants to work.

This work should keep Events Tracker focused as a student-side Canvas companion. It should improve review and navigation, not attempt in-app submissions, quiz taking, discussion replies, or Canvas roster editing.

## Current Context

`CoursesView` already has a `Modules` workspace section. Module rows expose `CourseModuleItem` values with `type`, `contentID`, `pageURL`, `htmlURL`, `apiURL`, and `contentDetails`. The UI currently renders rows with badges and a generic `Open` Canvas link.

`CanvasStore` already lazy-loads course details such as modules, assignments, files, announcements, syllabus, and people. Course detail data is cached through `CourseDetailCacheManager` and pruned with the same TTL policy.

App configuration is stored in Application Support through `CanvasConfigManager`; secrets are stored in Keychain. Non-secret user preferences should use a separate JSON file in Application Support so they do not mix with credentials.

## Product Design

### Native Module Details

In `Courses > Modules`, clicking a module item should open a native detail sheet for supported types:

- `Quiz`
- `Discussion`
- `Page`

The sheet should open immediately. If the detail is not cached, show a loading state while `CanvasStore` fetches the item detail. When loaded, show a read-only native summary plus an `Open in Canvas` link.

Unsupported item types keep the current Canvas link behavior. `Assignment` should continue to use existing assignment detail paths rather than duplicating assignment behavior inside module detail work.

#### Quiz Detail

Display:

- title;
- description stripped from Canvas HTML;
- due, unlock, and lock dates when present;
- points, question count, allowed attempts, time limit;
- published/locked state;
- quiz type when Canvas returns it;
- Canvas link.

No quiz-taking, previewing questions, answer display, or submission attempt management is in scope.

#### Discussion Detail

Display:

- title;
- message/body stripped from Canvas HTML;
- author display name when Canvas returns it;
- posted/delayed dates;
- reply count/unread count when available;
- locked/closed/pinned/require initial post state when available;
- Canvas link.

No reply creation, thread expansion, or unread mutation is in scope.

#### Page Detail

Display:

- title;
- body stripped from Canvas HTML;
- front-page/published state when available;
- created/updated dates;
- Canvas link.

No editing, page history, or file embed rendering is in scope.

### Course Preferences

Persist preferences separately from Canvas credentials in `course-preferences.json`.

Per-course preferences:

- last opened `Courses` workspace tab;
- Modules search, filter, and sort;
- Files search, filter, and sort;
- Announcements search, filter, and sort;
- Assignments search, filter, and sort;
- Grades search and sort;
- People search, filter, and sort.

Global course preferences:

- hidden course IDs;
- pinned course IDs;
- default course ID;
- default Events course filter.

Course lists should apply preferences as follows:

- pinned visible courses appear first;
- hidden courses are excluded from default course pickers/lists;
- a `Show Hidden` control in `Courses` allows temporarily revealing hidden courses;
- if the default course no longer exists or is hidden, fall back to the first visible course;
- if all courses are hidden, show all courses with a clear empty/preference message rather than trapping the user.

### UI Placement

`CoursesView` remains the course workspace owner. It should bind selection and controls to persisted preferences instead of keeping every tab control as isolated `@State` that resets on relaunch.

The `Modules` area should pass a tap handler into module item rows. Supported rows open native details; unsupported rows keep their link.

Preference controls should be lightweight:

- a pin/unpin button or menu action for each course row;
- hide/unhide course action;
- show hidden toggle near the course list;
- default course action for the selected course.

Avoid a large settings redesign in this pass.

## Technical Design

### Native Detail Models

Add focused models in `DataStructure.swift`:

- `CourseQuizDetail`
- `CourseDiscussionDetail`
- `CoursePageDetail`
- shared author helper if needed
- `CourseModuleItemDetail` enum for cache/store lookup

Each model should decode Canvas fields defensively. Optional data must not block rendering. Each model should expose:

- display title;
- stripped summary/body;
- `htmlURL`;
- `matchesSearch` only if useful for tests and future UI.

### Network Calls

Add `NetworkManager` methods:

- `fetchQuizDetail(courseID:quizID:using:)`
- `fetchDiscussionDetail(courseID:discussionID:using:)`
- `fetchPageDetail(courseID:pageURL:using:)`

Expected Canvas endpoints:

- `/api/v1/courses/{courseID}/quizzes/{quizID}`
- `/api/v1/courses/{courseID}/discussion_topics/{discussionID}`
- `/api/v1/courses/{courseID}/pages/{url_or_id}`

The page path component must be URL-encoded safely because Canvas page URLs are slugs.

### Store And Cache

Extend `CanvasStore` with:

- detail dictionaries keyed by course ID plus content identifier;
- loading sets for module item details;
- `detail(for:)` accessors;
- `loadModuleItemDetailIfNeeded(courseID:item:)`.

Extend `CourseDetailCacheSnapshot` to persist the native detail cache. Reuse existing TTL and pruning behavior.

The detail key should be stable and explicit, for example:

- `quiz:{courseID}:{quizID}`
- `discussion:{courseID}:{discussionID}`
- `page:{courseID}:{pageURL}`

### Preferences Persistence

Create `CoursePreferenceManager.swift` in `Models/`.

Responsibilities:

- read/write `CoursePreferencesSnapshot`;
- default missing fields during decode;
- expose `savePreferences(_:)`, `loadPreferences()`, and `clearPreferences()`.

Add models:

- `CoursePreferencesSnapshot`
- `SingleCoursePreference`
- `CourseWorkspacePreference`

Keep raw values aligned with UI enums so preferences survive enum decoding changes by falling back to defaults.

Add `CanvasStore` ownership of preferences:

- published `coursePreferences`;
- helpers for visible/sorted courses;
- helpers to update selected tab/search/filter/sort;
- helpers to pin, hide, unhide, set default course, and set default Events course.

When Canvas credentials change and local data clears, course preferences should clear too because course IDs are account-specific.

## Error Handling

Native detail sheets should show:

- loading state while fetching;
- readable empty state when Canvas returns no body/description;
- error message through the existing `CanvasStore.errorMessage` path if a request fails;
- `Open in Canvas` fallback when native fetch is unsupported or fails.

Preferences should tolerate corrupt JSON by discarding the corrupt file and returning defaults. This should not block app launch.

## Testing

Add unit tests for:

- decoding quiz, discussion, and page detail payloads;
- Canvas request paths and query/path encoding for the three detail endpoints;
- stable module detail cache keys;
- detail cache pruning with course detail snapshot;
- course preferences default decode;
- preference save/load round trip;
- pinned/hidden/default course resolution;
- credential-change clearing of preferences.

Run typecheck and targeted unit tests after implementation:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```

## Out Of Scope

- Taking quizzes in the app.
- Submitting assignments or quiz attempts.
- Replying to discussions.
- Editing Canvas pages.
- Rendering full Canvas HTML embeds, scripts, iframes, or files inline.
- Syncing preferences across devices.
