List<String> _strings(Object? v) => v is List ? v.map((e) => e.toString()).toList() : const [];

/// One page of a staff work queue. [total] is the number of rows matching the filter on the server.
class StaffPage<T> {
  const StaffPage({required this.items, required this.total});

  final List<T> items;
  final int total;
}

/// A booking in the staff queue. [nextStatuses] comes from the server's own transition rules (a PAID booking has none),
/// so the app offers exactly the actions the server will accept.
class QueueBooking {
  const QueueBooking({
    required this.id,
    required this.code,
    required this.status,
    required this.currency,
    required this.total,
    required this.customerEmail,
    required this.createdAt,
    this.nextStatuses = const [],
  });

  final String id;
  final String code;
  final String status;
  final String currency;
  final String total;
  final String customerEmail;
  final String createdAt;
  final List<String> nextStatuses;

  factory QueueBooking.fromJson(Map<String, dynamic> j) => QueueBooking(
        id: (j['id'] ?? '').toString(),
        code: (j['booking_code'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        currency: (j['currency'] ?? '').toString(),
        total: (j['total_amount'] ?? '').toString(),
        customerEmail: (j['customer_email'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        nextStatuses: _strings(j['next_statuses']),
      );
}

class QueueDispute {
  const QueueDispute({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.reason,
    required this.description,
    required this.status,
    required this.openedBy,
    required this.createdAt,
    this.nextStatuses = const [],
  });

  final String id;
  final String bookingId;
  final String bookingCode;
  final String reason;
  final String description;
  final String status;
  final String openedBy;
  final String createdAt;
  final List<String> nextStatuses;

  factory QueueDispute.fromJson(Map<String, dynamic> j) => QueueDispute(
        id: (j['id'] ?? '').toString(),
        bookingId: (j['booking_id'] ?? '').toString(),
        bookingCode: (j['booking_code'] ?? '').toString(),
        reason: (j['reason'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        openedBy: (j['opened_by_email'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        nextStatuses: _strings(j['next_statuses']),
      );
}

class QueuePartner {
  const QueuePartner({
    required this.id,
    required this.legalName,
    required this.status,
    required this.ownerEmail,
    required this.createdAt,
    this.nextStatuses = const [],
  });

  final String id;
  final String legalName;
  final String status;
  final String ownerEmail;
  final String createdAt;
  final List<String> nextStatuses;

  factory QueuePartner.fromJson(Map<String, dynamic> j) => QueuePartner(
        id: (j['id'] ?? '').toString(),
        legalName: (j['legal_name'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        ownerEmail: (j['owner_email'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        nextStatuses: _strings(j['next_statuses']),
      );
}

const _statusTh = {
  'PENDING': 'รอดำเนินการ',
  'CONFIRMED': 'ยืนยันแล้ว',
  'CANCELLED': 'ยกเลิก',
  'PAID': 'ชำระแล้ว',
  'OPEN': 'เปิดอยู่',
  'IN_REVIEW': 'กำลังตรวจสอบ',
  'RESOLVED': 'แก้ไขแล้ว',
  'REJECTED': 'ปฏิเสธ',
  'APPROVED': 'อนุมัติแล้ว',
  'SUSPENDED': 'ถูกระงับ',
};

/// Thai label for a status code; an unknown code is shown as it is.
String statusLabelTh(String status) => _statusTh[status] ?? status;

/// Status changes that cannot easily be undone (or hurt a customer) get a warning colour and an explicit confirmation.
bool isDestructiveStatus(String to) => to == 'CANCELLED' || to == 'REJECTED' || to == 'SUSPENDED';

/// Label of the button that moves [kind] ('booking' | 'dispute' | 'partner') from [from] to [to].
String statusActionTh(String kind, String from, String to) {
  switch ('$kind:$to') {
    case 'booking:CONFIRMED':
      return 'ยืนยันการจอง';
    case 'booking:CANCELLED':
      return 'ยกเลิกการจอง';
    case 'dispute:IN_REVIEW':
      return 'เริ่มตรวจสอบ';
    case 'dispute:RESOLVED':
      return 'ปิดเรื่อง (แก้ไขแล้ว)';
    case 'dispute:REJECTED':
      return 'ปฏิเสธข้อพิพาท';
    case 'partner:APPROVED':
      return from == 'SUSPENDED' ? 'เปิดใช้งานอีกครั้ง' : 'อนุมัติ';
    case 'partner:REJECTED':
      return 'ปฏิเสธ';
    case 'partner:SUSPENDED':
      return 'ระงับ';
  }
  return statusLabelTh(to);
}
