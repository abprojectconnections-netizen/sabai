import 'support_models.dart';

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
  'IN_PROGRESS': 'กำลังดำเนินการ',
  'CLOSED': 'ปิดแล้ว',
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
bool isDestructiveStatus(String to) => to == 'CANCELLED' || to == 'REJECTED' || to == 'SUSPENDED' || to == 'CLOSED';

/// Label of the button that moves [kind] ('booking' | 'dispute' | 'partner' | 'ticket') from [from] to [to].
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
    case 'ticket:IN_PROGRESS':
      return from == 'RESOLVED' ? 'เปิดใหม่' : 'เริ่มดำเนินการ';
    case 'ticket:RESOLVED':
      return 'ทำเครื่องหมายว่าแก้ไขแล้ว';
    case 'ticket:CLOSED':
      return 'ปิดคำขอ';
    case 'partner:APPROVED':
      return from == 'SUSPENDED' ? 'เปิดใช้งานอีกครั้ง' : 'อนุมัติ';
    case 'partner:REJECTED':
      return 'ปฏิเสธ';
    case 'partner:SUSPENDED':
      return 'ระงับ';
  }
  return statusLabelTh(to);
}

/// A support ticket in the staff queue. [nextStatuses] comes from the server's transition rules.
class QueueTicket {
  const QueueTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.customerEmail,
    this.priority = '',
    this.bookingCode = '',
    this.assignedStaffId = '',
    this.createdAt = '',
    this.messageCount = 0,
    this.nextStatuses = const [],
  });

  final String id;
  final String subject;
  final String category;
  final String status;
  final String customerEmail;
  final String priority;
  final String bookingCode;
  final String assignedStaffId;
  final String createdAt;
  final int messageCount;
  final List<String> nextStatuses;

  factory QueueTicket.fromJson(Map<String, dynamic> j) => QueueTicket(
        id: (j['id'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        customerEmail: (j['customer_email'] ?? '').toString(),
        priority: (j['priority'] ?? '').toString(),
        bookingCode: (j['booking_code'] ?? '').toString(),
        assignedStaffId: (j['assigned_staff_id'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        messageCount: j['message_count'] is num ? (j['message_count'] as num).toInt() : 0,
        nextStatuses: _strings(j['next_statuses']),
      );
}

/// One ticket with its description and the whole conversation (GET /portal/tickets/:id).
class StaffTicketDetail {
  const StaffTicketDetail({required this.ticket, this.description = '', this.messages = const []});

  final QueueTicket ticket;
  final String description;
  final List<SupportMessage> messages;

  factory StaffTicketDetail.fromJson(Map<String, dynamic> j) {
    final raw = j['messages'];
    return StaffTicketDetail(
      ticket: QueueTicket.fromJson(j),
      description: (j['description'] ?? '').toString(),
      messages: raw is List ? raw.whereType<Map<String, dynamic>>().map(SupportMessage.fromJson).toList() : const [],
    );
  }
}
