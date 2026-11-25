# Field Job Portal — Teardown Recipe

**This is a TEMPORARY feature** (added ~Nov 2026, expected removal ~1 month later).
It was built to be deleted cleanly. Everything it owns is named `field_*` / `field-*`
so it is unmistakable. Removing it touches **nothing** in the customer, booking, or
technician-jobs systems.

Do all of the steps below. Each is independent and safe.

---

## 1. Flutter app (`MC Flutter App` repo)

| What | Where | Action |
|---|---|---|
| Feature code | `lib/src/features/field_portal/` | **Delete the whole folder** |
| Route constants | `lib/src/app/app_routes.dart` | Remove the `fieldPortal*` constants |
| Route registration | `lib/src/app/app_router.dart` | Remove the `field_portal` import(s) + its `GoRoute` entry |
| Entry point | `lib/src/features/technician/screens/technician_home_screen.dart` | Remove the "Field Job Portal" button/tile + its import |
| Tests | `test/features/field_portal/` | Delete the folder |

Then: `flutter analyze` (no dangling references) and `flutter test`.

> The feature only ever **read** `technicianSessionProvider` and reused the shared
> photo-upload helpers — it never modified them, so nothing in the technician code
> needs reverting.

---

## 2. Supabase backend (`Micocare Booking System` repo)

| What | Where | Action |
|---|---|---|
| Edge Function | `supabase/functions/field-jobs/` | **Delete the folder** |
| Function registration | `supabase/config.toml` | Remove the `[functions.field-jobs]` block (and its comment) |
| Migration file | `supabase/migrations/0006_field_portal.sql` | Leave it in history; the teardown SQL below undoes it |

### Undeploy the function
```bash
supabase functions delete field-jobs --project-ref fcmpfrogdhudesvzfoyg
```

### Drop the table + empty & delete the bucket
Run this SQL against the project (SQL editor or `supabase db execute`):
```sql
-- 1. Drop the table (cascades its index). This is the whole data model.
drop table if exists public.field_jobs;

-- 2. Empty, then delete, the private photo bucket.
delete from storage.objects where bucket_id = 'field-job-photos';
delete from storage.buckets where id = 'field-job-photos';
```

> Storage will refuse to delete a non-empty bucket, so the `storage.objects` delete
> must run first. (Alternatively empty `field-job-photos` from the Storage UI, then
> remove the bucket there.)

---

## Verification after teardown
- `grep -ri "field_portal\|field-jobs\|field_jobs\|field-job-photos" lib/ test/` → no hits in the Flutter repo.
- `supabase functions list` → no `field-jobs`.
- `select to_regclass('public.field_jobs');` → `NULL`.
- `select id from storage.buckets where id = 'field-job-photos';` → 0 rows.

Nothing else references this feature. Done.
