import { useState, useEffect, useRef } from 'react';
import './index.css';

const API = 'http://localhost:3002';

const DIFFICULTIES = ['Хялбар', 'Дунд', 'Хүнд'];

const SOURCES = [
  { value: 'mealdb-translate',      label: 'TheMealDB + Google Translate',        icon: '🌍', color: 'var(--cyan)',   desc: 'Fast · Free · 3s delay' },
  { value: 'mealdb-gemini',         label: 'TheMealDB + Gemini',                  icon: '✨', color: 'var(--accent)', desc: 'High quality · 4.5s delay' },
  { value: 'dummyjson-gemini',      label: 'DummyJSON + Gemini',                  icon: '📦', color: 'var(--green)',  desc: 'Open Dataset · 4.5s delay' },
  { value: 'dummyjson-gemini-batch',label: 'DummyJSON + Gemini 2.5 Flash (Batch)',icon: '⚡', color: 'var(--purple)', desc: 'All recipes · 5 per batch · 8s delay' },
  { value: 'dummyjson-openrouter',  label: 'DummyJSON + OpenRouter (Batch)',       icon: '🧠', color: 'var(--orange)', desc: '5 per batch · 30s delay' },
];

const SOURCE_BADGES = {
  'mealdb-translate':       { label: 'MealDB·GT',   cls: 'source-cyan'    },
  'mealdb-gemini':          { label: 'MealDB·Gem',  cls: 'source-accent'  },
  'dummyjson-gemini':       { label: 'Dummy·Gem',   cls: 'source-green'   },
  'dummyjson-gemini-batch': { label: 'Dummy·GBatch',cls: 'source-purple'  },
  'dummyjson-openrouter':   { label: 'Dummy·OR',    cls: 'source-orange'  },
};

function fmt(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleTimeString();
}

function elapsed(startedAt, finishedAt) {
  if (!startedAt) return '00:00';
  const end = finishedAt ? new Date(finishedAt) : new Date();
  const s   = Math.floor((end - new Date(startedAt)) / 1000);
  return `${String(Math.floor(s / 60)).padStart(2,'0')}:${String(s % 60).padStart(2,'0')}`;
}

