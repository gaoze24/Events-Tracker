# Telegram Assignment Reminders Design

## Summary

Events Tracker will add Telegram reminders for Canvas assignments that are close to their deadline and not yet submitted. The reminder system will run only while the macOS app process is running, including when the window is minimized. It will not install a system background agent or send reminders after the app quits.

The feature will live beside the existing Canvas configuration in Settings. Users can configure Telegram bot access, pick the target chat through a guided setup flow, choose how far ahead to look for deadlines, and choose how often the same pending assignment can be reminded again.

## Goals

- Notify the configured Telegram chat about assignments that are due soon and still unsubmitted.
- Keep configuration in the same local app configuration flow as Canvas credentials.
- Avoid repeated spam by recording reminder history locally.
- Refresh assignment submission status periodically while the app is running.
- Keep reminder selection logic testable without network calls.

## Non-Goals

- No reminders after the app has quit.
- No LaunchAgent, login item, or helper app in this iteration.
- No multi-device sync for reminder history.
- No support for multiple Telegram chats at once.

## User Experience

Settings gains a `Telegram Reminders` section below the existing Canvas configuration.

The section includes:

- Enable or disable Telegram reminders.
- Bot token entry.
- A guided chat setup flow:
  1. User enters a bot token.
  2. User sends any message to the bot in Telegram.
  3. App loads recent bot updates.
  4. User selects the chat to use.
  5. App sends a test message to confirm the setup.
- Reminder window, configured in hours.
- Check interval, configured in minutes.
- Repeat interval, configured in hours.
- A `Send Test Message` action once token and chat are configured.

The UI should clearly explain that reminders are only active while Events Tracker is open.

## Configuration Model

`CanvasConfig` will be extended with a nested `TelegramReminderConfig` value:

- `isEnabled: Bool`
- `botToken: String`
- `chatID: String`
- `reminderWindowHours: Int`
- `checkIntervalMinutes: Int`
- `repeatIntervalHours: Int`

The defaults should keep reminders disabled and use conservative timing:

- Reminder window: 24 hours.
- Check interval: 30 minutes.
- Repeat interval: 24 hours.

Validation rules:

- Telegram reminders require a non-empty bot token and chat ID.
- Reminder window should be clamped to 1 to 168 hours.
- Check interval should be clamped to 5 to 240 minutes.
- Repeat interval should be clamped to 1 to 168 hours.

The existing config file remains the source of truth for this iteration. Token storage can be moved to Keychain later, but this implementation should not introduce separate partial configuration stores unless needed for reminder history.

The decoder must preserve compatibility with existing `canvas-config.json` files that do not contain Telegram settings by defaulting the nested config to disabled.

## Architecture

### `TelegramManager`

`TelegramManager` owns Telegram Bot API calls.

Responsibilities:

- Fetch bot updates with `getUpdates` for chat discovery.
- Send messages with `sendMessage`.
- Return clear errors for invalid token, missing chat, network failure, or Telegram API errors.

It should not know about Canvas assignments or reminder timing.

### `ReminderEvaluator`

`ReminderEvaluator` is pure business logic.

Responsibilities:

- Accept assignments, course names, config, reminder history, and a reference date.
- Select assignments that:
  - have a due date;
  - are due between now and the configured reminder window;
  - are not submitted, graded, or excused;
  - are not suppressed by the repeat interval.
- Produce reminder candidates and the updated reminder timestamps needed after a successful send.

This keeps deadline filtering and de-duplication covered by unit tests.

### `AssignmentReminderService`

`AssignmentReminderService` runs inside the app process.

Responsibilities:

- Start when the app initializes and stop when reminders are disabled or the app exits.
- Use a timer or structured concurrency loop based on `telegramCheckIntervalMinutes`.
- Refresh Canvas assignment status for active courses.
- Evaluate reminder candidates.
- Send Telegram messages through `TelegramManager`.
- Persist reminder history after successful sends.

The service should avoid overlapping runs. If a check is still in progress when the next interval arrives, it should skip that tick.

### `ReminderHistoryManager`

`ReminderHistoryManager` stores local de-duplication state.

The history can be a JSON file in the same Application Support directory as the current Canvas config and cache. A stable key should combine course ID and assignment ID, for example `courseID:assignmentID`.

Stored value:

- last reminder sent date.

The manager should tolerate missing or corrupt history by starting with an empty history rather than blocking reminders.

## Canvas Data Flow

The service should reuse existing Canvas API support where possible.

For each active course:

1. Fetch assignments through the existing assignments endpoint with `include[]=submission`.
2. Use `CourseAssignment.status`, `isCompleted`, and `dueAt` to decide whether an assignment is still pending.
3. Include course name in the Telegram message.

The first implementation can fetch assignments for all active courses during each reminder check. If this becomes too slow, a later optimization can cache course-level assignment data or stagger course checks.

## Telegram Message Format

Messages should be compact and actionable:

```text
Upcoming Canvas deadline

Course: Biology
Assignment: Lab Report
Due: Today at 11:59 PM
Status: Not submitted
Link: https://...
```

If Canvas does not provide a link, omit the link line.

## Error Handling

- Invalid Canvas configuration: do not run reminder checks; surface the existing Canvas configuration error in the app state when appropriate.
- Invalid Telegram configuration: keep reminders disabled for sending, and show a Settings status message when testing or saving.
- Telegram send failure: record an error in service state but do not mark the reminder as sent.
- Partial assignment fetch failure: fail the current check and retry at the next interval.
- Empty candidate list: do nothing.

## Testing

Unit tests should cover:

- Telegram reminder config normalization and validation.
- Assignment selection inside and outside the reminder window.
- Submitted, graded, excused, late, missing, and unscheduled assignment handling.
- Repeat interval suppression.
- Reminder history keying by course ID and assignment ID.

Network calls should be kept behind small types so reminder selection tests do not require Canvas or Telegram access.

## Implementation Order

1. Extend `CanvasConfig` and Settings fields for Telegram reminders.
2. Add reminder history storage.
3. Add `ReminderEvaluator` and unit tests.
4. Add `TelegramManager` for chat discovery and test messages.
5. Add `AssignmentReminderService` and wire it into app startup.
6. Add Settings actions for wizard, test message, and enablement.
7. Run targeted tests and a source typecheck.
