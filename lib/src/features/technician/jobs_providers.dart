// lib/src/features/technician/jobs_providers.dart — the technician jobs data layer.
//
// Thin Riverpod wrappers over [technicianApiProvider].jobs()/job(), giving the
// screens an AsyncValue (loading / error / data) with `ref.invalidate(...)` as the
// refresh. Unlike the catalog, a technician's queue changes through the shift, so
// these are plain autoDispose futures (no long staleTime) — a revisit refetches.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import 'data/technician_api.dart';
import 'data/technician_job.dart';

/// Retry transient failures a couple of times, but never an auth failure (a 401
/// means the token is gone/expired — retrying won't help and only delays the
/// sign-out the session layer will trigger on the next action).
Duration? technicianJobsRetry(int retryCount, Object error) {
  if (error is ApiException && error.status == 401) return null;
  return retryCount < 2
      ? Duration(milliseconds: 300 * (1 << retryCount))
      : null;
}

/// The signed-in technician's job queue (soonest first), optionally filtered by a
/// [JobStatus]. `null` ⇒ the whole queue. The family arg is the cache key.
final technicianJobsProvider =
    FutureProvider.autoDispose.family<List<TechnicianJob>, JobStatus?>(
  (ref, filter) =>
      ref.watch(technicianApiProvider).jobs(status: filter?.code),
  retry: technicianJobsRetry,
);

/// One job's full detail by id. (Key: `['job', id]`.)
final technicianJobProvider =
    FutureProvider.autoDispose.family<TechnicianJob, String>(
  (ref, id) => ref.watch(technicianApiProvider).job(id),
  retry: technicianJobsRetry,
);

/// A job's before/after photos with short-lived viewable URLs. Separate from the
/// detail because the signed URLs only come from the photos endpoint (the detail
/// embed carries just the private object keys).
final jobPhotosProvider =
    FutureProvider.autoDispose.family<List<JobPhoto>, String>(
  (ref, id) => ref.watch(technicianApiProvider).jobPhotos(id),
  retry: technicianJobsRetry,
);

/// Job lifecycle actions (acknowledge / status change). Each performs the server
/// call then refreshes the affected views — the job's own detail and the queue —
/// so the UI reflects the new state. The screen owns the in-flight / error UI and
/// awaits these; a server rejection (e.g. 409 wrong transition, or DONE without
/// the required photos) propagates as the thrown [ApiException] for it to surface.
class JobActions {
  JobActions(this._ref);
  final Ref _ref;

  TechnicianApi get _api => _ref.read(technicianApiProvider);

  Future<void> acknowledge(String id) async {
    await _api.acknowledgeJob(id);
    _refresh(id);
  }

  Future<void> setStatus(String id, JobStatus status) async {
    await _api.updateJobStatus(id, status);
    _refresh(id);
  }

  /// Upload before/after photos, then refresh the photo strip (and the detail,
  /// whose embedded photo set feeds the DONE gate).
  Future<void> uploadPhotos(
    String id,
    PhotoKind kind,
    List<PhotoUpload> files,
  ) async {
    await _api.uploadPhotos(id, kind, files);
    _ref.invalidate(jobPhotosProvider(id));
    _ref.invalidate(technicianJobProvider(id));
  }

  void _refresh(String id) {
    _ref.invalidate(technicianJobProvider(id));
    _ref.invalidate(jobPhotosProvider(id));
    _ref.invalidate(technicianJobsProvider); // the whole queue (every filter)
  }
}

final jobActionsProvider = Provider<JobActions>(JobActions.new);
