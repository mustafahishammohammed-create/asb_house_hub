# A9. Publisher demo prefills; attachments validator has no per-item caps

**Severity:** LOW (second pass, 2026-11-08)

**Status (2026-11-08):** the `image_url` field is now whitelisted and capped at 500000 chars in `isValidHomework` (shipped with the photo-upload feature, firestore.rules:384,398). The two items below remain open.

## Problem

1. **Demo prefills in staff publisher forms** (same family as A7/A8):
   - Assignment modal: teacher defaults to `'Mr. Sharma'` — [academics_screen.dart:2339](../lib/screens/academics_screen.dart).
   - Exam publisher: paper title defaults to `'Mid-Term Assessment Paper 1'` and syllabus to `'Chapters 1 to 5 Revision'` — [academics_screen.dart:3516-3518](../lib/screens/academics_screen.dart). Publishing without editing pushes boilerplate to every grade in the selected range.
2. **`attachments` list items are unvalidated.** `isValidHomework` caps the list at 10 items but checks no item type or size — [firestore.rules:397](../firestore.rules). Admin-only surface, so hygiene: ten oversized strings could approach the 1 MiB document limit and fail the write opaquely.

## What breaks

- Boilerplate teacher names / syllabus text reach students as if real.
- An oversized attachments payload fails with a raw Firestore size error instead of a clear validation message.

## Solution

**No Blaze required:**

1. Replace prefilled demo values with empty controllers + hint text (teacher, paper title, syllabus). Keep legitimate defaults (exam hall, duration, marks) as-is.
2. Add a per-item check to the attachments rule: every item `is string && size() <= 2000` (URLs/paths, not base64 blobs — base64 images belong in the capped `image_url` field).

## Done when

- Publisher forms start empty (hints only) except genuine defaults.
- Rules-contract test asserts the attachments per-item cap.