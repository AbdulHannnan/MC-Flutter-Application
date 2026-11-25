// lib/src/features/field_portal — TEMPORARY "Field Job Portal" feature barrel.
//
// A self-contained, throwaway feature (see FIELD_PORTAL_REMOVAL.md): a signed-in
// technician submits a field job (month/team/sequence + before/after photos) that
// the CRM later turns into a PDF report. It reuses the existing technician session +
// shared widgets but owns its own backend (field_jobs table, field-jobs Edge
// Function, field-job-photos bucket). Everything is under this one folder so removal
// is: delete this folder + unregister its route + run the backend teardown.
//
// Import the feature's public surface from here.
export 'field_job_form.dart';
export 'screens/field_job_portal_screen.dart';
