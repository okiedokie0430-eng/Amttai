import React, { useEffect, useRef } from 'react';
import gsap from 'gsap';

/**
 * CinematicSplash
 * A production-grade, full-screen SVG stroke-reveal splash animation.
 *
 * All timing, easing, and color values are externally configurable via props
 * so they can be driven by a design / testing UI (e.g. SplashTestLab).
 */
export default function CinematicSplash({
  onComplete,
  // --- Timing (seconds) ---
  strokeDuration = 1.5,
  fillDuration = 1.0,
  exitDuration = 0.6,
  // --- Stagger ---
  strokeStagger = 0.12,
  // --- Easing ---
  strokeEase = 'power2.inOut',
  fillEase = 'power2.out',
  glowEase = 'power2.out',
  exitEase = 'power3.inOut',
  // --- Glow ---
  glowStartScale = 0.92,
  glowEndScale = 1.08,
  glowOpacity = 0.6,
  glowBlur = 10,
  // --- Exit ---
  exitScale = 1.03,
  exitYPercent = -6,
  // --- Colors ---
  strokeColor = '#e2e8f0',
  fillColor = '#38bdf8',
  accentColor = '#f472b6',
  bgCenter = '#0b1220',
  bgEdge = '#020617',
}) {
  const rootRef = useRef(null);
  const svgRef = useRef(null);
  const tlRef = useRef(null);
  const onCompleteRef = useRef(onComplete);

  useEffect(() => {
    onCompleteRef.current = onComplete;
  }, [onComplete]);

  useEffect(() => {
    const root = rootRef.current;
    const svg = svgRef.current;
    if (!root || !svg) return;

    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const strokes = svg.querySelectorAll('.stroke-path');
    const fills = svg.querySelectorAll('.fill-path');
    const glowGroup = svg.querySelector('.glow-layer');

    // Reset inline styles from previous mounts
    gsap.set([root, svg, strokes, fills, glowGroup], { clearProps: 'all' });
    root.style.clipPath = 'inset(0% 0% 0% 0%)';
    root.style.visibility = 'visible';
    root.style.pointerEvents = 'auto';

    strokes.forEach((path) => {
      const len = path.getTotalLength();
      path.style.strokeDasharray = `${len}`;
      path.style.strokeDashoffset = `${len}`;
    });

    const tl = gsap.timeline({
      onComplete: () => {
        gsap.set(root, { visibility: 'hidden', pointerEvents: 'none' });
        if (typeof onCompleteRef.current === 'function') {
          onCompleteRef.current();
        }
      },
    });
    tlRef.current = tl;

    if (prefersReduced) {
      tl.set(strokes, { strokeDashoffset: 0, opacity: 1 });
      tl.set(fills, { opacity: 1 });
      tl.set(glowGroup, { opacity: glowOpacity * 0.8 });
      tl.to(root, { opacity: 0, duration: 0.4, delay: 0.2 });
      return;
    }

    // 1. STROKE REVEAL
    tl.to(strokes, {
      strokeDashoffset: 0,
      duration: strokeDuration,
      stagger: { each: strokeStagger, from: 'start' },
      ease: strokeEase,
    });

    // 2. GLOW & FILL
    tl.to(
      fills,
      { opacity: 1, duration: fillDuration, ease: fillEase },
      `-=${Math.min(0.3, fillDuration * 0.3)}`
    );

    tl.fromTo(
      glowGroup,
      { opacity: 0, scale: glowStartScale, transformOrigin: '50% 50%' },
      { opacity: glowOpacity, scale: glowEndScale, duration: fillDuration, ease: glowEase },
      `-=${fillDuration}`
    );

    // 3. EXIT WIPE
    tl.to(
      root,
      {
        clipPath: 'inset(0% 0% 100% 0%)',
        yPercent: exitYPercent,
        scale: exitScale,
        duration: exitDuration,
        ease: exitEase,
      },
      `-=${Math.min(0.2, exitDuration * 0.35)}`
    );

    return () => {
      if (tlRef.current) {
        tlRef.current.kill();
        tlRef.current = null;
      }
      gsap.set([root, svg, strokes, fills, glowGroup], { clearProps: 'all' });
    };
  }, [
    strokeDuration, fillDuration, exitDuration, strokeStagger,
    strokeEase, fillEase, glowEase, exitEase,
    glowStartScale, glowEndScale, glowOpacity, glowBlur,
    exitScale, exitYPercent,
    strokeColor, fillColor, accentColor, bgCenter, bgEdge,
  ]);

  const bgGradient = `radial-gradient(ellipse at center, ${bgCenter} 0%, ${bgEdge} 100%)`;

  return (
    <div
      ref={rootRef}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: bgGradient,
        willChange: 'transform, opacity, clip-path',
        clipPath: 'inset(0% 0% 0% 0%)',
      }}
    >
      <svg
        ref={svgRef}
        viewBox="0 0 200 200"
        xmlns="http://www.w3.org/2000/svg"
        style={{
          width: 'min(50vmin, 320px)',
          height: 'min(50vmin, 320px)',
          overflow: 'visible',
        }}
      >
        <defs>
          <filter id="glow-blur" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation={glowBlur} result="coloredBlur" />
            <feMerge>
              <feMergeNode in="coloredBlur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* ================================================================
            REPLACE PATHS BELOW WITH YOUR CUSTOM LOGO / TEXT VECTORS.
            Keep classNames intact so GSAP selectors work.
            ================================================================ */}

        {/* --- Outer ring --- */}
        <path
          className="stroke-path"
          d="M100,20 A80,80 0 1,1 99.99,20"
          fill="none"
          stroke={strokeColor}
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          className="fill-path"
          d="M100,20 A80,80 0 1,1 99.99,20"
          fill="none"
          stroke={strokeColor}
          strokeWidth="2"
          opacity="0"
        />

        {/* --- Inner diamond --- */}
        <path
          className="stroke-path"
          d="M100 60 L140 140 L60 140 Z"
          fill="none"
          stroke={fillColor}
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          className="fill-path"
          d="M100 60 L140 140 L60 140 Z"
          fill={fillColor}
          fillOpacity="0.22"
          stroke="none"
          opacity="0"
        />

        {/* --- Central accent --- */}
        <path
          className="stroke-path"
          d="M100 90 L115 120 L85 120 Z"
          fill="none"
          stroke={accentColor}
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          className="fill-path"
          d="M100 90 L115 120 L85 120 Z"
          fill={accentColor}
          fillOpacity="0.35"
          stroke="none"
          opacity="0"
        />

        {/* --- Glow layer (blurred duplicates) --- */}
        <g className="glow-layer" opacity="0" filter="url(#glow-blur)">
          <path
            d="M100,20 A80,80 0 1,1 99.99,20"
            fill="none"
            stroke={strokeColor}
            strokeWidth="3"
            opacity="0.35"
          />
          <path
            d="M100 60 L140 140 L60 140 Z"
            fill={fillColor}
            fillOpacity="0.35"
            stroke="none"
          />
          <path
            d="M100 90 L115 120 L85 120 Z"
            fill={accentColor}
            fillOpacity="0.35"
            stroke="none"
          />
        </g>
      </svg>
    </div>
  );
}
