# C2 — Self-service super-admin escalation via the users doc

- **Severity:** Critical
- **Area:** Firestore rules / privilege escalation
- **Evidence:** `firestore.rules:293-318` (`isValidUser`), `firestore.rules:236-245` (`isSuperAdmin`), `firestore.rules:591-600` (users create)

## Problem

`isValidUser` only validates `scholar_no` **length** (4–20 chars), so the privileged values `'11209'` and `'admin'` pass. `isSuperAdmin()` trusts the users document: `scholar_no in ['admin','11209']` → super admin. The users-create rule blocks admin *roles* but not privileged *scholar numbers*.

## What breaks

**Repro:** any authenticated user creates `users/{myUid}` with `{'scholar_no': '11209', 'role': 'student', ...valid fields...}`. `isAdmin()` / `isSuperAdmin()` now evaluate true for them → they can write `house_points`, `admin_roster`, announcements, attendance, conduct records — every admin-gated collection — and the client UI also treats them as staff (see C6).

## Solution

1. Reject privileged identifiers at self-create time in `isValidUser`:

```
request.resource.data.scholar_no is string &&
request.resource.data.scholar_no.size() >= 4 &&
request.resource.data.scholar_no.size() <= 20 &&
!(request.resource.data.scholar_no.lowerAscii() in ['admin', '11209'])
```

(Note: rules have no `lowerAscii`; compare against both cases or normalize scholar numbers to lowercase at signup and compare `!= 'admin' && != '11209'`.)

2. Stop deriving authority from a self-written doc. `isSuperAdmin()` should check **custom claims** (`request.auth.token.admin == true`) or the server-maintained `admin_roster` only — never `users/{uid}.scholar_no`.
3. Audit existing users docs for `scholar_no in ['admin','11209']` not belonging to the real admin and clean them up.
4. Add a rules unit test: self-create with scholar_no `11209` must be denied.