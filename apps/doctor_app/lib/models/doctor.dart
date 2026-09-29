import 'clinical.dart';
import 'json.dart';

/// `DoctorDetail & { acceptingBookings }` (contract §6 / §29).
class DoctorProfile {
  const DoctorProfile({
    required this.id,
    required this.name,
    this.specialty,
    this.specialtyName,
    this.qualifications = '',
    this.experienceYears,
    this.rating,
    this.ratingCount = 0,
    this.languages = const [],
    this.fees = const Fees(),
    this.photoUrl,
    this.bio = '',
    this.registrationNumber,
    this.acceptingBookings = true,
  });

  final String id;
  final String name;
  final String? specialty;
  final String? specialtyName;
  final String qualifications;
  final int? experienceYears;
  final num? rating;
  final int ratingCount;
  final List<String> languages;
  final Fees fees;
  final String? photoUrl;
  final String bio;
  final String? registrationNumber;
  final bool acceptingBookings;

  factory DoctorProfile.fromJson(Json j) => DoctorProfile(
    id: strOr(j['id']),
    name: strOr(j['name'], '–'),
    specialty: str(j['specialty']),
    specialtyName: str(j['specialtyName']),
    qualifications: strOr(j['qualifications']),
    experienceYears: intOrNull(j['experienceYears']),
    rating: numOrNull(j['rating']),
    ratingCount: intOrNull(j['ratingCount']) ?? 0,
    languages: stringList(j['languages']),
    fees: Fees.fromJson(asJson(j['fees'])),
    photoUrl: str(j['photoUrl']),
    bio: strOr(j['bio']),
    registrationNumber: str(j['registrationNumber']),
    acceptingBookings: boolOr(j['acceptingBookings'], true),
  );
}

/// Integer rupees per mode.
class Fees {
  const Fees({this.video = 0, this.audio = 0, this.chat = 0, this.inClinic = 0});
  final int video;
  final int audio;
  final int chat;
  final int inClinic;

  factory Fees.fromJson(Json j) => Fees(
    video: intOrNull(j['video']) ?? 0,
    audio: intOrNull(j['audio']) ?? 0,
    chat: intOrNull(j['chat']) ?? 0,
    inClinic: intOrNull(j['inClinic']) ?? 0,
  );

  Json toJson() => {'video': video, 'audio': audio, 'chat': chat, 'inClinic': inClinic};
}

const consultModes = ['video', 'audio', 'chat', 'in_clinic'];
const slotLengths = [10, 15, 20, 30, 45, 60];

/// `WeeklyBlock` (§29). weekday 0 = Sunday (IST).
class WeeklyBlock {
  const WeeklyBlock({
    required this.weekday,
    required this.start,
    required this.end,
    this.slotMins = 30,
    this.modes = const ['video', 'audio', 'chat'],
  });

  final int weekday;
  final String start;
  final String end;
  final int slotMins;
  final List<String> modes;

  int get startMinutes => hhmmToMinutes(start);
  int get endMinutes => hhmmToMinutes(end);

  factory WeeklyBlock.fromJson(Json j) => WeeklyBlock(
    weekday: intOrNull(j['weekday']) ?? 0,
    start: strOr(j['start'], '09:00'),
    end: strOr(j['end'], '13:00'),
    slotMins: intOrNull(j['slotMins']) ?? 30,
    modes: stringList(j['modes']),
  );

  Json toJson() => {'weekday': weekday, 'start': start, 'end': end, 'slotMins': slotMins, 'modes': modes};

  WeeklyBlock copyWith({int? weekday, String? start, String? end, int? slotMins, List<String>? modes}) => WeeklyBlock(
    weekday: weekday ?? this.weekday,
    start: start ?? this.start,
    end: end ?? this.end,
    slotMins: slotMins ?? this.slotMins,
    modes: modes ?? this.modes,
  );
}

class Leave {
  const Leave({required this.id, required this.date, this.reason});
  final String id;
  final String date;
  final String? reason;

  factory Leave.fromJson(Json j) => Leave(id: strOr(j['id']), date: strOr(j['date']), reason: str(j['reason']));
}

/// `Schedule` (§29).
class Schedule {
  const Schedule({
    this.weekly = const [],
    this.leaves = const [],
    this.horizonDays = 14,
    this.timezone = 'Asia/Kolkata',
  });
  final List<WeeklyBlock> weekly;
  final List<Leave> leaves;
  final int horizonDays;
  final String timezone;

