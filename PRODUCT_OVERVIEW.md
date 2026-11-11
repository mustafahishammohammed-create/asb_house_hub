# ASB House Hub — Product, Feature, and User-Experience Overview

**Purpose:** A self-contained product handoff for another AI to brainstorm high-impact features, upgrades, and creative directions without needing to start by reading the implementation.

**Snapshot:** 6 November 2026. This overview draws on the current local application, recent development history, and existing change proposals. The project is being actively edited. Features described as current have interface or implementation support; that does not mean their complete multi-user workflow or production deployment has been verified. The election area contains unfinished source edits, so this document is not a statement that the current checkout is release-ready.

**Status language:** **Current** means implemented interface/behavior; **partial** means a meaningful part exists but the promised outcome is incomplete or unreliable; **proposed** means described in project documents, not an approved delivery commitment; **opportunity** means a new direction suggested here. Previously discussed ideas below are sourced from the repository's proposals and feature copy, not reconstructed from unavailable chat history. No credentials or API keys are included.

## Core Vision & Value Proposition

### The central idea

ASB House Hub is a school-life companion organized around the inter-house culture of **The Asian School in Bahrain**. Its distinctive proposition is to combine everyday school utility with the emotional pull of belonging to a house: a student's timetable, homework, achievements, conduct, sports participation, school elections, and digital identity all sit alongside house standings, mythical mascots, collectible honours, and friendly rivalry.

The problem it addresses is fragmentation. Students otherwise need to find school information in separate notices, classroom instructions, paper documents, conversations, and event announcements. Recognition is also fragmented: a competition win, helpful behavior, good academic performance, or sports achievement may never become a visible part of the student's contribution to the school community.

The primary goal is therefore broader than tracking points: **make school life easier to navigate, make participation feel meaningful, and make recognition visible.** A successful version answers four recurring questions:

- What do I need to do today?
- What is happening at school and in my house?
- How can I contribute, and how will that contribution be recognized?
- Where can I access the people, records, and passes I need?

For staff, the corresponding promise is a practical route from a school action—publishing a task, approving an achievement, recording conduct, certifying a match—to an accurate student-facing outcome.

### Why the concept is compelling

This is not designed like a plain administrative portal. It combines three product layers:

1. **Utility:** academic schedules, attendance, notices, leave requests, digital ID, direct messaging, and school services.
2. **Participation and recognition:** house points, contributor rankings, certificate claims, sports awards, student elections, and personal contribution records.
3. **Identity and spectacle:** house-colored interfaces, mascot mentors, a game-like Arena, heraldic honours, chants, and an interactive 3D mascot sanctuary.

The intended emotional loop is: **participate in real school life → receive trustworthy recognition → see your contribution help your house → feel motivated to participate again.** The strongest potential is making useful routines and meaningful accomplishments reinforce belonging, rather than relying on unrelated mini-games to keep students opening the app.

### House identity

The current executable product uses **Ruby, Sapphire, Emerald, and Topaz**. An older introductory README names Diamond instead of Topaz; the current registration, themes, store, elections, sports, and mascot experiences consistently use Topaz.

| House | Visual identity | Mascot / AI mentor | Personality and signup motto |
|---|---|---|---|
| Ruby | Crimson/red, fire, warm glow | **Ignis the Crimson Dragon** | Courage, passion, valor; “Courage & Passion” |
| Sapphire | Blue, sky, lightning | **Zephyr the Tempest Gryphon** | Wisdom, precision, truth; “Wisdom & Truth” |
| Emerald | Green, earth, roots | **Sylva the Titan Wolf** | Loyalty, unity, perseverance; “Honor & Growth” |
| Topaz | Amber/gold, sunlight | **Solis the Golden Chimera** | Optimism, charisma, sportsmanship; “Light & Excellence” |

These identities appear across registration, Home, chat, honours, mascots, and mentoring. Fantasy founding stories, relics, and rites provide creative world-building; they should not be treated as verified school history. House language is not completely standardized across screens.

