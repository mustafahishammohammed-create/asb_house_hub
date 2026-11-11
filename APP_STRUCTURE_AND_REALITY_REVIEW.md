**ASB House Hub — structure and implementation reality**

Reviewed 6 November 2026, checkout 4a23cbf. This report follows the current executable source and its checked-in Firebase rules. The earlier code-change proposals describe a previous checkout and suggested implementations. A suggestion in those Markdown files does not establish that a feature has been implemented. Production deployment, actual school data, billing state and external accounts were outside this review.

**Overall assessment**

The app contains substantial functioning Flutter interface code, Firebase readers and writers, local persistence, and some genuine backend functions. Its maturity varies sharply across features. The weakest part is the connection between a visible official outcome and the authoritative record that should prove it. Several screens can say paid, verified, published, renewed or awarded before that outcome has occurred in the school's data.

A percentage such as “80% complete” would obscure this. An animated card, a successful remote write, a private record, a paid order and an eligible vote have very different requirements. The feature inventory below shows which part actually exists and which step remains missing.

There are 67 Dart files under lib, including 23 screens, 15 model files, 10 services and 13 reusable widget files. The source contains 58,199 lines, including generated localization Dart. The largest files are AcademicsScreen at 7,004 lines, HomeScreen at 5,496 and AuthService at 4,958. Code volume demonstrates implementation effort, but does not measure operational completeness.

**How a user moves through the app**

~~~text
main.dart
  Initialize device preferences and theme
  Initialize Firebase
  MaterialApp + English/Arabic localization delegates
  AuthGate
    Onboarding
    Login / Signup
      Ordinary Firebase account
      Special administrator path
      Saved sibling/account switching
    HomeScreen
      House overview and leaderboard
      Notices, ticker and moderated event wall
      Claim submission and approved claims
      Academics
        Timetable
        Homework
        Exams
        Report cards and honours
        Attendance and medical leave
      Elections
        Legacy chamber — existing main route
        New management page — chamber app-bar action
        Legacy audit/gazette screens — no caller found
      Sports
        Fixtures and tournaments
        Live match HUD
        Accolades, trophies and house points
      House Arena
        Spirit Reactor
        Brain Blitz
        Cup Oracle
        Badges and 3D mascots
      Merchandise store
        Catalog, favorites and cart
        Local orders and checkout receipts
      Digital wallet
        Student, store and tuition passes
        PDF export and native-wallet-labelled buttons
      Council/student chat
      House AI
      Profile, library and settings
      Staff routes
        Claim/leave moderation
        Scanner and conduct evaluation
        Roster/positions and publishing controls
~~~

Home's “School Calendar” action opens the academics exams tab. The wider holiday/event calendar implied by the label needs additional workflow. “Campus Events & Competitions” advertises registration, but the event browsing flow has no demonstrated registration record and confirmation. Navigation compares visible title strings in several places, so a translated or renamed label can change dispatch. See [Home action routing](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart:3084).

**The layers below the screens**

| Layer | Actual responsibilities | Consequence |
|---|---|---|
| App entry and theme | Firebase setup, auth gate, dark/light/system mode, house colors and localization delegates | A real app shell. Firebase initialization errors are logged and the same app continues to launch. |
| Screens | Forms, navigation, display, role checks and some direct database writes | Screen behavior and permission checks are spread across large files. |
| AuthService | Accounts, saved credentials, caches, academics, claims, scores, conduct, elections, sports, notices and leave | Most official business operations depend on one service that also owns local fallback behavior. |
| ChatService | User discovery, rooms, messages, read states and notification queue writes | Actual Firestore messaging exists. Room, message and notification updates can diverge after partial failure. |
| GeminiAiService | A real text API request when a key is configured, cached school context, keyword-based fallback answers | External generation and local canned answers share one response channel. |
| Security-labelled client services | HMAC tokens, QR verification, sports/election proof strings and cooldown calculations | Their bundled keys and client-generated inputs cannot independently certify an official school event. |
| Models | Convert dates, fields and records between Firestore, cache JSON and widgets | They describe data. They do not by themselves validate school policy or authority. |
| SharedPreferences and local stores | Saved accounts, reusable passwords, records, receipts, cart and cached views | These can make a screen look complete before a server write succeeds. Some caches have insufficient ownership boundaries. |
| Firestore and Storage rules | Actual access control for direct client reads and writes | Broad allows expose private records. New election/library collection rules are missing. |
| Cloud Functions | Certificate OCR trigger plus the newly added election and library callables | Most remaining school mutations still happen from Flutter. The academic, sports, store and private-chat server modules in the proposal guides have not been added to executable Functions source. |

