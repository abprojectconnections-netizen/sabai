import { ArrowLeft, Sparkles } from 'lucide-react';
import { Chip, PrimaryButton, SecondaryButton, Stepper } from '../../components/ui';
import { DESTINATIONS, STYLE_OPTIONS } from '../../data/catalog';
import { TripItinerary } from '../maps/MapComponents';

export function AiPlannerScreen({ destination, setDestination, days, setDays, budget, setBudget, styles, toggleStyle, travelers, setTravelers, generating, result, onGenerate, onReset, onSave, onBookTrip, saved }) {
  if (generating) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', gap: 18, padding: 20, textAlign: 'center' }}>
        <div style={{ width: 64, height: 64, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center', animation: 'spin-slow 2.2s linear infinite' }}>
          <Sparkles size={28} color="var(--pine)" />
        </div>
        <p className="font-display" style={{ fontSize: 17, fontWeight: 600 }}>AI กำลังจัดทริปให้คุณ...</p>
        <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', maxWidth: 230 }}>กำลังวิเคราะห์งบประมาณ ระยะทาง และสไตล์การเที่ยวที่คุณเลือก</p>
      </div>
    );
  }

  if (result) {
    const total = result.budgetBreakdown.reduce((s, b) => s + b.value, 0);
    const maxVal = Math.max(...result.budgetBreakdown.map((b) => b.value));
    return (
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <div style={{ padding: '18px 20px 12px', borderBottom: '1px solid var(--border)', flexShrink: 0 }}>
          <button onClick={onReset} style={{ background: 'none', border: 'none', color: 'var(--pine)', fontSize: 12, fontWeight: 700, marginBottom: 8, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}><ArrowLeft size={14} /> วางแผนใหม่</button>
          <h1 className="font-display" style={{ fontSize: 19, fontWeight: 600 }}>ทริป {destination} · {days} วัน</h1>
          <p style={{ fontSize: 12, color: 'var(--ink-soft)' }}>{travelers} ผู้เดินทาง · จัดโดย AI</p>
        </div>
        <div className="scrollbar-hide fade-up" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '18px 20px', display: 'flex', flexDirection: 'column', gap: 20 }}>
          <TripItinerary itinerary={result} destination={destination} />

          <div>
            <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>ประมาณการค่าใช้จ่าย</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 10 }}>
              {result.budgetBreakdown.map((b, i) => (
                <div key={i}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
                    <span style={{ color: 'var(--ink)' }}>{b.label}</span>
                    <span style={{ fontWeight: 700, color: 'var(--ink)' }}>฿{b.value.toLocaleString()}</span>
                  </div>
                  <div style={{ height: 6, borderRadius: 999, background: 'var(--pine-pale)' }}>
                    <div style={{ height: '100%', width: `${(b.value / maxVal) * 100}%`, borderRadius: 999, background: 'var(--amber)' }} />
                  </div>
                </div>
              ))}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', paddingTop: 10, borderTop: '1px dashed var(--border)' }}>
              <span style={{ fontSize: 13.5, fontWeight: 700 }}>รวมทั้งหมด</span>
              <span className="font-display" style={{ fontSize: 17, fontWeight: 700, color: 'var(--pine)' }}>฿{total.toLocaleString()}</span>
            </div>
          </div>
        </div>
        <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', display: 'flex', gap: 10, flexShrink: 0 }}>
          <div style={{ flex: 1 }}><SecondaryButton onClick={onSave}>{saved ? 'บันทึกแล้ว ✓' : 'บันทึกทริป'}</SecondaryButton></div>
          <div style={{ flex: 1.4 }}><PrimaryButton onClick={onBookTrip}>จองทริปนี้</PrimaryButton></div>
        </div>
      </div>
    );
  }

  return (
    <div className="scrollbar-hide" style={{ height: '100%', overflowY: 'auto', padding: '20px 20px 28px', display: 'flex', flexDirection: 'column', gap: 22 }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
          <Sparkles size={18} color="var(--amber)" />
          <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--pine)' }}>ผู้ช่วยวางแผนทริป</span>
        </div>
        <h1 className="font-display" style={{ fontSize: 22, fontWeight: 600 }}>ให้ AI จัดทริปในฝันของคุณ</h1>
        <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', marginTop: 4 }}>ตอบคำถามสั้นๆ แล้วปล่อยให้ AI จัดการที่เหลือ</p>
      </div>

      <div>
        <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>อยากไปที่ไหน?</p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {DESTINATIONS.map((d) => <Chip key={d.id} label={d.name} active={destination === d.name} onClick={() => setDestination(d.name)} />)}
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700 }}>กี่วัน?</p>
          <p style={{ fontSize: 11.5, color: 'var(--ink-soft)' }}>รวมวันเดินทาง</p>
        </div>
        <Stepper value={days} onChange={setDays} min={1} max={14} />
      </div>

      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
          <p style={{ fontSize: 13, fontWeight: 700 }}>งบประมาณโดยประมาณ</p>
          <span className="font-display" style={{ fontSize: 15, fontWeight: 700, color: 'var(--pine)' }}>฿{budget.toLocaleString()}</span>
        </div>
        <input type="range" min={3000} max={50000} step={500} value={budget} onChange={(e) => setBudget(Number(e.target.value))} style={{ width: '100%', accentColor: '#10403D' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10.5, color: 'var(--ink-soft)' }}>
          <span>฿3,000</span><span>฿50,000</span>
        </div>
      </div>

      <div>
        <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>สไตล์การเที่ยว</p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {STYLE_OPTIONS.map((s) => <Chip key={s} label={s} active={styles.includes(s)} onClick={() => toggleStyle(s)} />)}
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <p style={{ fontSize: 13, fontWeight: 700 }}>จำนวนผู้เดินทาง</p>
        <Stepper value={travelers} onChange={setTravelers} min={1} max={10} />
      </div>

      <PrimaryButton onClick={onGenerate}>ให้ AI จัดแผนให้ ✨</PrimaryButton>
    </div>
  );
}
