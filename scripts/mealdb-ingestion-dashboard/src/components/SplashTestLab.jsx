/* This component has been removed. See App.jsx for the updated dashboard. */

const EASINGS = [
  'none',
  'power1.out',
  'power1.inOut',
  'power2.out',
  'power2.inOut',
  'power3.out',
  'power3.inOut',
  'power4.out',
  'power4.inOut',
  'back.out(1.7)',
  'elastic.out(1, 0.3)',
  'expo.out',
  'expo.inOut',
  'circ.out',
  'circ.inOut',
];

const PRESETS = {
  Default: {
    strokeDuration: 1.5, fillDuration: 1.0, exitDuration: 0.6, strokeStagger: 0.12,
    strokeEase: 'power2.inOut', fillEase: 'power2.out', glowEase: 'power2.out', exitEase: 'power3.inOut',
    glowStartScale: 0.92, glowEndScale: 1.08, glowOpacity: 0.6, glowBlur: 10,
    exitScale: 1.03, exitYPercent: -6,
    strokeColor: '#e2e8f0', fillColor: '#38bdf8', accentColor: '#f472b6',
    bgCenter: '#0b1220', bgEdge: '#020617',
  },
  Fast: {
    strokeDuration: 0.8, fillDuration: 0.5, exitDuration: 0.35, strokeStagger: 0.06,
    strokeEase: 'power2.out', fillEase: 'power1.out', glowEase: 'power1.out', exitEase: 'power2.inOut',
    glowStartScale: 0.94, glowEndScale: 1.04, glowOpacity: 0.5, glowBlur: 6,
    exitScale: 1.02, exitYPercent: -4,
    strokeColor: '#e2e8f0', fillColor: '#38bdf8', accentColor: '#f472b6',
    bgCenter: '#0b1220', bgEdge: '#020617',
  },
  Slow: {
    strokeDuration: 2.5, fillDuration: 1.8, exitDuration: 1.2, strokeStagger: 0.25,
    strokeEase: 'power3.inOut', fillEase: 'power2.inOut', glowEase: 'power2.inOut', exitEase: 'power4.inOut',
    glowStartScale: 0.88, glowEndScale: 1.15, glowOpacity: 0.75, glowBlur: 16,
    exitScale: 1.06, exitYPercent: -10,
    strokeColor: '#e2e8f0', fillColor: '#38bdf8', accentColor: '#f472b6',
    bgCenter: '#0b1220', bgEdge: '#020617',
  },
  Dramatic: {
    strokeDuration: 1.8, fillDuration: 1.2, exitDuration: 0.9, strokeStagger: 0.18,
    strokeEase: 'expo.inOut', fillEase: 'expo.out', glowEase: 'expo.out', exitEase: 'power4.inOut',
    glowStartScale: 0.85, glowEndScale: 1.2, glowOpacity: 0.85, glowBlur: 20,
    exitScale: 1.08, exitYPercent: -14,
    strokeColor: '#ffffff', fillColor: '#0ea5e9', accentColor: '#ec4899',
    bgCenter: '#000000', bgEdge: '#0f172a',
  },
  Minimal: {
    strokeDuration: 1.2, fillDuration: 0.8, exitDuration: 0.5, strokeStagger: 0.08,
    strokeEase: 'circ.out', fillEase: 'power1.out', glowEase: 'power1.out', exitEase: 'power2.inOut',
    glowStartScale: 0.95, glowEndScale: 1.02, glowOpacity: 0.3, glowBlur: 4,
    exitScale: 1.01, exitYPercent: -3,
    strokeColor: '#cbd5e1', fillColor: '#64748b', accentColor: '#94a3b8',
    bgCenter: '#f8fafc', bgEdge: '#e2e8f0',
  },
};