The checked-in backend exports three functional entry points. [Functions entry point](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/functions/index.js:19)

~~~text
Flutter screen
  -> AuthService / another service / direct Firestore call
  -> local cache and/or Firebase write
  -> screen success message
  -> another user's read

New election path
  -> SchoolElectionsPage reads school_members
  -> reads published polls and staff drafts
  -> HTTPS callable schoolElection
  -> trusted roster check and transaction
  -> authoritative receipt/result

Certificate path
  -> Storage upload
  -> Vision logo/text detection
  -> house_claims status update
  -> staff queue
  -> approval and point writes
~~~

The crucial question for every feature is whether the next user can see the committed result. Updating the first user's widget or cache establishes only a local change.

**What changed since the earlier review**

| Area | Current truth |
|---|---|
| Elections | Draft, candidate addition, publication, voting, receipts and certification now have real UI and backend implementations. The rules and membership provisioning needed to use them remain missing. |
| Library | A real checkout/renewal/return backend was added. The displayed library still uses hardcoded books and only updates local widget state. |
| PDF | A native PDF producer and file writer now exist. The button still announces success immediately without awaiting or checking the result. Web returns a synthetic success without starting a download. |
| Home attendance | It now calculates from cached records or reads a profile value. Missing records still produce 100.0%, and its formula differs from the attendance tab. |
| Administrator authentication | A special scholar path now accepts embedded credentials and caches administrator identity before the Firebase attempt finishes. The most recent change restored this path and saved-password switching. |

**Feature-by-feature reality**

