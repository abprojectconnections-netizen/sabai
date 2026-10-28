import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import BootGate from '../../src/app/BootGate';
import { createMockRepository } from '../../src/repositories/mockRepository';

const cfg = Object.freeze({ appEnv: 'development', apiMode: 'mock', apiBaseUrl: '', version: '0', buildId: 't', isProduction: false });
const boot = (repo = createMockRepository({ latencyMs: 0 })) => render(<BootGate configOverride={cfg} repositoryOverride={repo} />);

describe('authentication flow', () => {
  it('rejects an empty login with a visible error', async () => {
    boot();
    await userEvent.click(await screen.findByRole('button', { name: 'เข้าสู่ระบบ' }));
    expect(await screen.findByRole('alert')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('you@email.com')).toBeInTheDocument();
  });
  it('shows the server error when login fails', async () => {
    const repo = createMockRepository({ latencyMs: 0 });
    const { ApiError } = await import('../../src/repositories/errors');
    repo.auth.login = vi.fn().mockRejectedValue(new ApiError({ code: 'UNAUTHORIZED', message: 'invalid credentials', status: 401 }));
    boot(repo);
    await userEvent.type(await screen.findByPlaceholderText('you@email.com'), 'a@b.co');
    await userEvent.type(screen.getByPlaceholderText('••••••••'), 'wrongpass');
    await userEvent.click(screen.getByRole('button', { name: 'เข้าสู่ระบบ' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    expect(repo.auth.login).toHaveBeenCalledWith({ email: 'a@b.co', password: 'wrongpass' });
  });
  it('logs in and reaches the home screen', async () => {
    boot();
    await userEvent.type(await screen.findByPlaceholderText('you@email.com'), 'a@b.co');
    await userEvent.type(screen.getByPlaceholderText('••••••••'), 'password1');
    await userEvent.click(screen.getByRole('button', { name: 'เข้าสู่ระบบ' }));
    expect(await screen.findByText('หน้าแรก')).toBeInTheDocument();
    expect(screen.queryByPlaceholderText('you@email.com')).toBeNull();
  });
});
