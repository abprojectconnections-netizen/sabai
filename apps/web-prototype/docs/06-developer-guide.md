# Developer guide
- Add a backend call: extend the contract in `repositories/contract.js`, implement in mock and HTTP repos, add contract tests with a fake fetch.
- Add pure logic in `src/domain` with a unit test; keep React out.
- Tests that depend on today's date must fake `Date` (`vi.useFakeTimers({ toFake: ['Date'] })`).
- Never call `fetch` from components. Never read `import.meta.env` outside `config/env.js`.