| Feature | Implemented behavior | Missing, overstated or broken behavior | Source |
|---|---|---|---|
| Ordinary login/signup | Firebase sign-in and Auth account creation, plus a users profile | No verified roster membership provisioning. Self-entered or privileged local identifiers still influence access elsewhere. | [Signup](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:2407) |
| Administrator access | A special login route, cached admin profile and UI role helpers | Embedded accepted passwords, cached privilege before authenticated completion, and scholar-based super-admin classification. Embedded passwords are omitted from this report. | [Special sign-in branch](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:2266), [role helper](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/hierarchy_service.dart:14) |
| Sibling switching | Saved account picker and an attempt to authenticate the selected account | Cache switches first. Failure can leave the selected visual identity ahead of actual authentication. Reusable passwords are reversibly encoded with an app-bundled key. | [Switch account](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:2114) |
| Timetable | Real class records, editing, a template and schedule display | Staff editing is insufficiently gated in the tab. Clearing the day is a sequence of deletes with failure absorbed. | [Timetable operations](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:712) |
| Homework | Shared task list, due dates, add/delete and status buttons | One class-wide status cycles pending → submitted → graded → pending. No independent saved student answer or assessor-owned grade. Remote rejection can still update the local display and attempt a reward. | [Status handling](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:928) |
| Exams | Real composer, batch write and exam display | Grade and section IDs can disagree, hiding a grade-wide exam from a section reader. Invalid grade ranges broaden silently. | [Exam publication](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:1198) |
| Reports/honours | Real report storage, per-scholar filtering and rich report view | Document IDs omit school year. GPA/reward inputs and client proof can drive honours before the claimed flag is committed. Broad rules expose reports. | [Report handling](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:1442) |
| Attendance | Real daily register records and staff/student views | Default cache ownership is weak. Home counts excused fully and late half, while the tab counts present days only. Empty data can appear as 100%. The stated 75% policy is a hardcoded label/threshold whose external authority was not established here. | [Home formula](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart:5048), [tab formula](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/models/attendance_record.dart:182) |
| Medical leave | Photo/form submission, review controls and history | Approving leave never updates the daily register. Errors can still be reported as success. “Approved (Excused)” promises an attendance effect the handler does not perform. | [Approval](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:4876) |
| Notices | Composer, attempted database write and recent feed | Writer fields disagree with the rule allowlist. The catch returns true, and the form announces publication. Audience selection is not enforced by the feed. | [Publisher](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:4753) |
| Campus events | Real read stream, event cards and search/category filters | Staff creation/publication and student registration are incomplete. House filtering and live-state expiry are incomplete. | [Event reader](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/events_screen.dart:43) |
| New elections | Real server-managed draft, roster candidate lookup, publish, eligibility, duplicate prevention, receipt and certification | The first membership read and v2 feeds are denied by the checked-in rules. Signup writes users only. The main tile still opens the old chamber. Live deployment is unverified. | [New page](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/school_elections_page.dart:63), [new backend](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/functions/elections-v2.js:91), [default deny](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/firestore.rules:532) |
| Old elections | Candidate rendering, local receipt/proof creation and attempted vote transaction | Student transaction reads an admin-only vote lock. Open totals are directly mutable under the old rule. Complete anonymity, audited inclusion and certification exceed the guarantees. | [Vote write](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:3723), [old rules](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/firestore.rules:694) |
| Merchandise | Real catalog UI, size/quantity selection, favorites, local orders and attempted remote writes | No payment-provider confirmation or stock reservation. Checkout starts an order ready and labels zero-point cash orders paid. | [Checkout](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/merch_store_tab.dart:839), [paid label](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/merch_store_tab.dart:1111) |
| Store collection | QR parsing and order update code | Reads and updates happen separately. Local fallback can report fulfilment. Two counters can race. Generated zero-point cash tokens fail the positive-points validator. | [Voucher handling](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/voucher_security_service.dart:428) |
| Tuition fee pass | Rendered pass and QR | Fixed receipt ID, PAID IN FULL, Verified Electronic Payment and BHD 150.000. This screen never looks up the student's actual fee payment. | [Tuition pass](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/digital_wallet_screen.dart:772) |
| Native wallet/NFC | A button and in-app success sheet | No provider pass issuance, actual wallet save or NFC provisioning in that handler. | [Wallet action](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/digital_wallet_screen.dart:1240) |
| PDF pass | Real PDF bytes and native file-write attempt | UI ignores completion/error/location. Web reports success without downloading. QR data is printed as text, with no scannable QR image. Arabic shaping/font embedding is absent. | [Exporter](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/pass_document_exporter.dart:8), [button](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/digital_wallet_screen.dart:1743) |
| Library | Exported transactional backend for checkout, holds, renewal and return | Home never calls it. Three fixed books and local due-day increments persist only in the screen state. No librarian workflow or loan collection rules. | [Home list](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart:175), [local renewal](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart:5296), [backend](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/functions/library-v2.js:25) |
| Certificate verification | Real upload and Vision logo/text requests | Keywords such as principal or certificate of merit determine “verified”. This is insufficient evidence of authentic issuance/signature. OCR states miss the staff pending/approved queues and can overwrite a human decision. | [Verification heuristic](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/functions/index.js:111), [queues](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:2720) |
| Claim award | A transaction blocks an already-approved repeat and updates house/contributor totals | Missing/rejected claims and caller-supplied house/points are insufficiently checked. Subsequent profile/notification writes can fail separately. | [Claim approval](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:2736) |
| Conduct/merits | Real staff controls, points transactions and conduct history | Points commit before the reason/history record. A failed follow-up or retry can disagree with the ledger. House and personal zero-floor calculations diverge. | [Conduct operation](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:3128) |
| Sports | Fixture editor, score events, HUD, trophies and certification code | Fixture schema disagrees with rules. Create/score failures can report local success. Stale screen totals can overwrite another scorer. Client-minted proofs cannot independently certify the result. | [Score write](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:4101), [fixture create](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/auth_service.dart:4636) |
| Brain Blitz | Working questions, timer, local marking and award attempt | Answers and score are on the client. Student award writes target staff-only totals. A celebration can precede denial. The advertised daily limit is not enforced on this path. | [Quiz completion](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_arena_screen.dart:451) |
| Spirit Reactor | Tapping, combos, animations and sync attempt | Initial values are invented. Every fifth tap overwrites all four values from one device, so concurrent updates can be lost. | [Initial scores](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_arena_screen.dart:164), [sync](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_arena_screen.dart:351) |
| Cup Oracle | Working interactive sliders and a calculated result | The “championship probability” is a slider formula against a fixed benchmark, clamped to 5–95%. No statistical model or live rival history supports the percentage. | [Calculation](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_arena_screen.dart:1387) |
| Badges | Real badge artwork, sorting and inspection | Several earned states/dates are constants, including points, discipline and NFC claims. Summing displayed badges does not establish actual earned merit. | [Badge list](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/widgets/apple_fitness_badges_vault.dart:140) |
| 3D mascots | Real generated meshes, perspective, lighting, depth sorting, rotation, zoom and particles | The displayed meshes are created in Dart. The supplied Blender files are not loaded by the rendering path inspected. | [Renderer](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/widgets/mascot_3d_stage.dart:3204) |
| Battle chant | Real timed system sounds, haptics, visuals and lyric text | The audio uses system alerts/clicks. There is no demonstrated generated sung/spoken chant. | [Sound implementation](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/widgets/battle_chant_synthesizer.dart:158) |
| Chat | Real rooms/messages, stream updates and read states | Room filtering protects the ordinary UI only. Rules let signed-in users read other rooms/messages. “Push triggered” is a stored flag and notification queue write, without actual device delivery. | [Chat stream](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/chat_service.dart:41), [rules](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/firestore.rules:750), [send](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/chat_service.dart:237) |
| House AI | A genuine generateContent API call using a supplied key, with conversation text and school context | “Live” school context comes from cached records. Missing/failing API calls use keyword-based answers. Key presence drives the live badge. No live audio session or autonomous school-system action is implemented. | [AI request/fallback](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/gemini_ai_service.dart:268), [greeting](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_ai_chat_screen.dart:84) |
| Notification settings | Toggle widgets and several notification document writers | No device-token registration, push sender or student inbox reader was found in the executable source. The switch resets each time the sheet opens. | [Settings](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart:5334), [notification writer](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/chat_service.dart:288) |
| Effects setting/cache clear | Toggles and success feedback | Effects toggle is sheet-local. Cache clear only closes the sheet and announces a cleanup. | [Settings handlers](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart:5378), [cache-clear handler](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart:5445) |
| Theme/localization | Real persisted theme modes, house colors and generated English/Arabic resources | No use of AppLocalizations in screens/widgets was found. Many actual labels remain English literals. A supported locale declaration does not translate those labels. | [App configuration](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/main.dart:63), [theme controller](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/theme/app_theme.dart:433) |