function Control({ label, value, onChange, type = 'range', min = 0, max = 1, step = 0.01, options = [], unit = '' }) {
  return (
    <div className="control-row">
      <label className="control-label">
        <span>{label}</span>
        <span className="control-value">{typeof value === 'number' ? `${value}${unit}` : value}</span>
      </label>
      {type === 'range' ? (
        <input
          type="range"
          className="control-slider"
          min={min} max={max} step={step}
          value={value}
          onChange={(e) => onChange(type === 'range' ? parseFloat(e.target.value) : e.target.value)}
        />
      ) : type === 'select' ? (
        <select className="control-select" value={value} onChange={(e) => onChange(e.target.value)}>
          {options.map((o) => (
            <option key={o} value={o}>{o}</option>
          ))}
        </select>
      ) : type === 'color' ? (
        <div className="control-color-wrap">
          <input
            type="color"
            className="control-color"
            value={value}
            onChange={(e) => onChange(e.target.value)}
          />
          <input
            type="text"
            className="control-hex"
            value={value}
            onChange={(e) => onChange(e.target.value)}
          />
        </div>
      ) : null}
    </div>
  );
}

export default function SplashTestLab() {
  const [params, setParams] = useState(() => ({ ...PRESETS.Default }));
  const [key, setKey] = useState(0);
  const [showUnderlay, setShowUnderlay] = useState(true);
  const [completed, setCompleted] = useState(false);
  const timerRef = useRef(null);

  const update = useCallback((key, value) => {
    setParams((p) => ({ ...p, [key]: value }));
  }, []);

  const applyPreset = useCallback((name) => {
    setParams({ ...PRESETS[name] });
    setKey((k) => k + 1);
    setCompleted(false);
  }, []);

  const replay = useCallback(() => {
    setCompleted(false);
    setKey((k) => k + 1);
  }, []);

  // Auto-replay when core params change (debounced slightly via key reset)
  useEffect(() => {
    const t = setTimeout(() => {
      setKey((k) => k + 1);
      setCompleted(false);
    }, 300);
    return () => clearTimeout(t);
  }, [
    params.strokeDuration, params.fillDuration, params.exitDuration, params.strokeStagger,
    params.strokeEase, params.fillEase, params.glowEase, params.exitEase,
    params.glowStartScale, params.glowEndScale, params.glowOpacity, params.glowBlur,
    params.exitScale, params.exitYPercent,
  ]);

  useEffect(() => {
    timerRef.current = setTimeout(() => setCompleted(true), 3500);
    return () => clearTimeout(timerRef.current);
  }, [key]);

  const totalTime = (
    params.strokeDuration +
    params.strokeStagger * 3 +
    params.fillDuration * 0.7 +
    params.exitDuration
  ).toFixed(2);

  const codeBlock = `<CinematicSplash
${Object.entries(params)
  .map(([k, v]) => `  ${k}={${typeof v === 'string' ? `'${v}'` : v}}`)
  .join('\n')}
  onComplete={() => console.log('Done')}
/>`;

  return (
    <div className="splash-lab">
      {/* Preview Area */}
      <div className="splash-preview" style={{ position: 'relative', overflow: 'hidden' }}>
        {showUnderlay && (
          <div className="splash-underlay">
            <div className="underlay-card">
              <div className="underlay-header" />
              <div className="underlay-body">
                <div className="underlay-skeleton" style={{ width: '60%' }} />
                <div className="underlay-skeleton" style={{ width: '90%' }} />
                <div className="underlay-skeleton" style={{ width: '75%' }} />
              </div>
            </div>
            <div className="underlay-card">
              <div className="underlay-header" />
              <div className="underlay-body">
                <div className="underlay-skeleton" style={{ width: '50%' }} />
                <div className="underlay-skeleton" style={{ width: '85%' }} />
                <div className="underlay-skeleton" style={{ width: '65%' }} />
              </div>
            </div>
          </div>
        )}
        <CinematicSplash
          key={key}
          {...params}
          onComplete={() => setCompleted(true)}
        />
      </div>

      {/* Toolbar */}
      <div className="splash-toolbar">
        <div className="splash-toolbar-group">
          <button className="btn btn-primary" onClick={replay}>
            ▶ Replay Animation
          </button>
          <label className="splash-toggle">
            <input
              type="checkbox"
              checked={showUnderlay}
              onChange={(e) => setShowUnderlay(e.target.checked)}
            />
            <span>Show underlay</span>
          </label>
          <span className={`status-pill ${completed ? 'done' : 'running'}`}>
            {completed ? 'Completed' : 'Animating…'}
          </span>
          <span className="timing-badge">~{totalTime}s total</span>
        </div>
        <div className="splash-presets">
          {Object.keys(PRESETS).map((name) => (
            <button
              key={name}
              className="preset-pill"
              onClick={() => applyPreset(name)}
            >
              {name}
            </button>
          ))}
        </div>
      </div>

      {/* Controls Grid */}
      <div className="splash-controls">
        <div className="control-panel">
          <h3 className="control-panel-title">Timing</h3>
          <Control label="Stroke Duration" unit="s" value={params.strokeDuration} min={0.2} max={4} step={0.1} onChange={(v) => update('strokeDuration', v)} />
          <Control label="Fill Duration" unit="s" value={params.fillDuration} min={0.2} max={3} step={0.1} onChange={(v) => update('fillDuration', v)} />
          <Control label="Exit Duration" unit="s" value={params.exitDuration} min={0.1} max={2.5} step={0.1} onChange={(v) => update('exitDuration', v)} />
          <Control label="Stroke Stagger" unit="s" value={params.strokeStagger} min={0} max={1} step={0.02} onChange={(v) => update('strokeStagger', v)} />
        </div>

        <div className="control-panel">
          <h3 className="control-panel-title">Easing</h3>
          <Control label="Stroke Ease" type="select" value={params.strokeEase} options={EASINGS} onChange={(v) => update('strokeEase', v)} />
          <Control label="Fill Ease" type="select" value={params.fillEase} options={EASINGS} onChange={(v) => update('fillEase', v)} />
          <Control label="Glow Ease" type="select" value={params.glowEase} options={EASINGS} onChange={(v) => update('glowEase', v)} />
          <Control label="Exit Ease" type="select" value={params.exitEase} options={EASINGS} onChange={(v) => update('exitEase', v)} />
        </div>

        <div className="control-panel">
          <h3 className="control-panel-title">Glow</h3>
          <Control label="Start Scale" value={params.glowStartScale} min={0.5} max={1.2} step={0.01} onChange={(v) => update('glowStartScale', v)} />
          <Control label="End Scale" value={params.glowEndScale} min={0.9} max={1.5} step={0.01} onChange={(v) => update('glowEndScale', v)} />
          <Control label="Opacity" value={params.glowOpacity} min={0} max={1} step={0.05} onChange={(v) => update('glowOpacity', v)} />
          <Control label="Blur" unit="px" value={params.glowBlur} min={0} max={40} step={1} onChange={(v) => update('glowBlur', v)} />
        </div>

        <div className="control-panel">
          <h3 className="control-panel-title">Exit</h3>
          <Control label="Scale" value={params.exitScale} min={0.95} max={1.3} step={0.01} onChange={(v) => update('exitScale', v)} />
          <Control label="Y Percent" unit="%" value={params.exitYPercent} min={-30} max={0} step={1} onChange={(v) => update('exitYPercent', v)} />
        </div>

        <div className="control-panel">
          <h3 className="control-panel-title">Colors</h3>
          <Control label="Stroke" type="color" value={params.strokeColor} onChange={(v) => update('strokeColor', v)} />
          <Control label="Fill" type="color" value={params.fillColor} onChange={(v) => update('fillColor', v)} />
          <Control label="Accent" type="color" value={params.accentColor} onChange={(v) => update('accentColor', v)} />
          <Control label="BG Center" type="color" value={params.bgCenter} onChange={(v) => update('bgCenter', v)} />
          <Control label="BG Edge" type="color" value={params.bgEdge} onChange={(v) => update('bgEdge', v)} />
        </div>

        <div className="control-panel code-panel">
          <h3 className="control-panel-title">Export Props</h3>
          <pre className="code-block">{codeBlock}</pre>
          <button
            className="btn btn-ghost"
            style={{ marginTop: 8 }}
            onClick={() => navigator.clipboard?.writeText(codeBlock)}
          >
            Copy to clipboard
          </button>
        </div>
      </div>
    </div>
  );
}
