import { useEffect, useState } from 'react';
import api from '../services/api';

// Placeholder: replaced by the real homepage in Phase 2/5.
export default function Home() {
  const [health, setHealth] = useState('checking...');
  useEffect(() => {
    api.get('/health').then((r) => setHealth(`API ${r.status}, database ${r.database}`)).catch((e) => setHealth(e.message));
  }, []);
  return (
    <main className="container-page py-20">
      <h1 className="text-4xl font-bold">Store setup complete</h1>
      <p className="mt-3 text-ink-500">{health}</p>
    </main>
  );
}