**Campus-events update (2026-11-10).** The campus-events row above and the published-event/registration row below are now closed for Spark scope. `events_screen.dart` has a staff-only composer with preview, publish, private draft, edit, and cancel-with-reason; the list has house filtering and honest upcoming/live/concluded/cancelled states; and `events/{eventId}/registrations/{uid}` stores self-owned RSVPs that staff can read as a participant list. The remaining limits are the absence of an authenticated end-to-end Firebase run, device-calendar or push reminders, live audio, and automatic points for attendance. See `development_plan/M8_VERIFICATION.md` for the test and deployment evidence.

**Why a polished screen can still be incorrect**

Homework illustrates the distinction. A teacher should publish a task, Student A should send a submission, the teacher should grade A, and A's grade should appear without changing Student B's submission. The current class task holds one status. The screen can render the full set of status chips, while the required per-student workflow is absent.

The library illustrates disconnected implementation. The server has a real one-renewal policy, but Home increments a local number repeatedly. Those two pieces do not communicate. A successful demonstration on one screen does not renew the record a librarian would use.

PDF illustrates inaccurate acknowledgement. The native exporter can write a file. The button starts it and immediately announces Downloads without checking the returned path or error. The missing await/result check makes a real implementation appear successful even on failure.

Chat illustrates the difference between normal navigation and enforced privacy. The chat-list query filters to the current user, but a direct read of another room is permitted by the broad rule. Privacy must hold when a caller bypasses the screen's query.

