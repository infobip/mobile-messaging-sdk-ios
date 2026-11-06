# Inbox example

A SwiftUI app that shows how to use the Mobile Messaging SDK Inbox: fetching messages, cursor pagination, topic filters, marking as read, deleting and JWT authorization.

## Run it

```bash
open InboxExample/InboxExample.xcodeproj
```

The SDK is added with Swift Package Manager from this repository (`MobileMessaging` and `MobileMessagingInbox` products). In your app, add `https://github.com/infobip/mobile-messaging-sdk-ios` as a package dependency instead.

Run the `InboxExample` scheme on a device or a simulator. No code changes are needed. The app opens on **Settings** until it is set up:

1. Enter the Application Code from the App Profile. Set a base URL only if Infobip gave you one.
2. Choose the authorization. It must match the **Inbox authorization type** on the App Profile:
   - **App code**: for Sandbox applications only.
   - **JWT**: the app signs the token itself with a key from *JWT private keys for mobile app inbox*. The secret is kept in memory only. This is for trying JWT authorization without a backend. Never ship the secret key in an app.
3. Optionally enter the topics used by your application (comma separated). They become filters on the inbox screen.
4. Tap **Save**, allow notifications, and wait for the push registration. The SDK is started once per app launch, so relaunch the app after changing the Application Code or base URL.
5. Enter an External User ID and tap **Personalize**. Messages are stored in the inbox only for users with an External User ID.

To get messages, send push messages with *Send to inbox* enabled to that External User ID. The list refreshes when the app returns to the foreground or a push arrives, and you can also pull to refresh.

## Where to look

All SDK inbox calls are in `InboxModel` (`Inbox/InboxModel.swift`):

| SDK API | Used for |
|---|---|
| `fetchInbox(token:externalUserId:options:)` / `fetchInbox(externalUserId:options:)` | First page, next page (`cursor` = previous `nextCursor`), counters only (`limit: 0`) |
| `setSeen(externalUserId:messageIds:)` | Opening a message, swipe right |
| `deleteMessages(token:externalUserId:messageIds:)` / `deleteMessages(externalUserId:messageIds:)` | Swipe left, delete on the message screen |

Personalization and SDK start are in `App/AppModel.swift`, the screens in `Views/`.

## Things to copy into your app

- **Pagination.** Pass `nextCursor` of the last page as `cursor`, with the same topic. `nil` means there is no further page. Changing the user or topic starts a new list, and responses of the previous list are dropped.
- **`INVALID_CURSOR`.** Don't retry the same cursor. Load the first page again.
- **Deleting.** Delete uses the same authorization as fetch: the same JWT for the same user, or the Application Code. Missing or already deleted IDs succeed too.
- **Eventual consistency.** A fetch made right after a successful delete or mark as read can still return the previous state and counters. The example keeps the deleted and read IDs for as long as the app runs, and corrects every fetched page with them. A page can be empty after deleted messages are removed, so "Load more" stays available while there is a `nextCursor`.
- **Counters.** Show them as the server returned them, and don't decrement them locally. After a delete or mark as read the example refreshes them with a `limit: 0` fetch.
- **JWT.** In your app, get the token from your backend. The backend authenticates the signed-in user and signs a short-lived JWT with `sub` set to their External User ID. Reuse it until it expires, and request a new one when a request fails with `UNAUTHORIZED` or `JWT_TOKEN_EXPIRED`. `setSeen` doesn't need a JWT: it uses the Application Code and the push registration of the installation. See [JSON Web Token (JWT) structure and generation example](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/JSON-Web-Token-(JWT)-structure-and-generation-example).
- **Errors.** Server errors have the error code in `mm_code` and the HTTP status in `mm_httpStatusCode`. Fetching and deleting fail with `NoRegistration` until the push registration completes. Invalid arguments (an empty list of message IDs, a blank ID, External User ID or token) are rejected by the SDK before a request is sent, with `mm_code` `20013`.

## Tests

`LiveInboxAPITests` calls a real Infobip environment through the SDK and checks how errors are reported. The tests are skipped unless the environment is configured:

```bash
TEST_RUNNER_INBOX_LIVE_APP_CODE=<app code> \
TEST_RUNNER_INBOX_LIVE_BASE_URL=<base URL> \
TEST_RUNNER_INBOX_LIVE_USER=<External User ID> \
xcodebuild test -project InboxExample.xcodeproj -scheme InboxExample -destination 'platform=iOS Simulator,name=iPhone 17'
```

The tests save these settings and skip if the app was started with another Application Code (relaunch the tests), or if the installation gets no push registration within 30 seconds. Set `TEST_RUNNER_INBOX_LIVE_DELETE_ALL=1` to also delete every message of that user in one request.