Product identity reference: [lib/theme/app_theme.dart:5](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/theme/app_theme.dart#L5).

## Target Audience & Use Cases

### Primary audiences

| Audience | Biggest needs and pain points | Typical real-world use |
|---|---|---|
| **Students** | Knowing what is due, finding school information, getting fair recognition, understanding attendance, accessing school services | Check the next class; inspect exam syllabus; submit a competition certificate; show a digital ID; follow house standings; contact a teacher or council member |
| **Prefects, captains, and student council members** | Coordinating participation, being approachable, understanding their responsibilities, maintaining house morale | Respond to student messages; follow fixtures; encourage participation; use leadership tools where school policy permits |
| **Teachers and faculty** | Fast publishing and recordkeeping, fewer disconnected forms, reliable student-specific outcomes | Publish exams/report cards; mark attendance; review medical leave; scan an ID to record a merit or demerit |
| **School administrators / super administrators** | Managing authority, public communications, moderation, and institutional trust | Appoint council roles; broadcast an announcement; oversee achievement claims; manage elections and school records |
| **Sports officials / activity coordinators** | Scheduling competition, recording scores, recognizing participants, avoiding disputed results | Create a fixture; run the match console; nominate an MVP; certify a result; issue a trophy |
| **Families sharing a device** | Convenient access to more than one child's account without confusing their identities or records | Add another student's credentials and switch between sibling profiles |
| **Store staff and librarians** | Confirming identity, collection, borrowing, and returns | Scan a pickup pass; verify handover; eventually issue and renew real library loans |

Registration currently targets students in **grades 6–12**. Some staff forms and election policies cover other grade ranges, so a single consistent whole-school eligibility model has not yet been established.

Families are an implied audience through sibling switching, **not an implemented guardian role**. There is no separate parent dashboard, guardian consent workflow, or verified family relationship. Librarian workflows exist on the backend but are not connected to a usable librarian interface.

### Concrete usage scenarios

- **Before the first lesson:** a student opens the app, sees their house identity, finds today's timetable, and checks whether homework or an exam needs attention. Today this requires visiting separate academic tabs rather than a unified daily agenda.
- **After winning an external competition:** the student photographs the certificate, requests recognition points, follows the review status, and later sees approved contribution totals. Public featuring on the Event Wall is a separate moderation step.
- **During an assembly or corridor interaction:** a teacher scans a student's ID, selects a positive or negative conduct reason and point value, and records the evaluation. The student can later see the citation and its contribution impact.
- **On sports day:** students browse fixtures and standings; an official records match points, uses a period timer, nominates an MVP, and certifies the result. Spectator score synchronization and authoritative timing still need completion.
- **During election season:** managers prepare candidate slates; eligible students inspect manifestos, cast a vote, and receive a receipt; the school publishes certified outcomes. Two parallel election systems currently complicate this journey.
- **When absent for medical reasons:** a student submits dates and medical information, then checks the decision. The intended result is excused attendance, but approval currently does not update the attendance register.
- **At the school store:** a student chooses merchandise, creates an order pass, and presents it at the counter. Actual reservation, payment acknowledgment, and safe one-time collection are not yet a complete flow.
- **In a shared-device household:** one sibling checks school information, switches profiles, and the next student sees their own house and records. Reliable authentication and private-data isolation are essential, not just a quick visual transition.

### Role model

The interface recognizes Student Member, Grade Prefect, House Captain, Student Council, Faculty Lead, and Super Admin families. Council variants include head/deputy head roles, cultural and sports leadership; captain and faculty aliases also exist. Most elevated roles expose a broad set of leadership controls, while exams, report cards, and attendance publishing are more faculty-focused. Super-admin adds roster management and ticker broadcasting.

**Important limitation:** visible permissions are not uniform across screens, backend rules, and election capabilities. A prefect or captain may see a control that the backend does not permit them to use. These are intended access patterns, not a fully resolved institutional authorization policy.

Role reference: [lib/services/hierarchy_service.dart:5](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/hierarchy_service.dart#L5).

## Complete Feature & Workflow Breakdown

### 1. First launch, registration, login, and sibling accounts

**Onboarding — current.** A first-time signed-out installation sees three swipeable slides:

1. “Welcome to the Arena of Houses”: house pride, championship standings, honours, and mascots.
2. “Your Personal AI House Mentor”: timetable, attendance, and homework assistance.
3. “Classroom Mastery & Pitch Glory”: academic tracking, sports, and report cards.

Users can skip, advance with “Next Step,” or complete with “Continue to Sign In.” Completion is remembered for the installation. This is promotional onboarding, not a house-sorting quiz or personalized school induction; illustrated progress values are examples.

**Student signup — current, with enrollment gaps.** The four steps are:

- **Identity:** full name and a five- or six-digit scholar number.
- **Academic:** grade 6–12, section A–F, and an age control from 10–20, initially 14.
- **House:** manually choose the assigned Ruby, Sapphire, Emerald, or Topaz house.
- **Security:** password and confirmation, visibility controls, and an animated Weak/Fair/Good/Strong meter.

Back navigation and previously unlocked step indicators preserve entered values while the form remains open. Selecting a house transforms the form's accents, focused inputs, progress, ambient colors, and main button; a “THEME ACTIVATED” panel introduces its mascot and motto.

Completing registration creates authentication and a student profile, saves local account information, and attempts school-membership setup before opening Home. Errors include duplicate accounts, weak passwords, and connection failures. There is no verified registrar invitation, guardian consent, or authoritative validation of the entered house/grade. Enrollment is not a finished school-controlled workflow.

**Login — current.** Student Login uses scholar number and password; Admin Login changes the visual treatment and accepts an administrator identifier. Ordinary accounts use Firebase authentication; elevated access is checked against the retrieved role. A special administrator path exists, but no credential details are included here. Loading, password visibility, Enter submission, and useful credential/network errors are implemented. “Forgot Password?” currently advises contacting school administration rather than completing a recovery flow. Google/Apple sign-in, OTP, and biometric login are not exposed.

**Account switching — current but security-sensitive.** The account sheet shows saved names, house colors, scholar numbers, an ACTIVE badge, Switch, Add Sibling / Another Account, removal, and sign-out actions. Adding an account authenticates its supplied credentials and loads its profile. It is device-local convenience, not proof that accounts belong to one family. Switching prioritizes an immediate cached identity change while authentication catches up; reusable credential material is stored locally. The next version needs a verified session transition before showing private records, while preserving the convenience.

References: [lib/screens/onboarding_screen.dart:43](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/onboarding_screen.dart#L43), [lib/screens/signup_screen.dart:20](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/signup_screen.dart#L20), [lib/widgets/account_switcher_modal.dart:6](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/widgets/account_switcher_modal.dart#L6).

### 2. Home hub and navigation

**Current.** Four bottom destinations anchor the app: **Dashboard, Store, Standings, Profile**. The selected destination gains an animated pill and label. A drawer contains the wider school-service menu; toolbar shortcuts adapt to available width.

Dashboard reads top-to-bottom as:

1. Persistent brand header and optional school broadcast.
2. House-gradient identity card with name, scholar number, class, school, and contribution.
3. Review-portal promotion for elevated roles.
4. Large banners for Arena, Academics, Sports, and House AI.
5. Live House Standings.
6. Eight stacked Student Services cards.
7. Notice Board & Circulars.
8. Live Event Wall.

The eight service cards are **Switch Account / Siblings, Submit House Claim, 1-on-1 Council & Student Chats, Attendance Record, School Calendar, Campus Events & Competitions, Student Council Elections, and Inter-House Sports League**.

The drawer additionally provides academic profile, wallet/ID/fee passes, leadership scanning, honours, library, settings, and sign-out. The Standings destination repeats house rankings with a possible first-place celebration; Profile repeats identity and adds contribution history.

**Partial navigation promises:** School Calendar is an Exams shortcut, not a comprehensive calendar. Some services are represented in several places with different labels. Routing relies partly on visible titles, which complicates renaming and translation. The home experience is a rich launchpad, but not yet a focused “what matters today” agenda.

Reference: [lib/screens/home_screen.dart:1537](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/home_screen.dart#L1537).

### 3. House standings, contributor rankings, and student profiles

**Current.** House standings show rank/medal, color, total points, and a bar representing the house's share of all school points. Users tap any house to open its leaderboard, switch houses, search students by name or scholar number, inspect the top-three podium, and browse all contributors.

Each house leaderboard includes a house banner/motto, captain, total points, and **Sports, Academics, Cultural, and Conduct** breakdowns. The breakdowns are display totals, not interactive filters. The podium appears when enough contributors exist and search is empty. No seasonal, grade, or date-range ranking is currently offered.

Tapping a contributor opens a student profile with **Merits & Accolades** and **Conduct Ledger**. Elevated viewers also get merit/demerit actions and a direct-chat shortcut. Profile-tab contribution history shows net points, merit/demerit counts, and recent teacher evaluations. Certificate awards increase totals but do not necessarily appear as teacher conduct entries.

**Partial:** live feeds coexist with cached totals, some empty states are mistaken for offline states, category subtotals can lag award totals, and profile metrics can disagree between screens. Private conduct must not become a public leaderboard feature; denied or unavailable records should not be presented as a clean record.

References: [lib/screens/house_leaderboard_screen.dart:216](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_leaderboard_screen.dart#L216), [lib/widgets/student_profile_modal.dart:133](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/widgets/student_profile_modal.dart#L133).

### 4. Achievement claims, certificate review, and approved gallery

**Student flow — current.** “Submit House Claim” asks for an activity/competition title, requested **10, 25, or 50 points**, and a required certificate image. Students take a photo or choose an image, preview/replace it, and submit for verification. Uploading disables the button. “My Certificate Claims” shows Under Review, Approved with points, or Not Approved with feedback.

**Review flow — current.** The review portal's Point Claims tab shows pending claims with student identity, house, requested points, search, and a zoomable certificate. Reviewers can inspect, approve, or reject; an Approved Achievements Gallery provides a searchable, house-filtered archive and certificate inspection. It is principally a staff review archive, not a general public social gallery.

**AI assistance — partial.** Certificate uploads can trigger Google Cloud Vision logo/OCR analysis. Review cards display scanning, seal-matched confidence, or warnings requiring manual inspection. This is assistive recognition of logos and text phrases, **not proof of a genuine signature or authentic certificate**. Staff still make the decision.

Approval updates claim status, house/contributor totals, and merit count together, with profile/notification updates afterward. The already-approved guard helps prevent repeat credit, but evidence binding, late AI updates, fallbacks, and the complete audit/notification chain remain incomplete. Some failure paths can still announce submission success without a durable record.

The student submission also attempts a pending Event Wall post. **Award approval and public featuring are separate actions**, and currently are not coordinated. A future flow should offer a consented public celebration image distinct from private certificate evidence.

Reference: [lib/screens/admin_claims_screen.dart:264](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/admin_claims_screen.dart#L264).

### 5. ID scanner, merits, demerits, and staff evaluation

**Current.** Students present a digital ID; eligible staff/leadership users open the scanner. Android/iOS support live camera scanning, flashlight, and camera switching. Other paths accept an uploaded QR image or typed scholar/QR text. Loading, unknown-student, unreadable-image, and camera-retry states exist.

A resolved student opens **Student Conduct & House Evaluation**:

1. Review identity, house, and class.
2. Select **Well Behaved** or **Misbehaviour**.
3. Choose a reason preset or edit the citation.
4. Choose **5, 10, 15, 25, or 50** positive/negative points.
5. Submit and view the recorded-outcome dialog.

Positive reasons cover academic initiative, helping peers, sportsmanship, service/cleanliness, leadership, and discipline. Negative reasons cover incomplete work, lateness, uniform issues, disruption, hallway misconduct, and disrespect. The evaluator can inspect recent conduct history; profile sheets provide further conduct actions.

The flow changes house and personal contribution totals and separately writes a conduct record and notification. House totals have a zero floor, while personal net contribution may be negative. These are recognition/contribution measures, **not a demonstrated spendable cash balance**.

**Partial:** ID scanning does not establish a live, revocable campus-access credential. Role visibility, backend permission, transaction history, and retry behavior need alignment. A scan-to-merit record should be one attributable institutional action, not several outcomes that can diverge.

References: [lib/screens/id_scanner_screen.dart:60](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/id_scanner_screen.dart#L60), [lib/screens/student_behavior_evaluation_screen.dart:33](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/student_behavior_evaluation_screen.dart#L33).

### 6. Notices, school broadcast, Event Wall, and campus events

**Notices — partial.** The Home notice feed shows the latest five circulars with date, title, and content. A composer offers Academic, Sports, Examination, Holiday & Closure, and General categories; audiences include all students and grade bands 6–8, 9–10, and 11–12. The intended journey is compose → broadcast → relevant students read. Currently the composer is too broadly visible, audience targeting is not enforced by the feed, and publication can report success after a rejected write. There are no acknowledgments or searchable circular archives.

**Broadcast — current.** Super-admin edits a school-wide message and active toggle. Users see an announcement strip. Despite “ticker” terminology, it is a single-line banner, not a scrolling marquee or device push.

**Event Wall — current, moderation incomplete.** Image posts show house identity, author, caption, and heart reactions. Ordinary students see approved posts; elevated users also see pending submissions. Moderators can Feature a pending post; authors/moderators can delete with confirmation. Likes are intended to toggle once per student. There are no comments, free-form peer posting composer in this Home flow, reporting tools, or true share action. Its explicit contribution path is certificate submission. Public visibility and points approval are independent.

**Campus Events & Competitions - current for Spark scope.** "Campus House Events" streams published events with All/Cultural/Sports/Academic/Arts/Technology filters, a house-scope filter, search, and event details. Cards and details show upcoming, live, concluded, and cancelled states. Staff get a composer with preview, publish, private draft, edit, and cancel-with-reason, plus a participant list built from real registration documents. Students can register or withdraw; registration is stored under the event, is limited to the signed-in student, and closes once an event is cancelled or concluded. Local/sample mode stays device-only and does not pretend to collect live registrations.

**Remaining limits:** there is no device-calendar insertion, push reminder, live audio stream, automatic spirit-point award, or authenticated end-to-end Firebase test. The screen reports those actions honestly instead of simulating them. A combined school calendar beyond exams is still not implemented.

Reference: [lib/screens/events_screen.dart:27](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/events_screen.dart#L27).

### 7. Campus Academics: five tabs and medical leave

The academic hub contains **Class Timetable, Homework Tracker, Exam Schedule, Report Cards, and Attendance**. Medical leave is inside Attendance. It is positioned as a “Campus Academics Command” rather than a separate learning platform.

#### Class Timetable — current, with template and access limitations

Students browse **Sunday–Thursday**, see periods, subjects, teachers, rooms, and timing, and get current-class or next-class emphasis. The screen refreshes timing periodically and can announce transitions for accessibility.

The editor chooses weekday, P1–P8, subject, standard/custom time, room, teacher, and optional break. Save/update/delete flows exist. An empty schedule can load a fixed CBSE example template; it is not an authenticated official school schedule. Editing controls are exposed too broadly even though the backend restricts writes. There is no timetable reward.

**Proposed:** staff-owned drafts, conflict checking, previewable templates, atomic publication, and schedule revisions that preserve the last valid version.

#### Homework Tracker — partial, not a complete assignment system

Subject filters, Pending/Submitted/Graded counts, task cards, teacher, reward, and relative deadline highlight urgent or overdue work. The composer collects subject, title, teacher, due date, instructions, and **10/20/30/50 merit points**.

The visible status chip cycles **Pending → Submitted → Graded → Pending**. Crucially, it changes one class-wide assignment status. Students do not have independent answer/file submissions, and teachers do not have a real grading queue. “Graded” attempts to award the current cached account, rather than an assessed individual submission. Stored instructions are not fully surfaced in the student card experience.

**Proposed complete journey:** teacher publishes a task → student saves/submits their own answer → teacher reviews and grades that submission → the student sees feedback → any approved merit is awarded once. Offline drafts and failed submissions remain recoverable.

#### Exam Schedule — current publication and browsing, with targeting gaps

Exam cards show subject/paper, date/time, marks, duration, hall, seating, and upcoming/in-progress/concluded emphasis. An expandable **Syllabus Vault** lists topics and study-reference labels. Attached circulars support zoomable preview.

Faculty/admin scheduling selects a grade range **5–12**, subject, title, date/time, duration, marks, hall, syllabus topics, and optional circular image. Publication has saving and failure feedback. There is no exam-taking flow, configurable seat allocation, broad school calendar, or scheduled reminder. Grade-versus-section naming can send records to a different class view from the student's.

**Proposed:** roster-consistent targeting, revisions/cancellations, room/time validation, and calendar integration.

#### Report Cards and Honours — rich presentation, partial official record

Students filter personal reports by term and see academic year, GPA out of 4, percentage, attendance, teacher/principal remarks, and subject-performance bars. GPA **3.80 or higher** exposes an honours panel and **Claim Honours Merit (+50 PTS)**.

Faculty can issue a report using scholar identity, grade, term, overall percentage, editable GPA, attendance, and remarks. However, the form generates five subject results from offsets around the entered overall percentage rather than accepting genuine subject-level marks. Some section/official-status/approval copy is fixed. Honours can be marked locally before settlement succeeds.

**Proposed:** year-specific private records, actual subject marks, correction history, register-derived attendance, and one evidence-based honours award from the published report. No automatic academic badge ledger currently connects this flow to Titan Vault.

#### Attendance — current recordkeeping, incomplete register experience

Students see a percentage, status totals, threshold labels, dated history, and P1–P8 breakdown chips. Staff type one scholar number, select Present/Late/Absent/Excused, add remarks, and save today's record; it applies the same status to every period. There is no roster-based batch register, date picker, per-period editor, or monthly attendance calendar.

Attendance calculations disagree: the academic tab counts only present days, while the academic-profile summary credits excused days and half of late days. Empty records can show **100%**. The app uses a stated **75% threshold**, with a warning buffer below 80%; the regulatory wording has not been independently established.

**Proposed:** one school-approved calculation, honest no-data state, school-calendar awareness, and reliable staff/student consistency.

#### Medical Leave — current submission/review, missing attendance effect

Students choose From/To dates, doctor/clinic, reason, and optional prescription image, then submit. The reason is required; the photo and doctor are not, despite certificate-focused wording. History shows Pending, Approved (Excused), or Declined and administrative feedback.

Staff review in the portal's **Medical Reports** tab, using filters/search and a zoomable prescription, then Approve Leave or Decline. Current feedback is largely fixed. Approval changes the request status but **does not mark the instructional dates excused in attendance**.

**Proposed:** approval and register reconciliation in one operation, skipping closures and resolving conflicting marks; private evidence, meaningful reviewer feedback, and recoverable error states.

Academic reference: [lib/screens/academics_screen.dart:111](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/academics_screen.dart#L111).

### 8. Elections, candidate campaigns, results, Gazette, and audit

**Current but actively in development.** Elections use a formal institutional tone: candidate manifestos, secret-ballot language, receipts, returning officers, certification, and public proclamations. Two systems coexist: the **Election Chamber** reached from Home and an **Institutional Elections v2** workspace linked from it.

Supported office concepts are **School Head Boy, School Head Girl, House Captain, House Vice-Captain, Cultural Secretary, Sports Captain, and Class Prefect**. The v2 builder omits Vice-Captain although other layers support it. Managers nominate candidates; self-service candidate nomination is not implemented.

**Candidate and voter experience:** browse office filters and candidate cards, search names/scholar numbers, inspect manifesto/pledges, confirm a vote, receive a receipt, and subsequently see recorded/selected status. Counts are intended to stay hidden until closure/certification. Eligibility includes grade and house scope in v2; gender, class-section prefect scope, and other school-policy conditions are not fully implemented.

**Manager lifecycle:**

1. Create a ballot with title, office, jurisdiction, grade range, and voting window.
2. Add candidates by scholar number; lookup fills real profile details where available.
3. Edit manifesto/name, remove candidates, and build at least a two-candidate slate.
4. Publish and freeze the slate.
5. Students vote and receive participation receipts.
6. Close voting and certify the outcome.
7. Display certified counts and a winner/tie/no-vote result.
8. Publish a Gazette proclamation and, where intended, recognition points.

Legacy staging is in-memory and publishes a default seven-day senior-grade poll. V2 has persisted drafts, readiness labels, candidate management, window presets, and draft deletion. Recent work adds publication mirroring, early conclusion, and account-specific receipt handling. Server and fallback behavior do not yet agree on every step.

**Gazette — current/partial.** Ceremonial cards show winner, house, votes/margin, commissioner/date, proclamation text, and points. A statutory-record loading action still supplies sample local proclamations, not verified history.

**Audit — partial and not normally routed.** A separate audit screen contains turnout/quorum visuals and receipt inclusion checking. Its current checks/default electorate data do not provide an authoritative independent audit; the receipt checker is not a live camera workflow. Election security labels, anonymity, certification, and awards must not be treated as established institutional guarantees.

**Major unfinished connections:** unify vote locks/tallies across both systems; enforce one trusted electorate; align early closure/tie handling; verify result-to-Gazette/points settlement; expose trustworthy receipt checking; and hand over an elected role only under an approved appointment policy. Winning currently does not automatically grant council permissions.

References: [lib/screens/election_chamber_screen.dart:17](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/election_chamber_screen.dart#L17), [lib/screens/school_elections_page.dart:25](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/school_elections_page.dart#L25), [lib/screens/election_audit_screen.dart:36](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/election_audit_screen.dart#L36).

### 9. Inter-House Sports League and live match console

**Current hub:** four tabs—**Fixtures & Live, League Table, Accolades & MVPs, Trophy Cabinet**—with Football, Basketball, Volleyball, Track & Field, and All Sports filters.

Students browse fixtures, venue, schedule, status, opposing houses, and score; completed fixtures feed standings with **win 3 / draw 1 / loss 0**. The current competition model is head-to-head fixtures plus a table, not a bracket/tournament generator. Athletics shares that score model rather than dedicated races and timings.

**Official flow:** create a title/sport/two-house/venue fixture; open its Match HUD; choose period and start/pause/reset a local clock; add +1 scoring events; inspect textual commentary; nominate an MVP; certify the result with fair-play stars and remarks. Fixture creation currently auto-schedules tomorrow rather than offering a real date/time editor. Basketball +2/+3, player attribution, substitutions, score correction, and other sport-specific controls are not fully exposed.

**Recognition:** sport-specific player lists feature Golden Boot, Scoring Champion, Service Ace Specialist, and Track & Field recognition. Custom accolades can credit **25 house points**. Trophy issuance can credit **100 to champions / 50 to runners-up** and publish a notice. These awards are manually entered, not derived from a complete certified tournament progression.

**Partial:** match clocks are screen-local, spectator headline scores do not reliably update live, simultaneous scorers can overwrite totals, and official/certified labels exceed the current trust boundary. Player stats, sports subtotals, and contributor rankings are not fully tied to score/award events. The “MATCH DAY LIVE” label is broader than actual live status.

**Proposed:** persisted official timing, sport-specific event rules, safe simultaneous scoring, corrections and recertification, actual athletics results, registered participants, and outcome-bound MVP/trophy awards.

References: [lib/screens/sports_tournament_screen.dart:142](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/sports_tournament_screen.dart#L142), [lib/screens/live_match_hud_screen.dart:771](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/live_match_hud_screen.dart#L771).

### 10. House Warroom / Arena

Five tabs form the playful identity layer: **Spirit Reactor, Brain Blitz, Cup Oracle, Titan Vault, and 3D Mascot**.

**Spirit Reactor — current interaction, partial shared state.** Tap the house mascot core to create particles and increase spirit energy. Rapid taps build up to a **10×** combo; overdrive produces heavier haptics and a battle-cry message. A four-house grid adds competition. Spirit is separate from official House Cup points. Totals start from fixed values and periodically replace shared totals, rather than reliably accumulating every participant's contribution. Fair rate limits and session accounting are unfinished.

**Brain Blitz — current quiz, partial rewards.** A five-question, four-option house-trivia round gives **15 seconds per question**, green/red answer feedback, streak multipliers, a result screen, and confetti for sufficiently high scores. Questions are fixed, not rotating scholastic content. A perfect streak can score 155 even though the result labels a /100 maximum. “Play Again” allows repeats despite “Daily” branding. Official points are attempted but not reliably settled or server-scored.

**Cup Oracle — current local simulation.** Sliders for sports, academic/decathlon surge, and spirit/attendance update a “win probability” ring. It is a what-if formula against a fixed benchmark, not AI forecasting or a statistical probability based on live competitors. No saved scenarios or rewards exist.

**Titan Vault — current presentation, partial earning.** Students filter House Pride, Milestones, Competitions, or Unlocked honours; inspect shields; tilt/flip them; and read their engraved recipient plate and criteria. The complete current award set is:

| Honour | Advertised earning idea | Current earning limitation |
|---|---|---|
| Ignis Firestarter | Ruby Spirit Week merits | House/admin check rather than 50-merit evidence |
| Zephyr Aeronaut | Science or debate victory | House/admin check rather than verified placement |
| Sylva Titan Pack | Attendance and teamwork service | House/admin check rather than measured service |
| Solis Solar Flare | Lead an athletics victory | House/admin check rather than match evidence |
| House Centurion | 100 lifetime merit points | Always unlocked |
| Pristine Shield | A demerit-free term | Always unlocked |
| Digital Pioneer | Verified photo and NFC credential | Always unlocked despite missing NFC issuance |
| Perfect Streak | 14 early check-ins | Locked with fixed progress |
| Overdrive Core | 10× Reactor resonance | Ten session taps, not verified rapid-tap criteria |
| Scholastic Titan | Strong Brain Blitz performance | Session raw-score threshold |
| Claim Conqueror | Verified external certificate | Locked with fixed pending progress |
| Cup Guardian | Council/prefect service | Broad elevated-role flag |

Rarities are Common/Rare/Epic/Legendary, not evolving upgrade ladders. Displayed merits/dates are not an authoritative award ledger. “Share House Honour Award” is a success message, not a real export/share flow.

**3D Mascot sanctuary — current, substantial interactive work.** All four house figurines can be explored through drag rotation, pinch/± zoom, camera presets, auto-spin, and Roar. Material finishes include Chroma, 24K Gold, Obsidian, and Astral; modes include Solid, Blueprint, and X-Ray, with anatomical callouts and a camera telemetry HUD. Each creature stands on a runic pedestal.

A lore codex describes elemental powers, five attribute bars, a sacred relic, founding chronicles, and an initiation rite: First Ember, Zenith Flight, Pack Vigil, or Golden Dawn. This is a real interactive procedural 3D viewer, not editable CAD, AR, combat, or a leveling system. Roar adds shake/particles/haptics/text, not recorded creature audio. Lore bonuses are fictional flavor rather than game modifiers.

**Battle chant deck — current rhythmic effects.** Embedded in Reactor, it offers War Cry, Heavy March, Stomp-Clap, and Victory Anthem; BPM selection; play/pause/stop; mute; and caption highlighting. Lyrics are house-specific. Audio is timed system clicks/alerts with haptics and a simulated equalizer, not sung/spoken chants.

References: [lib/screens/house_arena_screen.dart:617](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_arena_screen.dart#L617), [lib/widgets/apple_fitness_badges_vault.dart:59](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/widgets/apple_fitness_badges_vault.dart#L59), [lib/widgets/mascot_3d_stage.dart:1745](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/widgets/mascot_3d_stage.dart#L1745).

### 11. Merchandise store, shopping bag, and collection

**Current browsing experience.** The Store destination offers house-personalized products, Limited Edition, Favorites, All Houses, Hoodies, Tees, and Accessories filters; search; product detail sheets; hearts; sizes XS–XL; quantity; Add to Bag; and instant purchase. Bag/favorites/order history persist locally per scholar, with attempted order synchronization.

The complete displayed catalog is fixed, not inventory-managed:

| Item | Displayed price |
|---|---:|
| Premium Champion Hoodie | BHD 14.500 |
| Championship Gold Varsity Jacket | BHD 22.000 |
| House Hub Pro Wireless Earbuds Case | BHD 7.500 |
| Ruby House Elite Hoodie | BHD 12.000 |
| Sapphire Crest Pullover | BHD 12.000 |
| Emerald Performance Tee | BHD 6.500 |
| Topaz Solar Graphic Tee | BHD 6.500 |
| Official ASB Varsity Cap | BHD 4.500 |
| Insulated Hydro Flask (1L) | BHD 5.500 |
| ASB Elite Gym Duffel Bag | BHD 15.000 |

**Checkout — partial.** Users configure an item or build a bag, confirm an order, and receive a QR pickup pass with items and receipt ID. There is no payment-provider flow, cash acknowledgment, real stock reservation, or pickup scheduling. Orders can nevertheless be labeled paid/ready. Ratings, testimonial, weekly countdown, and the claimed 10% loyalty discount are static presentation; the discount is not applied.

Every current product is priced in **BHD**, and checkout does not deduct a verified spendable points balance. Recognition points, spirit, and cash should not be conflated.

**Collection — partial.** Staff scan a voucher, inspect items/student/order, and confirm handover. Claimed state exists, but current zero-point cash voucher generation conflicts with validation, collection is not safely transactional across counters, and local success can precede a real acknowledgment.

**Proposed complete flow:** reserve an available size at a confirmed price → show Reserved / Pay at Pickup → staff acknowledge actual payment → collect once → cancel/expire unused reservations and restore stock. Online payments would require a gateway and verified payment events; they are not currently integrated.

Reference: [lib/screens/merch_store_tab.dart:639](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/merch_store_tab.dart#L639).

### 12. Digital Wallet, ID, fee receipts, and exports

Three tabs provide **Store Passes, Campus ID Pass, and Fee Receipts**.

- **Store Passes:** purchased items, receipt, scholar identity, QR, and ready/fulfilled status. Current cash orders can incorrectly display zero points paid.
- **Campus ID Pass:** student name, scholar number, house, class, contribution, QR, and an academic-year validity label. It is a useful in-app identity display, not a live gate-access or revocable enrollment credential. Some routes supply default class/access labels.
- **Fee Receipts:** a styled tuition/activity pass currently shows a fixed receipt, **BHD 150.000**, and “PAID IN FULL.” It does not check actual fees or settlement.

“Pass & Receipt” opens a printable-looking preview with a real QR. Native PDF generation exists but produces a basic text document rather than the styled pass with scannable QR; the UI does not confirm completion/location reliably. Browser download and true print dispatch are incomplete.

Apple/Google Wallet buttons and NFC/Express Mode labels currently show simulated success, not native pass issuance or NFC provisioning. **Proposed:** signed, installed, updateable, revocable passes tied to real identity/order/payment records, plus honest save/share/download outcomes.

Reference: [lib/screens/digital_wallet_screen.dart:174](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/digital_wallet_screen.dart#L174).

### 13. Council/student direct messaging

**Current, with access/privacy gaps.** Active Conversations shows contact, house/role, last message, and unread badges. Start New Chat searches names/scholar numbers. Ordinary students are intended to contact council/faculty, not other ordinary students; elevated users can discover more registered contacts. Cross-house conversations are supported. There are no group or house channels.

The room has house-colored bubbles, a breathing dual-house wallpaper, text entry, send feedback, and Sent/Read states. Opening a room marks messages read; sending maintains input focus. Messaging is text-only: no attachments, voice messages, reactions, editing, moderation/reporting, or typing indicator.

The app writes messages and notification records, but not verified device pushes. Failed sends can lose drafts without a retry bubble. Role conversion can block intended student-to-council conversations. “Encrypted”/“confidential” copy is not evidence of end-to-end encryption or properly enforced participant-only access.

**Proposed:** approved contact discovery, participant-only access, retained drafts, exactly-once sends, meaningful read progress, and a private notification inbox before device push.

Reference: [lib/screens/chat_list_screen.dart:267](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/chat_list_screen.dart#L267).

### 14. House AI mentor

**Current text experience.** Each house receives its mascot mentor, a personalized greeting, conversational text UI, status pills, and prompt chips such as Timetable, Attendance %, Homework, House Rank, Sports League, Exam Syllabus, and Battle Chant. Responses have timestamps, copy controls, and keyword-selected follow-up suggestions. Clear Conversation resets the session.

With a configured Gemini key, the app sends conversation and school context to Google's text-generation API. The current key setup is user-facing. Without a working key, the mentor returns keyword-based answers using local cached records. Timetable, attendance, assignments, exams, standings, contributions, fixtures, and trophies can provide context, but “live” school data is not necessarily freshly fetched.

There is no persistent AI conversation history, realtime voice session, generated speech, autonomous record editing, or school-system action execution. The “Gemini Live” badge represents a saved key, not confirmed connectivity or Google's realtime Live API. Missing attendance and silent fallback can produce misleading confidence.

**Proposed:** separate structured private records from external general conversation; show source freshness and offline status; school-managed provider configuration, quotas, and safe data-sharing boundaries. Minor safety, school-specific moderation, privacy consent, and human escalation remain important gaps.

Reference: [lib/screens/house_ai_chat_screen.dart:49](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/house_ai_chat_screen.dart#L49).

### 15. Library, preferences, and authority management

**Library — demonstration UI plus disconnected backend.** A drawer sheet displays three fixed borrowed books: Advanced IB Diploma Physics, The Great Gatsby, and Theory of Knowledge Guide. Renew Loan repeatedly adds 14 days locally. A real backend supports copy-based checkout, return, and one borrower renewal, blocking unavailable/held/overdue loans. The interface does not call it. There is no connected catalog, borrower history, librarian screen, holds queue, or reminder.

**Preferences — mixed maturity.** Light/Dark/System theming is app-wide and persisted. Notifications and Sound Effects & Confetti switches are temporary sheet state; Clear App Cache only announces success. Linked accounts work through the account switcher. There is no real language selector despite English/Arabic infrastructure.

**Council roster — current/partial.** Super-admin searches faculty/council positions, filters categories, assigns scholar identity/authority/house/custom designation, edits slots, vacates/revokes roles, and seeds vacant templates. Assignments can update account roles and notification records. Replacement/revocation, backend schema, capability alignment, and audit consistency are not complete. There is no staged appointment approval process or automatic election-to-role handover.

Library reference: [functions/library-v2.js:25](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/functions/library-v2.js#L25).

## Engagement & UX Mechanics

### Visual vibe

The design mixes **premium school identity, collectible heraldry, and an esports-style command center**. It uses bold contemporary typography, large rounded surfaces, pill selectors, dark navy or white/slate backgrounds, house gradients, amber award accents, metallic-looking shields, glow, and ceremonial labels such as Command, Warroom, Vault, and Proclamation.

It is more theatrical than a traditional student portal. Signup visibly transforms into the chosen house; chat blends two houses; sports resembles a broadcast scoreboard; the mascot viewer resembles a technical collectible showroom. “Glass” styling is chiefly translucency, borders, and shadows, not universal blur. House personalization is extensive but not perfectly consistent across global components.

### Interaction mechanics

- Animated selections, page transitions, focused inputs, and modal sheets make navigation tactile.
- Haptics mark taps, selections, scans, successful actions, and overdrive.
- Confetti celebrates a leading house on Standings and strong Blitz results.
- Timetable current/next emphasis, exam urgency, homework color coding, and review status chips guide attention.
- Mascot rotation/zoom/material exploration and shield tilt/flip reward playful inspection.
- Chants add beat-driven sound/haptics, but not real vocal performances.
- Accessibility support includes semantic labels, live announcements, keyboard controls in richer viewers, and responsive touch targets; coverage is uneven.

There is no general avatar customization, editable room/mascot space, AR experience, or persistent character progression.

### Existing engagement loops

| Loop | Immediate motivation | Current limitation |
|---|---|---|
| Achievement → review → house points | Fair recognition for real-world effort | Outcome, audit, and public featuring are not fully coordinated |
| Conduct → personal record → house impact | Reinforces positive contribution | Private feedback and penalties need careful school-policy handling |
| House standings → contributor podium | Pride, visibility, friendly competition | No seasonal resets, participation-inclusive ranks, or reliable complete category ledger |
| Sports → MVP/trophy → proclamation | Event excitement and recognition | Awards/timing/stats are not all derived from authoritative match outcomes |
| Brain Blitz → answer streak → result | Fast feedback and mastery | Fixed content, repeatability, score mismatch, and unreliable official awards |
| Reactor → combo/overdrive → shared spirit | Low-friction collective excitement | Fixed initial totals and unsafe accumulation weaken real collaboration |
| Honours → inspection → collection | Desire to earn a beautiful artifact | Many unlocks/dates are constants or session-only, with no durable earning history |
| Mentor → question → follow-up | Personalized support and house attachment | Cached context, weak freshness signals, and no longitudinal coaching memory |
| Event Wall → featured image → likes | Public celebration and social recognition | Limited publishing, consent, reporting, and retry-safe reactions |

### Community, notifications, and rewards

The current community layer is deliberately narrower than a general social network: house rivalry, moderated photos/likes, staff/council direct messages, sports, and elections. It does **not** contain peer groups, forums, comments, house channels, collaborative quests, or a functioning share/export system.

Notification records exist for messages, claims, conduct, and some appointments. However, there is no complete student inbox, device-token registration, push sender, or durable preference/subscription flow. “Push triggered” flags and settings switches should not be mistaken for delivered alerts. A cooldown banner with a reminder action also exists without a connected production reminder flow.

Rewards are mostly intended recognition: official house/contribution points, sports awards, honours, and visual celebrations. **Spirit energy, practice scores, cumulative contribution, possible spendable credit, and money are distinct concepts.** The current product does not implement a coherent exchange economy or working loyalty-discount system.

The design opportunity is to keep the spectacle while making rewards earned, explainable, fair, and durable. Avoid publicly shaming students through attendance, grades, or demerits; a competitive school product needs noncompetitive paths to belonging too.

## Platform & Technical Capabilities

| Foundation | What is available to build on | Boundary to remember |
|---|---|---|
| **Flutter / Dart, Material 3** | Shared application UI and responsive layouts; Android, iOS, Windows, and web project/configuration support | Platform scaffolding is not evidence of App Store/Play Store publication or equal feature support |
| **Firebase Authentication** | Scholar-based email/password accounts, session streams, profile retrieval; REST credential checking for additional accounts | School-controlled enrollment, recovery, trusted authority, and safe shared-device storage remain incomplete |
| **Cloud Firestore** | Realtime school feeds and persisted profiles, points, claims, academics, chats, fixtures, and elections; some transactions | Access rules, data ownership, class identifiers, ledgers, and local success fallbacks need alignment |
| **Firebase Storage** | Certificate image upload via SDK and authenticated REST, with upload-triggered processing | Private owner-bound evidence and reliable fallback handling need completion |
| **Node.js Firebase Cloud Functions** | Existing certificate analysis trigger and schoolElection / schoolLibrary callables | The app reaches some functions through authenticated HTTPS; many official operations still occur directly from clients |
| **Google Cloud Vision** | Real logo detection and document OCR for certificate review hints | Not genuine seal/signature authentication or automatic approval |
| **Google Gemini REST text generation** | House persona prompts, conversational text, and school-context assistance | Configured model fallback chain includes Gemini 2.0 Flash and 1.5 models; availability is not runtime-verified. No realtime audio or tool-action agent exists |
| **Camera / image tooling** | Camera and gallery selection, Windows camera support, live mobile scanner, QR generation, image-based QR decoding | Permission handling and supported scan paths vary by platform |
| **Local persistence** | SharedPreferences account shortcuts, cached school views, cart, favorites, and order records | This is not a trusted institutional ledger or a complete secure offline synchronization strategy |
| **Custom graphics and art pipeline** | Procedural mascot meshes, Flutter-painted shields/effects, bundled illustrations and Blender-generated assets | Exported GLB/OBJ assets are available but are not the current viewer's active rendering path; no full 3D game engine |
| **Pass/PDF support** | In-app QR passes and basic native PDF byte/file generation | No finished native wallet issuance, NFC, printing, browser download, or polished QR-bearing PDF export |
| **Localization foundation** | English/Arabic resources and Flutter localization delegates | Product screens largely remain English literals; no completed language selector or full RTL UX |

There is **no demonstrated payment gateway, FCM push delivery, Apple/Google Wallet issuer, SIS/LMS connector, official calendar integration, guardian portal, or voice-AI service**. These require additional integration work rather than simply exposing hidden existing capability.

Backend functions and Vision/Storage usage also mean the project's older “free forever” infrastructure claim should not drive planning. Production billing, quotas, deployment, platform enrollment, and sustainable operating costs have not been verified. Android release configuration still uses development signing; school-owned distribution is an operational project, not a completed feature.

Foundation references: [pubspec.yaml:30](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/pubspec.yaml#L30), [functions/index.js:18](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/functions/index.js#L18), [android/app/build.gradle.kts:36](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/android/app/build.gradle.kts#L36).

## Gaps & Untapped Potential

### The highest-impact gaps

1. **The product promises institutional truth before consistently confirming it.** Paid, verified, published, awarded, renewed, encrypted, and live labels sometimes represent presentation, cache state, or incomplete operations. The highest-impact upgrade is a trustworthy lifecycle: pending → server-confirmed → visible to the correct next user, with recoverable failure and safe retries.

2. **Breadth currently exceeds depth.** Many compelling destinations exist, but essential journeys stop early: homework has no individual submissions; leave no attendance effect; store no settled payment; library no connected loans; elections two vote systems. Completing one full school day and several staff-to-student workflows is more valuable than adding more menu cards.

3. **The daily return reason is fragmented.** A student must hunt across tabs for next class, deadline, exam, unread message, or claim outcome. Once the visual novelty wears off, static mini-games and sample progress provide little durable reason to return.

4. **Rewards lack a single earned history.** Badge unlocks, quiz points, sports awards, contributions, and honours are not consistently derived from one ledger. Some totals disagree. Spending and recognition are conceptually mixed in copy without an implemented economy.

5. **Identity, privacy, and role boundaries need school ownership.** Self-entered enrollment, saved credentials, cached identity transitions, broad directory access, medical evidence, public certificates, and differing role gates create risks inappropriate for a school community. Student leaders should receive only explicitly delegated powers.

6. **Competition may exclude students who are not already high performers.** Public contribution ranking and ornate top awards favor visible winners. Team support, improvement, service, creativity, and consistent small contributions need equally credible recognition, without turning private academic or disciplinary data into public scores.

7. **Polish is not yet matched by accessibility and localization.** Dense headers, many parallel routes, theatrical terminology, motion, temporary preference switches, and English-only product copy can reduce usefulness for younger students, staff, families, and users needing quiet/readable layouts.

### Previously raised directions that remain undeveloped or only partial

These are documented proposals or ideas implied by current copy—not a claim that all have been approved:

- **Academics:** individual homework answers and teacher grading; report-card corrections and genuine subject marks; trusted class targeting; schedule publication/versioning; leave-to-register reconciliation; honest no-data attendance. See [ACADEMIC_CHANGE_PROPOSAL.md:21](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/ACADEMIC_CHANGE_PROPOSAL.md#L21).
- **Activities and commerce:** reserve/pay-at-counter/collect-once orders; expiry and refunds as later financial workflows; server-scored daily Blitz and separate practice mode; capped shared spirit; correction-safe match scoring; certified-result-bound trophies and MVPs. See [ACTIVITIES_CHANGE_PROPOSAL.md:19](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/ACTIVITIES_CHANGE_PROPOSAL.md#L19).
- **Product connections:** real library borrowing; "My submissions" for the Event Wall; private notification inbox followed by device push; signed native wallet passes; transparent House AI records versus external conversation; general calendar and confirmed event reminders. See [CODE_CHANGE_PROPOSAL.md:603](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/CODE_CHANGE_PROPOSAL.md#L603).
- **Trust and privacy:** registrar-controlled membership, reliable recovery, safe account shortcuts, participant-only messaging, exactly-once sends, private owner-bound certificate evidence, school-managed AI configuration, and deliberate data-sharing boundaries. See [SECURITY_CHANGE_PROPOSAL.md:18](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/SECURITY_CHANGE_PROPOSAL.md#L18).
- **Elections:** frozen electorates, quorum policy, independent receipt checking, history navigation, and controlled elected-role handover. Drafts, candidate auto-fill, voting UI, early conclusion, and Gazette presentation already have substantial implementation; those should be completed and unified, not reinvented as entirely new features.
- **Ideas suggested by honours/lore:** Spirit Week participation, early check-in streaks, teamwork hours, verified service, science/debate victories, authentic shareable honours, and mascot-linked progression. These are mostly criteria/flavor today, not functioning activity programs.
- **Audio/interaction ambitions:** actual chant/roar audio, true pass saving, badge sharing, and polished scannable exports. Current controls often only imitate the final result.

### New creative opportunities for the next AI to explore

The following are **new hypotheses**, not previously agreed requirements:

| Direction | Proposed user experience | Why it could matter |
|---|---|---|
| **A personalized Today hub** | Next class, due work, exams, notices, unread messages, and pending decisions in one clear agenda; one-tap next actions | Creates a daily reason to open the app and reduces navigation overload |
| **My House Journey** | An evidence-based timeline of achievements, service, improvement, team contributions, and earned honours | Converts disconnected point events into a meaningful personal story |
| **Cooperative house quests** | School-approved collective goals—reading, service, creative work, teamwork—with verified completion and group celebration | Makes contribution inclusive and reduces reliance on solo rankings or tap farming |
| **Mascot mentor as a guide, not just a chat skin** | Contextual explanations, reflection prompts, study planning, and optional lore/cosmetic milestones earned through real activity | Connects the strong mascot identity to sustained utility without letting AI adjudicate school records |
| **A real participation calendar** | Events, rehearsals, trials, exams, and deadlines; registration/waitlists; confirmed reminders and attendance | Turns event browsing into a practical participation engine |
| **Consent-based celebration studio** | Export a verified honour or school-approved achievement card; create seasonal house recaps and a digital yearbook | Lets the app's excellent visual identity travel beyond a static vault while protecting evidence/privacy |
| **A scoped family view** | Authorized guardians see each child's agenda, permission requests, leave decisions, and real dues without sharing passwords | Builds on shared-device demand with a legitimate guardian relationship rather than credential switching |
| **Positive growth and restorative feedback** | Private improvement goals, recognition for helping others, contextual explanations, and staff follow-up after incidents | Prevents the product from reducing students to scores or demerits |
| **A trustworthy digital campus pass** | Revocable ID and confirmed pickup/library credentials, with verified holder and explicit offline limits | Makes the wallet a genuinely useful campus tool rather than an official-looking visual |
| **School-year seasons and transparent impact** | Term-based house campaigns, balanced category recognition, a visible scoring policy, and an audit trail of why totals changed | Makes competition understandable, fairer, and renewable |

These should follow—not bypass—verified identity, privacy, dependable records, accessible UI, and genuine school policy. Avoid adding public student analytics, unrestricted messaging, automatic punitive AI judgments, or uncontrolled reward economies merely because the technical stack makes them easy to prototype.

### How to prioritize brainstorming

The next AI should separate **foundational completion**, **high-utility upgrades**, and **experimental creative directions**. For each idea, identify the user problem, exact journey, required authoritative data, school-policy decisions, privacy implications, and a measurable outcome. Useful outcomes include fewer missed deadlines, more confirmed participation, faster review, fewer failed handovers, broader recognition across students, and more reliable staff-to-student record agreement—not simply more taps or longer sessions.

**Bottom line:** ASB House Hub already has a distinctive identity and an unusually broad feature surface. Its best next evolution is to turn that surface into a dependable, inclusive school-life ecosystem, then use mascots, honours, and house culture to make those real experiences memorable.