  factory Schedule.fromJson(Json j) => Schedule(
    weekly: jsonList(j['weekly']).map(WeeklyBlock.fromJson).toList(),
    leaves: jsonList(j['leaves']).map(Leave.fromJson).toList()..sort((a, b) => a.date.compareTo(b.date)),
    horizonDays: intOrNull(j['horizonDays']) ?? 14,
    timezone: strOr(j['timezone'], 'Asia/Kolkata'),
  );
}

/// Response of `POST /doctor/me/leaves`.
class LeaveResult {
  const LeaveResult({required this.leave, this.conflicts = const []});
  final Leave leave;
  final List<Appointment> conflicts;

  factory LeaveResult.fromJson(Json j) => LeaveResult(
    leave: Leave.fromJson(asJson(j['leave'])),
    conflicts: jsonList(j['conflicts']).map(Appointment.fromJson).toList(),
  );
}

int hhmmToMinutes(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
  if (m == null) return -1;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return -1;
  return h * 60 + min;
}

String minutesToHhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Problems found in a weekly template before `PUT /doctor/me/schedule`
/// (the server rejects overlaps with VALIDATION_ERROR too).
enum BlockIssue { invalidTime, endBeforeStart, tooShortForSlot, noModes, overlap }

class BlockProblem {
  const BlockProblem(this.index, this.issue, [this.otherIndex]);
  final int index;
  final BlockIssue issue;
  final int? otherIndex;

  @override
  String toString() => 'BlockProblem($index, $issue, $otherIndex)';
}

/// Validates the weekly blocks: times, slot fit, modes and same-day overlaps.
/// Touching blocks (09:00–13:00 and 13:00–17:00) do not overlap.
List<BlockProblem> validateWeekly(List<WeeklyBlock> blocks) {
  final problems = <BlockProblem>[];
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final s = b.startMinutes;
    final e = b.endMinutes;
    if (s < 0 || e < 0 || b.weekday < 0 || b.weekday > 6) {
      problems.add(BlockProblem(i, BlockIssue.invalidTime));
      continue;
    }
    if (e <= s) {
      problems.add(BlockProblem(i, BlockIssue.endBeforeStart));
      continue;
    }
    if (e - s < b.slotMins) problems.add(BlockProblem(i, BlockIssue.tooShortForSlot));
    if (b.modes.isEmpty) problems.add(BlockProblem(i, BlockIssue.noModes));
  }
  for (var i = 0; i < blocks.length; i++) {
    for (var k = i + 1; k < blocks.length; k++) {
      final a = blocks[i];
      final b = blocks[k];
      if (a.weekday != b.weekday) continue;
      final as = a.startMinutes, ae = a.endMinutes, bs = b.startMinutes, be = b.endMinutes;
      if (as < 0 || ae <= as || bs < 0 || be <= bs) continue;
      if (as < be && bs < ae) problems.add(BlockProblem(k, BlockIssue.overlap, i));
    }
  }
  return problems;
}

/// `Earnings` (§32).
class Earnings {
  const Earnings({
    required this.from,
    required this.to,
    this.completedServices = 0,
    this.grossAmount = 0,
    this.platformFee = 0,
    this.refunds = 0,
    this.payable = 0,
    this.lines = const [],
  });

  final String from;
  final String to;
  final int completedServices;
  final num grossAmount;
  final num platformFee;
  final num refunds;
  final num payable;
  final List<EarningsLine> lines;

  factory Earnings.fromJson(Json j) => Earnings(
    from: strOr(j['from']),
    to: strOr(j['to']),
    completedServices: intOrNull(j['completedServices']) ?? 0,
    grossAmount: numOrNull(j['grossAmount']) ?? 0,
    platformFee: numOrNull(j['platformFee']) ?? 0,
    refunds: numOrNull(j['refunds']) ?? 0,
    payable: numOrNull(j['payable']) ?? 0,
    lines: jsonList(j['lines']).map(EarningsLine.fromJson).toList(),
  );
}

class EarningsLine {
  const EarningsLine({
    required this.date,
    required this.description,
    this.amount = 0,
    this.platformFee = 0,
    this.payable = 0,
  });
  final String date;
  final String description;
  final num amount;
  final num platformFee;
  final num payable;

  factory EarningsLine.fromJson(Json j) => EarningsLine(
    date: strOr(j['date']),
    description: strOr(j['description'], '–'),
    amount: numOrNull(j['amount']) ?? 0,
    platformFee: numOrNull(j['platformFee']) ?? 0,
    payable: numOrNull(j['payable']) ?? 0,
  );
}
