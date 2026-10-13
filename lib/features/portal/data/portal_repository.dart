import '../../../core/network/api_client.dart';

class PortalQueue {

  factory PortalQueue.fromJson(Map<String, dynamic> json) => PortalQueue(
        pendingBookings: json['pending_bookings'] as int? ?? 0,
        pendingPayments: json['pending_payments'] as int? ?? 0,
        pendingPartners: json['pending_partners'] as int? ?? 0,
        openTickets: json['open_tickets'] as int? ?? 0,
        openDisputes: json['open_disputes'] as int? ?? 0,
      );
  const PortalQueue({
    required this.pendingBookings,
    required this.pendingPayments,
    required this.pendingPartners,
    required this.openTickets,
    required this.openDisputes,
  });

  final int pendingBookings;
  final int pendingPayments;
  final int pendingPartners;
  final int openTickets;
  final int openDisputes;
}

class PortalRepository {
  PortalRepository(this._client);
  final ApiClient _client;

  Future<PortalQueue> queue(String token) async {
    final Map<String, dynamic> response = await _client.getAuthorized('/portal/queue', token);
    final Object? data = response['data'];
    if (data is! Map<String, dynamic>) throw const ApiException('Invalid portal queue response');
    return PortalQueue.fromJson(data);
  }

  Future<void> updateBookingStatus(String token, String bookingId, String status, {String? note}) async {
    await _client.patchAuthorized('/portal/bookings/$bookingId/status', token, {'status': status, if (note != null) 'note': note});
  }

  Future<void> verifyPayment(String token, String paymentId, String status, {String? note}) async {
    await _client.patchAuthorized('/portal/payments/$paymentId/verify', token, {'status': status, if (note != null) 'note': note});
  }

  Future<void> approvePartner(String token, String partnerId, String status, {String? note}) async {
    await _client.patchAuthorized('/portal/partners/$partnerId/approval', token, {'status': status, if (note != null) 'note': note});
  }
}
