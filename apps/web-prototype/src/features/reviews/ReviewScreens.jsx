import { Plus, Star } from 'lucide-react';
import { PrimaryButton, TopBar } from '../../components/ui';
import { TYPE_GRADIENT, TYPE_ICON } from '../../ui/typeMeta';

export function StarPicker({ value, onChange }) {
  return (
    <div style={{ display: 'flex', gap: 8 }}>
      {[1, 2, 3, 4, 5].map((n) => (
        <button key={n} onClick={() => onChange(n)} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 2 }}>
          <Star size={30} fill={n <= value ? 'var(--amber)' : 'none'} color="var(--amber)" strokeWidth={1.5} />
        </button>
      ))}
    </div>
  );
}

export function TextArea({ placeholder, value, onChange }) {
  return (
    <textarea placeholder={placeholder} value={value} onChange={onChange} rows={5}
      style={{ width: '100%', border: '1.5px solid var(--border)', borderRadius: 14, padding: '12px 14px', fontSize: 13.5, fontFamily: "'Plus Jakarta Sans', sans-serif", color: 'var(--ink)', outline: 'none', resize: 'none' }} />
  );
}

export function ReviewsScreen({ reviews, onBack, onWriteReview }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="รีวิวของฉัน" onBack={onBack} right={
        <button onClick={onWriteReview} style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'none', border: 'none', color: 'var(--pine)', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>
          <Plus size={14} /> เขียนรีวิว
        </button>
      } />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {reviews.length === 0 && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14, textAlign: 'center', padding: 20 }}>
            <div style={{ width: 64, height: 64, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Star size={26} color="var(--pine)" />
            </div>
            <p style={{ fontSize: 14, fontWeight: 700 }}>คุณยังไม่มีรีวิว</p>
            <p style={{ fontSize: 12, color: 'var(--ink-soft)', maxWidth: 220 }}>แบ่งปันประสบการณ์ของคุณให้นักเดินทางคนอื่น</p>
            <div style={{ width: 160 }}><PrimaryButton onClick={onWriteReview}>เขียนรีวิวแรก</PrimaryButton></div>
          </div>
        )}
        {reviews.map((r) => {
          const Icon = TYPE_ICON[r.itemType];
          return (
            <div key={r.id} style={{ border: '1px solid var(--border)', borderRadius: 18, padding: 16 }}>
              <div style={{ display: 'flex', gap: 12, marginBottom: 10 }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, background: TYPE_GRADIENT[r.itemType], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <Icon size={18} color="#fff" />
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--ink)' }}>{r.itemName}</p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                    <div style={{ display: 'flex', gap: 1 }}>
                      {[1, 2, 3, 4, 5].map((n) => <Star key={n} size={12} fill={n <= r.rating ? 'var(--amber)' : 'none'} color="var(--amber)" />)}
                    </div>
                    <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{r.date}</span>
                  </div>
                </div>
              </div>
              <p style={{ fontSize: 12.5, color: 'var(--ink)', lineHeight: 1.6 }}>{r.comment}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function WriteReviewScreen({ listings, selectedItem, onSelectItem, rating, setRating, comment, setComment, onBack, onSubmit }) {
  const canSubmit = selectedItem && rating > 0 && comment.trim().length > 0;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="เขียนรีวิว" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>คุณกำลังรีวิวอะไร?</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {listings.map((item) => {
              const Icon = TYPE_ICON[item.type];
              const active = selectedItem && selectedItem.id === item.id;
              return (
                <button key={item.id} onClick={() => onSelectItem(item)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 14, border: active ? '2px solid var(--pine)' : '1.5px solid var(--border)', background: active ? 'var(--pine-pale)' : 'var(--surface)', cursor: 'pointer', textAlign: 'left' }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: TYPE_GRADIENT[item.type], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Icon size={16} color="#fff" />
                  </div>
                  <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink)' }}>{item.name}</span>
                </button>
              );
            })}
          </div>
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>ให้คะแนนกี่ดาว?</p>
          <StarPicker value={rating} onChange={setRating} />
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>เล่าประสบการณ์ของคุณ</p>
          <TextArea placeholder="บอกเล่าประสบการณ์ให้นักเดินทางคนอื่นฟังหน่อย..." value={comment} onChange={(e) => setComment(e.target.value)} />
        </div>
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={onSubmit} disabled={!canSubmit}>ส่งรีวิว</PrimaryButton>
      </div>
    </div>
  );
}
