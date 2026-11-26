/// Error raised by every repository so the UI handles failures uniformly.
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.status = 0,
    this.requestId = '',
  });

  final String code;
  final String message;
  final int status;
  final String requestId;

  @override
  String toString() => 'ApiError($code, $status): $message';
}

/// User-facing Thai message. Never leaks server internals; the request id stays on the error for support.
String describeApiErrorTh(Object error) {
  if (error is! ApiError) return 'เกิดข้อผิดพลาดที่ไม่คาดคิด ลองอีกครั้ง';
  switch (error.code) {
    case 'UNAUTHORIZED':
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    case 'FORBIDDEN':
      return 'คุณไม่มีสิทธิ์ทำรายการนี้';
    case 'VALIDATION_ERROR':
      return 'ข้อมูลไม่ถูกต้อง: ${error.message}';
    case 'NOT_FOUND':
      return 'ไม่พบรายการที่ต้องการ';
    case 'CONFLICT':
      return 'ไม่สามารถทำรายการนี้ได้ในสถานะปัจจุบันของการจอง';
    case 'FINANCIAL_TRANSACTIONS_DISABLED':
      return 'ระบบการเงินยังไม่เปิดใช้งานในสภาพแวดล้อมนี้';
    case 'FEATURE_DISABLED':
      return 'ฟีเจอร์นี้ถูกปิดชั่วคราวโดยผู้ดูแลระบบ';
    case 'NETWORK_ERROR':
      return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบอินเทอร์เน็ตแล้วลองอีกครั้ง';
    case 'TIMEOUT':
      return 'เซิร์ฟเวอร์ตอบสนองช้าเกินไป ลองอีกครั้ง';
    case 'INTERNAL_ERROR':
      return 'ระบบขัดข้องชั่วคราว ลองอีกครั้งภายหลัง';
    default:
      return 'เกิดข้อผิดพลาดที่ไม่คาดคิด ลองอีกครั้ง';
  }
}