The new election illustrates a blocked integration. It first requires an active school_members record, then reads the v2 ballot feed and invokes a server transaction. The rules currently deny those first reads and there is no trusted membership setup path in the app. Adding the screen and callable did not complete this operational dependency.

**Records that should agree but currently can diverge**

| Record pair | Why agreement matters | Current gap |
|---|---|---|
| Auth UID and displayed cached student | Every private read/write must belong to the shown account | Cache can change ahead of authentication. |
| users profile and school_members | Old and new features need the same verified identity | Normal signup creates only users. |
| Homework task and individual submission | One student must not complete another student's work | Independent submission is absent. |
| Approved leave and attendance day | An excused day must appear in the register | Approval writes only the leave record. |
| Payment and ready/paid order | Pickup must correspond to actual settlement | Checkout declares readiness locally. |
| House points and conduct/award record | Every total change needs one attributable event | Separate writes and retries can diverge. |
| Published event and student registration | Staff need to see actual accepted participants | Registration workflow is absent. |
| Election receipt and accepted vote | A receipt must prove a committed server action | Legacy receipt has local/missing-ballot success paths. |
| Certificate scanner state and moderation queue | Staff must be able to see every unresolved claim | Scanner and queue use different status names. |
| Notification document and device alert | The claimed alert must reach the intended recipient | Device-delivery infrastructure is absent. |

**Infrastructure claims also need correction**

The infrastructure guide promises that Firebase is free forever and requires no payment. The app now depends on deployable Cloud Functions and uses Cloud Storage and Vision. Firebase's official documentation requires the Blaze plan to deploy Functions. Usage can fall within included allowances, but a guaranteed zero-cost promise does not follow from that. The configured project billing plan, deployment and actual usage were not inspected. [Local claim](C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/INFRASTRUCTURE_AND_PRICING_GUIDE.md:55), [Firebase Functions deployment requirements](https://firebase.google.com/docs/functions/get-started)

**What would establish completion**

For each official feature, verify one complete path using two different users. A staff member creates or approves the record, the server confirms it, the correct student sees it after restarting, a different student cannot read or alter private parts, and retrying after a lost response does not duplicate the outcome. That is especially necessary for election votes, rewards, leave approval and order collection.

Treat a displayed number as trustworthy only when its source, owner, date and calculation are known. Record the last successful sync. An empty register should say that no register has been recorded. A payment screen needs a verified payment record. A generated certificate/photo needs a review decision. A probability needs a justified model. The current code does not consistently maintain those distinctions.

Prioritize the special administrator bypass and access rules, then finish one election route with membership setup, per-student academic records, and reliable store/payment collection. Then correct the obvious presentation claims, connect library and notifications, and improve the remaining UX. Backgrounds, animations and mascots already have considerable implementation.

**Review scope and verification**

This is a source and navigation/dataflow audit of checkout 4a23cbf. The earlier 253-test result belonged to the earlier review. The current test file contains 257 test declarations. The new election test only mounts an unauthenticated screen. The PDF test exercises its byte structure and file writer. The attendance test checks arithmetic. None of those alone demonstrates a teacher-to-student school workflow under Firebase access rules.

Current Dart analysis of lib, test and tool in a disposable copy returned zero errors, zero warnings and 20 informational lints. This validates static code structure. The deployed rules, callable deployments, school roster and payment operations remain unverified. Generated platform code, dependencies and binary artwork were not audited line by line. The findings above identify concrete source behavior and integration gaps.

