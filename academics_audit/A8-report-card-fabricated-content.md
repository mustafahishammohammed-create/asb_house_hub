# A8. Report-card publisher fabricates "official" records

**Severity:** MEDIUM (second pass, 2026-11-08)

## Problem

The "Issue Official Report Card" flow invents most of what it publishes:

1. **Synthesized subject grades.** From a single entered percentage, the dialog generates five subject scores with fixed offsets — Mathematics `pct+2`, Physics `pct-1`, Chemistry `pct`, Computer Science `pct+4`, English `pct-2` — each with a canned teacher comment ("Strong problem-solving capability.", "Exceptional programming and logic."…) — [academics_screen.dart:5487-5524](../lib/screens/academics_screen.dart). No per-subject input exists.
2. **Silent numeric fallbacks.** Unparseable percentage becomes `90.0`, attendance becomes `98.0` — [academics_screen.dart:5483-5485](../lib/screens/academics_screen.dart). A typo publishes a fabricated score with no warning.
3. **Hardcoded endorsements in the model.** Every card renders `status => 'Official'`, `section => 'A'`, and `principalRemarks => 'Approved for Academic Excellence and Merit Recognition.'` — [academic_report_card.dart:147-149](../lib/models/academic_report_card.dart). A principal endorsement appears on every card though no principal ever wrote one.
4. **Demo prefills.** Scholar number defaults to `'2310910'` ([academics_screen.dart:5212](../lib/screens/academics_screen.dart)) and remarks to boilerplate (:5222-5224) — publishing without editing issues a card to the wrong scholar with invented remarks.

## What breaks

- An "Official" report card — the module's most sensitive record (see A1) — carries computer-invented subject scores, a fake principal endorsement, and possibly the wrong scholar number. Once published it is indistinguishable from a real record and feeds the GPA honours claim (A4).
- Staff get no signal about which fields were synthesized vs entered.

## Solution

**No Blaze required:**

1. Remove the silent fallbacks: invalid percentage/attendance/GPA input blocks publishing with a validation message.
2. Either add per-subject score entry, or clearly label the generated breakdown as an *indicative template* (and don't print canned per-subject teacher comments as if written by staff).
3. Delete the hardcoded `principalRemarks`/`status`/`section` getters' fabricated values — return empty/derived data; only show a principal remark if one was actually stored.
4. Remove the `'2310910'` scholar prefill and boilerplate remarks default; use empty fields with hint text (same fix family as A7/A9).

## Done when

- Publishing requires valid numeric input and a deliberately entered scholar number.
- No card displays a principal endorsement or per-subject comments that no human entered.
- Tests: model round-trip carries only stored values; publish dialog rejects invalid numbers.