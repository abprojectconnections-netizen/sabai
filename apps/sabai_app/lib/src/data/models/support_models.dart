/// Customer support tickets (GET /support/tickets). Statuses and categories are the server's own codes.
const Map<String, String> supportCategoriesTh = {
  'BOOKING': 'การจอง',
  'PAYMENT': 'การชำระเงิน',
  'REFUND': 'การคืนเงิน',
  'ACCOUNT': 'บัญชีผู้ใช้',
  'OTHER': 'อื่น ๆ',
};

String ticketCategoryLabelTh(String code) => supportCategoriesTh[code] ?? code;

String ticketStatusLabelTh(String status) {
  switch (status) {
    case 'OPEN':
      return 'รอเจ้าหน้าที่';
    case 'IN_PROGRESS':
      return 'กำลังดำเนินการ';
    case 'RESOLVED':
      return 'แก้ไขแล้ว';
    case 'CLOSED':
      return 'ปิดแล้ว';
    default:
      return status;
  }
}

/// Date part of an RFC 3339 timestamp, for compact display.
String ticketDate(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    this.bookingCode = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.replyCount = 0,
  });

  final String id;
  final String subject;
  final String category;
  final String status;
  final String bookingCode;
  final String createdAt;
  final String updatedAt;

  /// How many times staff have answered.
  final int replyCount;

  bool get isClosed => status == 'CLOSED';

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: (j['id'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        bookingCode: (j['booking_code'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        updatedAt: (j['updated_at'] ?? '').toString(),
        replyCount: j['reply_count'] is num ? (j['reply_count'] as num).toInt() : 0,
      );
}

class SupportMessage {
  const SupportMessage({required this.id, required this.authorKind, required this.body, this.createdAt = ''});

  final String id;

  /// CUSTOMER or STAFF. The server never says which staff member wrote a reply.
  final String authorKind;
  final String body;
  final String createdAt;

  bool get fromStaff => authorKind == 'STAFF';

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: (j['id'] ?? '').toString(),
        authorKind: (j['author_kind'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

class SupportTicketDetail {
  const SupportTicketDetail({required this.ticket, this.description = '', this.messages = const []});

  final SupportTicket ticket;
  final String description;
  final List<SupportMessage> messages;

  factory SupportTicketDetail.fromJson(Map<String, dynamic> j) {
    final raw = j['messages'];
    return SupportTicketDetail(
      ticket: SupportTicket.fromJson(j),
      description: (j['description'] ?? '').toString(),
      messages: raw is List ? raw.whereType<Map<String, dynamic>>().map(SupportMessage.fromJson).toList() : const [],
    );
  }
}

class TicketsPage {
  const TicketsPage({required this.items, required this.total});

  final List<SupportTicket> items;
  final int total;
}
