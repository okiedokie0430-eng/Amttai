import React, { useState, useEffect, useRef } from 'react';
import './index.css';

const API_BASE = 'http://localhost:3001/api';

function App() {
  const [status, setStatus] = useState('idle');
  const [progress, setProgress] = useState({ processed: 0, total: 0, currentRecipe: '' });
  const [logs, setLogs] = useState([]);
  const logsEndRef = useRef(null);

  useEffect(() => {
    // Setup SSE Connection
    const eventSource = new EventSource(`${API_BASE}/logs`);

    eventSource.onmessage = (event) => {
      const parsed = JSON.parse(event.data);
      if (parsed.type === 'init') {
        setLogs(parsed.data);
      } else if (parsed.type === 'log') {
        setLogs((prev) => {
            const newLogs = [...prev, parsed.data];
            if (newLogs.length > 500) newLogs.shift();
            return newLogs;
        });
      } else if (parsed.type === 'progress') {
        setProgress(parsed.data);
        setStatus(parsed.data.status);
      }
    };

    eventSource.onerror = (error) => {
        console.error("SSE Error:", error);
    };

    return () => {
      eventSource.close();
    };
  }, []);

  // Auto-scroll logs
  useEffect(() => {
    logsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  const handleStart = async () => {
    try {
      await fetch(`${API_BASE}/start`, { method: 'POST' });
    } catch (err) {
      console.error('Failed to start:', err);
    }
  };

  const handleStop = async () => {
    try {
      await fetch(`${API_BASE}/stop`, { method: 'POST' });
    } catch (err) {
      console.error('Failed to stop:', err);
    }
  };

  const percent = progress.total > 0 ? Math.round((progress.processed / progress.total) * 100) : 0;

  return (
    <div className="glass-panel">
      <div className="header">
        <h1>TTS Batch Processing Dashboard</h1>
        <span className={`status-badge status-${status}`}>
          {status.toUpperCase()}
        </span>
      </div>

      <div className="controls">
        <button 
          className="btn-primary" 
          onClick={handleStart} 
          disabled={status === 'running'}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polygon points="5 3 19 12 5 21 5 3"></polygon>
          </svg>
          Start Automation
        </button>
        <button 
          className="btn-danger" 
          onClick={handleStop} 
          disabled={status !== 'running'}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
          </svg>
          Cancel Job
        </button>
      </div>

      <div className="progress-container">
        <div className="progress-header">
          <span>{status === 'running' && progress.currentRecipe ? `Processing: ${progress.currentRecipe}` : 'Ready'}</span>
          <span>{progress.processed} / {progress.total} ({percent}%)</span>
        </div>
        <div className="progress-bar-bg">
          <div className="progress-bar-fill" style={{ width: `${percent}%` }}></div>
        </div>
      </div>

      <div className="logs-container">
        {logs.length === 0 && <div className="log-time">Awaiting logs...</div>}
        {logs.map((log) => (
          <div key={log.id} className="log-entry">
            <span className="log-time">[{new Date(log.timestamp).toLocaleTimeString()}]</span>
            <span className={`log-${log.type}`}>{log.message}</span>
          </div>
        ))}
        <div ref={logsEndRef} />
      </div>
    </div>
  );
}

export default App;
