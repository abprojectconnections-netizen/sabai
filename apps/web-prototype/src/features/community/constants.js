import { BookOpen, Briefcase, HelpCircle, Lightbulb } from 'lucide-react';
import { DESTINATIONS } from '../../data/catalog';

export const ME_ID = 'me';

export const POST_MAX = 500;

export const POST_MIN = 10;

export const POST_TYPE_META = {
  story: { label: 'เรื่องเล่า', icon: BookOpen },
  tip: { label: 'เคล็ดลับ', icon: Lightbulb },
  question: { label: 'คำถาม', icon: HelpCircle },
  trip: { label: 'ทริปแนะนำ', icon: Briefcase },
};

export const COMPOSER_TYPES = ['story', 'tip', 'question'];

export const COMPOSER_HINT = {
  story: 'เล่าประสบการณ์การเดินทางของคุณ เช่น สถานที่ที่ไป สิ่งที่ประทับใจ',
  tip: 'แบ่งปันเคล็ดลับที่ช่วยให้คนอื่นเที่ยวง่ายขึ้น เช่น เวลาที่ควรไป วิธีเดินทาง',
  question: 'ถามสิ่งที่อยากรู้ เช่น ที่พักแถวไหนดี ต้องจองล่วงหน้าไหม',
};

export const REPORT_REASONS = ['สแปมหรือโฆษณา', 'ข้อมูลเท็จหรือทำให้เข้าใจผิด', 'ภาษาไม่สุภาพหรือคุกคาม', 'ละเมิดความเป็นส่วนตัว', 'เหตุผลอื่น'];

export const formatCount = (n) => (n >= 1000 ? `${(n / 1000).toFixed(1).replace(/\.0$/, '')}k` : String(n));

export const destinationGradient = (name) => (DESTINATIONS.find((d) => d.name === name) || {}).gradient || 'linear-gradient(135deg,#1C5C57,#0B2422)';
