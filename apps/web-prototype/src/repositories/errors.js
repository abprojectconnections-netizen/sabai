/** Error raised by every repository implementation so the UI handles failures uniformly. */
export class ApiError extends Error {
  /**
   * @param {{ code: string, message: string, status?: number, requestId?: string }} info
   */
  constructor({ code, message, status = 0, requestId = '' }) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
    this.requestId = requestId;
  }
}

/** User-facing Thai message. Never leaks server internals; the request id is kept on the error for support. */
export function describeApiErrorTh(error) {
  const code = error && error.code;
  switch (code) {
    case 'UNAUTHORIZED': return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    case 'FORBIDDEN': return 'คุณไม่มีสิทธิ์ทำรายการนี้';
    case 'VALIDATION_ERROR': return `ข้อมูลไม่ถูกต้อง: ${error.message}`;
    case 'NOT_FOUND': return 'ไม่พบรายการที่ต้องการ';
    case 'CONFLICT': return 'ไม่สามารถทำรายการนี้ได้ในสถานะปัจจุบันของการจอง';
    case 'FINANCIAL_TRANSACTIONS_DISABLED': return 'ระบบการเงินยังไม่เปิดใช้งานในสภาพแวดล้อมนี้';
    case 'NETWORK_ERROR': return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบอินเทอร์เน็ตแล้วลองอีกครั้ง';
    case 'TIMEOUT': return 'เซิร์ฟเวอร์ตอบสนองช้าเกินไป ลองอีกครั้ง';
    case 'INTERNAL_ERROR': return 'ระบบขัดข้องชั่วคราว ลองอีกครั้งภายหลัง';
    default: return 'เกิดข้อผิดพลาดที่ไม่คาดคิด ลองอีกครั้ง';
  }
}
