# Calendar, People, and README Refresh Design

## Goal

Improve the student planning surface without turning Events Tracker into a full Canvas clone:

- Upgrade `Events` from two lists into a calendar workspace with calendar, week, and agenda views.
- Add `People` as a course-level workspace tab under `Courses`, not inside the calendar.
- Update `README.md` so the documented feature set matches the current app.

## Current Context

The app already has a global sidebar with `Dashboard`, `Assignments`, `Courses`, `Events`, `Profile`, and `Settings`. Course workspaces already support `Overview`, `Modules`, `Announcements`, `Syllabus`, `Files`, `Assignments`, and `Grades`.

`Events` currently shows a course selector plus a segmented `Upcoming`/`Missing` list. The data is already available in `CanvasStore` as `upcomingEvents` and `missingSubmissions`.

Course detail data is lazy-loaded through `CanvasStore`, with network calls in `NetworkManager` and local detail caching through `CourseDetailCacheManager`.

## Product Design

### Events Calendar Workspace

Keep `Events` as its own top-level app section. The left side remains a course filter. The main panel gets a view-mode picker:

- `Calendar`: month grid, selected day, event density indicators, overdue markers, and a selected-day detail panel.
- `Week`: seven-day planning view for the current selected week.
- `Agenda`: grouped list of upcoming and missing work, organized by date and status.

The first version reuses the dashboard data already loaded at sync time. It should not introduce a new Canvas calendar endpoint unless current data proves insufficient.

Missing work should appear alongside upcoming work in calendar contexts so overdue items remain visible. Items without dates stay in an undated or attention section rather than disappearing.

### Course People Tab

Add `People` as a new `CourseWorkspaceSection` in `CoursesView`.

When the tab opens, the app lazily loads the selected course roster. The UI shows:

- summary cards for teachers, TAs, students, and total visible members;
- search by name, sortable name/role/last activity when data exists;
- role filters for all, teachers, TAs, students, and other;
- member rows with avatar initials or avatar URL, display name, role, section, last activity, and links/contact fields when Canvas provides them;
- a lightweight detail sheet for profile/contact fields and course role context.

The People feature is course-scoped because Canvas rosters are course resources. It should not be shown inside `Events`.

### README

Update the README to describe:

- current dashboard, assignment, course workspace, events, profile, settings, cache, and Telegram reminder capabilities;
- local app data and Keychain token storage;
- current roadmap after this work: richer assignment submissions, quiz/discussion/page detail views, Inbox/notifications, and polish.

## Technical Design

### Data Structures

Add a `CoursePerson` model in `DataStructure.swift` that decodes Canvas users/enrollments returned by course user APIs. It should normalize role display into a small enum or helper properties, but keep raw Canvas fields available where useful.

Expected fields include:

- id, name, sortableName, shortName;
- avatarURL, htmlURL;
- email/loginID if Canvas returns them;
- enrollments, role, section, lastActivityAt if available.

The model should tolerate missing optional fields because Canvas permissions vary by institution.

### Networking

Add `NetworkManager.fetchPeople(courseID:using:)`.

Preferred endpoint: `/api/v1/courses/{courseID}/users` with includes for enrollments and avatar URL where supported, paginated with `per_page=100`.

The request should follow existing pagination, decoding, and sorting patterns. It should not require additional scopes beyond normal student Canvas API access; if Canvas withholds fields, the UI degrades gracefully.

### Store and Cache

Extend `CanvasStore` with:

- `coursePeopleByCourseID`;
- `loadingCoursePeopleIDs`;
- `people(for:)`, `isLoadingPeople(for:)`, `hasLoadedPeople(for:)`;
- `loadPeopleIfNeeded(for:)` and `loadPeople(for:)`.

Include People in `CourseDetailCacheSnapshot` so a previously opened roster can restore with other course detail data. Reuse existing TTL and pruning behavior.

### UI

Keep the first implementation in existing files unless the edit becomes unwieldy. If `CoursesView.swift` grows too much, extract People-specific views into a focused view file.

For `EventsView`, introduce small helper models or computed properties for calendar days and grouped items so date math stays testable. The UI should stay SwiftUI-native and macOS friendly.

## Error Handling

Use existing `CanvasStore.errorMessage` behavior for network failures. Empty states should distinguish between:

- no data returned;
- no matching search/filter results;
- undated items that cannot be placed on the calendar.

People should handle restricted rosters by showing a clear empty/restricted-style message rather than crashing or hiding the tab.

## Testing

Add unit tests for:

- calendar item grouping and date bucketing;
- month/week date generation around month boundaries;
- People role normalization and search matching;
- People network request path/query and decoding.

Run the targeted unit test command after implementation. If Xcode UI runner issues appear, note them separately and keep unit verification focused.

## Out of Scope

- In-app assignment submission and file upload.
- Native quiz/discussion/page readers beyond existing module links.
- Canvas Inbox/conversations.
- Editing roster data or messaging people from inside the app.
- Adding a new full calendar sync endpoint unless existing upcoming/missing data is inadequate.
