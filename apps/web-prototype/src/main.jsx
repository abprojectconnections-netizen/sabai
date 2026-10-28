import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import BootGate from './app/BootGate';

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BootGate />
  </StrictMode>,
);
