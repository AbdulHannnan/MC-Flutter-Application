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
