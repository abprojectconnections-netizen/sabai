import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import BootGate from '../../src/app/BootGate';
import { createMockRepository } from '../../src/repositories/mockRepository';
import { emptyAccountSnapshot } from '../../src/repositories/contract';

const cfg = (over = {}) => Object.freeze({ appEnv: 'development', apiMode: 'mock', apiBaseUrl: '', version: '0.0.0', buildId: 'test', isProduction: false, ...over });

describe('BootGate', () => {
  it('shows loading, then the login screen once the snapshot is ready', async () => {
    render(<BootGate configOverride={cfg()} repositoryOverride={createMockRepository({ latencyMs: 0 })} />);
    expect(screen.getByText('กำลังโหลด Sabai...')).toBeInTheDocument();
    expect(await screen.findByPlaceholderText('you@email.com')).toBeInTheDocument();
  });
  it('shows an error with retry, and recovers', async () => {
    const ok = createMockRepository({ latencyMs: 0 });
    const load = vi.fn().mockRejectedValueOnce(new Error('boom')).mockImplementation(() => ok.loadAccountSnapshot());
    render(<BootGate configOverride={cfg()} repositoryOverride={{ ...ok, loadAccountSnapshot: load }} />);
    expect(await screen.findByRole('alert')).toHaveTextContent('โหลดข้อมูลเริ่มต้นไม่สำเร็จ');
    await userEvent.click(screen.getByRole('button', { name: 'ลองอีกครั้ง' }));
    expect(await screen.findByPlaceholderText('you@email.com')).toBeInTheDocument();
    expect(load).toHaveBeenCalledTimes(2);
  });
  it('rejects an invalid snapshot instead of rendering it', async () => {
    const ok = createMockRepository({ latencyMs: 0 });
    render(<BootGate configOverride={cfg()} repositoryOverride={{ ...ok, loadAccountSnapshot: async () => ({ ...emptyAccountSnapshot(), bookings: 'x' }) }} />);
    expect(await screen.findByRole('alert')).toHaveTextContent('ข้อมูลเริ่มต้นไม่ถูกต้อง');
  });
  it('fails safe on an invalid configuration (no app, no repository calls)', () => {
    vi.stubEnv('VITE_APP_ENV', 'production');
    vi.stubEnv('VITE_API_MODE', 'mock');
    try {
      render(<BootGate />);
      expect(screen.getByText('ตั้งค่าระบบไม่ถูกต้อง')).toBeInTheDocument();
      expect(screen.getByRole('alert')).toHaveTextContent('mock');
      expect(screen.queryByPlaceholderText('you@email.com')).toBeNull();
    } finally { vi.unstubAllEnvs(); }
  });
  it('shows the environment badge outside production and hides it in production', async () => {
    const { unmount } = render(<BootGate configOverride={cfg({ appEnv: 'beta', apiMode: 'beta' })} repositoryOverride={createMockRepository({ latencyMs: 0 })} />);
    expect(await screen.findByTestId('env-badge')).toHaveTextContent(/beta/i);
    unmount();
    render(<BootGate configOverride={cfg({ appEnv: 'production', apiMode: 'production', isProduction: true })} repositoryOverride={createMockRepository({ latencyMs: 0 })} />);
    await screen.findByPlaceholderText('you@email.com');
    await waitFor(() => expect(screen.queryByTestId('env-badge')).toBeNull());
  });
});
