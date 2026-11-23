// lib/src/features/technician/data/technician_job.dart — a job in the technician's
// queue. The shape the `technician` Edge Function returns from GET /technician/jobs
// (list) and GET /technician/jobs/:id (detail).
//
// ONE model covers both: the list SELECT returns the core fields; the detail SELECT
// adds notes/quantity/total/serviceOption/addons/photos. Those detail-only fields
// are nullable/empty on a list row. Field names mirror the deployed function's
// SELECT exactly (confirmed from supabase/functions/technician/index.ts), and are
// identical to the legacy Express job shape.
//
// Money: `total`/`lineTotal` arrive as major-unit AED strings/numbers → Money.fromAed.

import '../../../models/money.dart';

/// The fulfillment lifecycle of a job. UNASSIGNED → ASSIGNED → ACKNOWLEDGED →
/// IN_PROGRESS → DONE (mirrors the backend `JobStatus` enum).
enum JobStatus {
  unassigned,
  assigned,
  acknowledged,
  inProgress,
  done;

  /// The wire token, e.g. `IN_PROGRESS`.
  String get code => switch (this) {
        JobStatus.unassigned => 'UNASSIGNED',
        JobStatus.assigned => 'ASSIGNED',
        JobStatus.acknowledged => 'ACKNOWLEDGED',
        JobStatus.inProgress => 'IN_PROGRESS',
        JobStatus.done => 'DONE',
      };

  /// A short human label for the status pill.
  String get label => switch (this) {
        JobStatus.unassigned => 'Unassigned',
        JobStatus.assigned => 'Assigned',
        JobStatus.acknowledged => 'Acknowledged',
        JobStatus.inProgress => 'In progress',
        JobStatus.done => 'Done',
      };

  /// Parse a wire token, defaulting to [unassigned] for anything unrecognised.
  static JobStatus fromCode(String? value) => switch (value) {
        'ASSIGNED' => JobStatus.assigned,
        'ACKNOWLEDGED' => JobStatus.acknowledged,
        'IN_PROGRESS' => JobStatus.inProgress,
        'DONE' => JobStatus.done,
        _ => JobStatus.unassigned,
      };
}

/// A before/after job photo kind.
enum PhotoKind {
  before,
  after;

  static PhotoKind fromCode(String? value) =>
      value == 'after' ? PhotoKind.after : PhotoKind.before;
}

/// The service a job is for (`service:Service(id,name)`).
class JobServiceRef {
  final String id;
  final String name;
  const JobServiceRef({required this.id, required this.name});

  factory JobServiceRef.fromJson(Map<String, dynamic> j) => JobServiceRef(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
      );
}

/// The chosen price-tier option (`serviceOption:ServiceOption(id,label)`).
class JobOptionRef {
  final String id;
  final String label;
  const JobOptionRef({required this.id, required this.label});

  factory JobOptionRef.fromJson(Map<String, dynamic> j) => JobOptionRef(
        id: j['id'] as String,
        label: (j['label'] ?? '') as String,
      );
}

/// One add-on line on the job (`addons:BookingAddon(id,quantity,lineTotal,addon:Addon(id,name))`).
class JobAddonLine {
  final String id;
  final int quantity;
  final Money lineTotal;
  final String addonName;

  const JobAddonLine({
    required this.id,
    required this.quantity,
    required this.lineTotal,
    required this.addonName,
  });

  factory JobAddonLine.fromJson(Map<String, dynamic> j) {
    final addon = j['addon'] as Map<String, dynamic>?;
    return JobAddonLine(
      id: j['id'] as String,
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      lineTotal: Money.fromAed(j['lineTotal']),
      addonName: (addon?['name'] ?? '') as String,
    );
  }
}

/// A job photo (`photos:BookingPhoto(id,kind,url,createdAt)`).
class JobPhoto {
  final String id;
  final PhotoKind kind;

  /// May be a relative path — callers resolve with assetUrl() before display.
  final String url;
  final String? createdAt;

  const JobPhoto({
    required this.id,
    required this.kind,
    required this.url,
    this.createdAt,
  });

  factory JobPhoto.fromJson(Map<String, dynamic> j) => JobPhoto(
        id: j['id'] as String,
        kind: PhotoKind.fromCode(j['kind'] as String?),
        url: (j['url'] ?? '') as String,
        createdAt: j['createdAt'] as String?,
      );
}

class TechnicianJob {
  // ── Core (list + detail) ──
  final String id;
  final String? reference;

  /// The customer booking status (COMPLETED / DRAFT / …) — raw wire value.
  final String? bookingStatus;
  final JobStatus jobStatus;
  final String? propertyType;
  final String? address;
  final String? mapUrl;

  /// ISO datetime of the scheduled visit; [scheduledTime] is the label ("HH:mm").
  final String? scheduledDate;
  final String? scheduledTime;
  final String? contactName;
  final String? contactPhone;
  final String? assignedAt;
  final String? acknowledgedAt;
  final String? startedAt;
  final String? doneAt;
  final JobServiceRef? service;

  // ── Detail-only (null/empty on a list row) ──
  final String? notes;
  final int? quantity;
  final Money? total;
  final JobOptionRef? serviceOption;
  final List<JobAddonLine> addons;
  final List<JobPhoto> photos;

  const TechnicianJob({
    required this.id,
    required this.jobStatus,
    this.reference,
    this.bookingStatus,
    this.propertyType,
    this.address,
    this.mapUrl,
    this.scheduledDate,
    this.scheduledTime,
    this.contactName,
    this.contactPhone,
    this.assignedAt,
    this.acknowledgedAt,
    this.startedAt,
    this.doneAt,
    this.service,
    this.notes,
    this.quantity,
    this.total,
    this.serviceOption,
    this.addons = const [],
    this.photos = const [],
  });

  /// The service name, or a neutral fallback.
  String get serviceName => service?.name.isNotEmpty == true
      ? service!.name
      : (reference ?? 'Job');

  factory TechnicianJob.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) map) =>
        (j[key] as List<dynamic>? ?? const [])
            .map((e) => map(e as Map<String, dynamic>))
            .toList();

    return TechnicianJob(
      id: j['id'] as String,
      reference: j['reference'] as String?,
      bookingStatus: j['status'] as String?,
      jobStatus: JobStatus.fromCode(j['jobStatus'] as String?),
      propertyType: j['propertyType'] as String?,
      address: j['address'] as String?,
      mapUrl: j['mapUrl'] as String?,
      scheduledDate: j['scheduledDate'] as String?,
      scheduledTime: j['scheduledTime'] as String?,
      contactName: j['contactName'] as String?,
      contactPhone: j['contactPhone'] as String?,
      assignedAt: j['assignedAt'] as String?,
      acknowledgedAt: j['acknowledgedAt'] as String?,
      startedAt: j['startedAt'] as String?,
      doneAt: j['doneAt'] as String?,
      service: j['service'] == null
          ? null
          : JobServiceRef.fromJson(j['service'] as Map<String, dynamic>),
      notes: j['notes'] as String?,
      quantity: (j['quantity'] as num?)?.toInt(),
      total: j.containsKey('total') && j['total'] != null
          ? Money.fromAed(j['total'])
          : null,
      serviceOption: j['serviceOption'] == null
          ? null
          : JobOptionRef.fromJson(j['serviceOption'] as Map<String, dynamic>),
      addons: list('addons', JobAddonLine.fromJson),
      photos: list('photos', JobPhoto.fromJson),
    );
  }
}