export default function App() {
  const [logs,        setLogs]        = useState([]);
  const [stats,       setStats]       = useState({ success:0, failed:0, skipped:0, total:0, source:'', startedAt:null, finishedAt:null });
  const [history,     setHistory]     = useState([]);
  const [config,      setConfig]      = useState({ source:'dummyjson-gemini', recipesPerRun:5, delayMs:3000, difficulty:'Дунд', isPremium:false, prepTimeMinutes:15, cookTimeMinutes:30, servings:4 });
  const [running,     setRunning]     = useState(false);
  const [filter,      setFilter]      = useState('all');
  const [autoScroll,  setAutoScroll]  = useState(true);
  const [timer,       setTimer]       = useState('00:00');
  const [configDirty, setConfigDirty] = useState(false);
  const [histFilter,  setHistFilter]  = useState('all');

  const logRef   = useRef(null);
  const timerRef = useRef(null);

  // ── SSE ─────────────────────────────────────────────────────────────────────
  useEffect(() => {
    const es = new EventSource(`${API}/api/logs`);
    es.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.type === 'init') {
        setLogs(msg.logs || []);
        setStats(msg.stats || {});
        setHistory(msg.history || []);
        setConfig(c => ({ ...c, ...(msg.config || {}) }));
        setRunning(msg.stats?.finishedAt === null && msg.stats?.startedAt !== null);
      } else if (msg.type === 'log') {
        if (msg.data?.type === 'clear') { setLogs([]); return; }
        setLogs(prev => [...prev, msg.data].slice(-1000));
      } else if (msg.type === 'stats') {
        setStats(msg.data);
        setRunning(!msg.data.finishedAt && !!msg.data.startedAt);
      } else if (msg.type === 'recipe') {
        setHistory(prev => [msg.data, ...prev]);
      }
    };
    return () => es.close();
  }, []);

  // ── Timer ───────────────────────────────────────────────────────────────────
  useEffect(() => {
    clearInterval(timerRef.current);
    if (stats.startedAt) {
      const tick = () => setTimer(elapsed(stats.startedAt, stats.finishedAt));
      tick();
      if (!stats.finishedAt) timerRef.current = setInterval(tick, 1000);
    }
    return () => clearInterval(timerRef.current);
  }, [stats.startedAt, stats.finishedAt]);

  // ── Auto-scroll ─────────────────────────────────────────────────────────────
  useEffect(() => {
    if (autoScroll && logRef.current)
      logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [logs, autoScroll]);

  // ── Actions ─────────────────────────────────────────────────────────────────
  const startJob = async () => {
    if (configDirty) await saveConfig();
    await fetch(`${API}/api/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ source: config.source, recipesPerRun: config.recipesPerRun }),
    });
    setRunning(true);
  };

  const stopJob  = () => fetch(`${API}/api/stop`, { method: 'POST' });
  const clearLogs = () => fetch(`${API}/api/logs/clear`, { method: 'POST' });

  const saveConfig = async () => {
    await fetch(`${API}/api/config`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(config),
    });
    setConfigDirty(false);
  };

  const updateConfig = (key, value) => {
    setConfig(prev => ({ ...prev, [key]: value }));
    setConfigDirty(true);
  };

  const exportLogs = () => {
    const text = logs.map(l => `[${new Date(l.timestamp).toLocaleTimeString()}] [${l.type.toUpperCase()}] ${l.message}`).join('\n');
    const blob = new Blob([text], { type: 'text/plain' });
    const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: `logs-${Date.now()}.txt` });
    a.click(); URL.revokeObjectURL(a.href);
  };

  const exportHistory = () => {
    const csv = ['ID,Title,Original,Category,Source,Steps,Ingredients,Status,Created At',
      ...history.map(r => `${r.id||''},${JSON.stringify(r.title)},${JSON.stringify(r.originalTitle)},${r.category},${r.source||''},${r.steps},${r.ingredients},${r.status},${r.createdAt}`)
    ].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: `history-${Date.now()}.csv` });
    a.click(); URL.revokeObjectURL(a.href);
  };

  // ── Computed ─────────────────────────────────────────────────────────────────
  const processed    = stats.success + stats.failed;
  const pct          = stats.total > 0 ? Math.round((processed / stats.total) * 100) : 0;
  const statusText   = running ? 'Running' : (stats.finishedAt ? 'Complete' : 'Idle');
  const statusCls    = running ? 'running'  : 'idle';
  const filteredLogs = filter === 'all' ? logs : logs.filter(l => l.type === filter);
  const activeSource = SOURCES.find(s => s.value === config.source) || SOURCES[0];
  const isGemini     = config.source.includes('gemini');
  const effectiveDelay = isGemini ? Math.max(config.delayMs, 4500) : config.delayMs;

  const filteredHistory = histFilter === 'all' ? history
    : histFilter === 'success' ? history.filter(r => r.status === 'success')
    : histFilter === 'failed'  ? history.filter(r => r.status === 'failed')
    : history.filter(r => r.source === histFilter);

  return (
    <div className="app">
      {/* ── Header ──────────────────────────────────────────────────────────── */}
      <header className="header">
        <div className="header-brand">
          <div className="header-logo">🍜</div>
          <div>
            <div className="header-title">Recipe Ingestion Dashboard</div>
            <div className="header-subtitle">Amttai · Multi-Source → Mongolian Cyrillic → Appwrite</div>
          </div>
        </div>
        <div style={{ display:'flex', alignItems:'center', gap:12 }}>
          <div className="pipeline-pill" style={{ borderColor: activeSource.color, color: activeSource.color }}>
            <span>{activeSource.icon}</span>
            <span>{activeSource.label}</span>
          </div>
          {stats.startedAt && <div className="timer">{timer}</div>}
          <div className={`status-badge ${statusCls}`}>
            <span className="status-dot" />{statusText}
          </div>
        </div>
      </header>

      <main className="main">
        {/* ── LEFT ──────────────────────────────────────────────────────────── */}
        <div className="left-panel">

          {/* Stats */}
          <div className="card">
            <div className="card-header">
              <span className="card-title">Session Stats</span>
              <span style={{ fontSize:11, color:'var(--text-muted)' }}>
                {stats.startedAt ? `Started ${fmt(stats.startedAt)}` : 'Not started'}
              </span>
            </div>
            <div className="stats-grid">
              <div className="stat-box"><div className="stat-label">Succeeded</div><div className="stat-value green">{stats.success}</div></div>
              <div className="stat-box"><div className="stat-label">Failed</div><div className="stat-value red">{stats.failed}</div></div>
              <div className="stat-box"><div className="stat-label">Target</div><div className="stat-value accent">{stats.total || config.recipesPerRun}</div></div>
              <div className="stat-box"><div className="stat-label">All-time</div><div className="stat-value cyan">{history.filter(r=>r.status==='success').length}</div></div>
            </div>
            {stats.total > 0 && (
              <div className="progress-section" style={{ marginTop:14 }}>
                <div className="progress-meta">
                  <span className="progress-text">{processed} / {stats.total} processed</span>
                  <span className="progress-pct">{pct}%</span>
                </div>
                <div className="progress-track"><div className="progress-fill" style={{ width:`${pct}%` }} /></div>
              </div>
            )}
          </div>

          {/* Source Selector */}
          <div className="card">
            <div className="card-header"><span className="card-title">Pipeline Source</span></div>
            <div className="source-list">
              {SOURCES.map(s => (
                <button
                  key={s.value}
                  id={`source-${s.value}`}
                  className={`source-btn ${config.source === s.value ? 'active' : ''}`}
                  style={config.source === s.value ? { borderColor: s.color, background: `${s.color}18` } : {}}
                  onClick={() => updateConfig('source', s.value)}
                  disabled={running}
                >
                  <span className="source-icon">{s.icon}</span>
                  <div className="source-info">
                    <span className="source-name" style={config.source === s.value ? { color: s.color } : {}}>{s.label}</span>
                    <span className="source-desc">{s.desc}</span>
                  </div>
                  {config.source === s.value && <span className="source-check" style={{ color: s.color }}>✓</span>}
                </button>
              ))}
            </div>
          </div>

          {/* Controls */}
          <div className="card">
            <div className="card-header"><span className="card-title">Controls</span></div>
            <div className="controls">
              <button className="btn btn-primary" onClick={startJob} disabled={running} id="btn-start">
                ▶ Start Ingestion
              </button>
              <button className="btn btn-danger" onClick={stopJob} disabled={!running} id="btn-stop">
                ⏹ Stop Job
              </button>
              <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:8 }}>
                <button className="btn btn-ghost" onClick={clearLogs} id="btn-clear-logs">🗑 Clear Logs</button>
                <button className="btn btn-ghost" onClick={exportLogs} id="btn-export-logs">↓ Export Logs</button>
              </div>
              <button className="btn btn-ghost" onClick={exportHistory} id="btn-export-history">↓ Export History CSV</button>
            </div>
          </div>

          {/* Config */}
          <div className="card">
            <div className="card-header">
              <span className="card-title">Configuration</span>
              {configDirty && <span style={{ fontSize:10, color:'var(--yellow)', fontWeight:600 }}>● UNSAVED</span>}
            </div>
            <div className="config-grid">
              <div className="config-row">
                <label className="config-label">Recipes Per Run</label>
                <input className="config-input" type="number" min={1} max={100}
                  value={config.recipesPerRun} id="cfg-recipes-per-run"
                  onChange={e => updateConfig('recipesPerRun', parseInt(e.target.value))}
                  disabled={running} />
              </div>
              <div className="config-row">
                <label className="config-label">
                  Delay Between Recipes (ms)
                  {isGemini && config.delayMs < 4500 &&
                    <span style={{ color:'var(--yellow)', fontSize:10, marginLeft:6 }}>⚠ Gemini locks to 4500ms</span>}
                </label>
                <input className="config-input" type="number" min={500} max={30000} step={500}
                  value={config.delayMs} id="cfg-delay"
                  onChange={e => updateConfig('delayMs', parseInt(e.target.value))}
                  disabled={running} />
                {isGemini && config.delayMs < 4500 &&
                  <span style={{ fontSize:10, color:'var(--text-muted)', marginTop:3 }}>Effective: 4500ms</span>}
              </div>
              <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:10 }}>
                <div className="config-row">
                  <label className="config-label">Is Premium</label>
                  <div className="config-toggle" style={{ marginTop:8 }}>
                    <input type="checkbox" id="cfg-premium" checked={config.isPremium}
                      onChange={e => updateConfig('isPremium', e.target.checked)} disabled={running} />
                    <label htmlFor="cfg-premium">{config.isPremium ? 'Yes' : 'No'}</label>
                  </div>
                </div>
              </div>
              <button className="btn btn-ghost" onClick={saveConfig} disabled={running || !configDirty}
                id="btn-save-config" style={{ marginTop:4 }}>
                💾 Save Configuration
              </button>
            </div>
          </div>
        </div>

        {/* ── RIGHT ─────────────────────────────────────────────────────────── */}
        <div className="right-panel">

          {/* Log Viewer */}
          <div className="card log-panel">
            <div className="card-header">
              <span className="card-title">Live Log Stream</span>
              <div className="scroll-toggle">
                <input type="checkbox" id="auto-scroll" checked={autoScroll} onChange={e => setAutoScroll(e.target.checked)} />
                <label htmlFor="auto-scroll">Auto-scroll</label>
              </div>
            </div>
            <div className="log-toolbar">
              <div className="log-filter-group">
                {['all','info','success','warn','error','step','system'].map(f => (
                  <button key={f} id={`filter-${f}`}
                    className={`log-filter-btn ${filter === f ? `active-${f}` : ''}`}
                    onClick={() => setFilter(f)}>
                    {f.charAt(0).toUpperCase() + f.slice(1)}
                    {f !== 'all' && <span style={{ marginLeft:4, opacity:0.7 }}>({logs.filter(l=>l.type===f).length})</span>}
                  </button>
                ))}
              </div>
              <span style={{ fontSize:11, color:'var(--text-muted)' }}>{filteredLogs.length} entries</span>
            </div>
            <div className="log-container" ref={logRef}>
              {filteredLogs.length === 0
                ? <div className="log-empty">No log entries{filter !== 'all' ? ` for "${filter}"` : ''}. Start an ingestion job to see live output.</div>
                : filteredLogs.map(entry => (
                    <div key={entry.id} className="log-entry">
                      <span className="log-time">{new Date(entry.timestamp).toLocaleTimeString()}</span>
                      <span className={`log-msg ${entry.type}`}>{entry.message}</span>
                    </div>
                  ))
              }
            </div>
          </div>

          {/* History */}
          <div className="card history-panel">
            <div className="card-header">
              <span className="card-title">Ingestion History · {history.length} records</span>
              <div style={{ display:'flex', gap:6, alignItems:'center' }}>
                <span style={{ fontSize:11, color:'var(--green)' }}>✅ {history.filter(r=>r.status==='success').length}</span>
                <span style={{ fontSize:11, color:'var(--red)' }}>❌ {history.filter(r=>r.status==='failed').length}</span>
              </div>
            </div>

            {/* History Filter Tabs */}
            <div className="log-toolbar" style={{ marginBottom:10 }}>
              <div className="log-filter-group">
                {[
                  { v:'all',              l:'All' },
                  { v:'success',          l:'Success' },
                  { v:'failed',           l:'Failed' },
                  { v:'mealdb-translate',       l:'MealDB·GT' },
                  { v:'mealdb-gemini',          l:'MealDB·Gem' },
                  { v:'dummyjson-gemini',       l:'Dummy·Gem' },
                  { v:'dummyjson-gemini-batch', l:'Dummy·GBatch' },
                  { v:'dummyjson-openrouter',   l:'Dummy·OR' },
                  { v:'wikibooks-gemini',       l:'Wiki·Gem' },
                ].map(({ v, l }) => (
                  <button key={v}
                    className={`log-filter-btn ${histFilter === v ? 'active-all' : ''}`}
                    onClick={() => setHistFilter(v)} id={`hist-filter-${v}`}>
                    {l}
                    <span style={{ marginLeft:4, opacity:0.7 }}>
                      ({v === 'all' ? history.length
                        : v === 'success' ? history.filter(r=>r.status==='success').length
                        : v === 'failed'  ? history.filter(r=>r.status==='failed').length
                        : history.filter(r=>r.source===v).length})
                    </span>
                  </button>
                ))}
              </div>
            </div>

            {filteredHistory.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">🍽️</div>
                <div>No recipes ingested this session yet.</div>
                <div style={{ fontSize:11, marginTop:4, color:'var(--text-muted)' }}>Start an ingestion job to see results here.</div>
              </div>
            ) : (
              <div className="history-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Thumb</th>
                      <th>Mongolian Title</th>
                      <th>Original</th>
                      <th>Source</th>
                      <th>Category</th>
                      <th>Steps</th>
                      <th>Ingr.</th>
                      <th>Status</th>
                      <th>Doc ID</th>
                      <th>Time</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredHistory.map((r, i) => {
                      const badge = SOURCE_BADGES[r.source] || { label: r.source || '—', cls: '' };
                      return (
                        <tr key={`${r.id}-${i}`}>
                          <td>
                            {r.imageUrl
                              ? <img src={r.imageUrl} alt="" className="td-thumb" />
                              : <div className="td-thumb-placeholder">🍴</div>}
                          </td>
                          <td className="td-title">{r.title}</td>
                          <td className="td-orig">{r.originalTitle}</td>
                          <td><span className={`badge source-badge ${badge.cls}`}>{badge.label}</span></td>
                          <td>{r.category}</td>
                          <td style={{ textAlign:'center' }}>{r.steps}</td>
                          <td style={{ textAlign:'center' }}>{r.ingredients}</td>
                          <td><span className={`badge ${r.status}`}>{r.status === 'success' ? '✅ OK' : '❌ Fail'}</span></td>
                          <td>
                            {r.id
                              ? <span style={{ fontFamily:'JetBrains Mono', fontSize:10, color:'var(--text-muted)' }}>{r.id.slice(0,12)}…</span>
                              : <span style={{ color:'var(--text-muted)', fontSize:11 }}>—</span>}
                          </td>
                          <td style={{ fontSize:11, color:'var(--text-muted)' }}>{fmt(r.createdAt)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
