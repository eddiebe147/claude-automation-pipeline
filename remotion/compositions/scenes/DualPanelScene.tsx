import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
} from 'remotion';

export const DualPanelScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Title animation
  const titleY = spring({
    frame,
    fps,
    from: -50,
    to: 0,
    config: {
      damping: 100,
    },
  });

  // Left panel (Canvas) animation
  const leftPanelX = spring({
    frame: frame - 20,
    fps,
    from: -400,
    to: 0,
    config: {
      damping: 100,
    },
  });

  // Right panel (Sandbox) animation
  const rightPanelX = spring({
    frame: frame - 40,
    fps,
    from: 400,
    to: 0,
    config: {
      damping: 100,
    },
  });

  // Description fade in
  const descOpacity = interpolate(frame, [60, 80], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        background: 'linear-gradient(135deg, #1e3a8a 0%, #1e40af 100%)',
        padding: 60,
      }}
    >
      {/* Title */}
      <div
        style={{
          transform: `translateY(${titleY}px)`,
          fontSize: 56,
          fontWeight: 'bold',
          color: 'white',
          fontFamily: 'Arial, sans-serif',
          marginBottom: 40,
          textAlign: 'center',
        }}
      >
        Dual-Panel Writing Environment
      </div>

      {/* Panels Container */}
      <div
        style={{
          display: 'flex',
          gap: 40,
          flex: 1,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {/* Canvas Panel (Left) */}
        <div
          style={{
            transform: `translateX(${leftPanelX}px)`,
            flex: 1,
            height: '70%',
            backgroundColor: '#1f2937',
            borderRadius: 12,
            padding: 30,
            boxShadow: '0 10px 40px rgba(0,0,0,0.3)',
            border: '2px solid #3b82f6',
          }}
        >
          <div
            style={{
              fontSize: 32,
              fontWeight: 'bold',
              color: '#3b82f6',
              marginBottom: 20,
              fontFamily: 'Arial, sans-serif',
            }}
          >
            📄 Canvas
          </div>
          <div
            style={{
              fontSize: 20,
              color: '#9ca3af',
              fontFamily: 'monospace',
              lineHeight: 1.8,
            }}
          >
            INT. COFFEE SHOP - DAY
            <br />
            <br />
            SARAH sits at a corner table,
            <br />
            laptop open. She types furiously.
            <br />
            <br />
            The cafe is bustling with...
          </div>
          <div
            style={{
              marginTop: 30,
              fontSize: 18,
              color: '#6b7280',
              fontFamily: 'Arial, sans-serif',
              fontStyle: 'italic',
            }}
          >
            Your final, polished output
          </div>
        </div>

        {/* Sandbox Panel (Right) */}
        <div
          style={{
            transform: `translateX(${rightPanelX}px)`,
            flex: 1,
            height: '70%',
            backgroundColor: '#1f2937',
            borderRadius: 12,
            padding: 30,
            boxShadow: '0 10px 40px rgba(0,0,0,0.3)',
            border: '2px solid #8b5cf6',
          }}
        >
          <div
            style={{
              fontSize: 32,
              fontWeight: 'bold',
              color: '#8b5cf6',
              marginBottom: 20,
              fontFamily: 'Arial, sans-serif',
            }}
          >
            🎨 Sandbox
          </div>
          <div
            style={{
              fontSize: 20,
              color: '#9ca3af',
              fontFamily: 'monospace',
              lineHeight: 1.8,
            }}
          >
            <span style={{ color: '#10b981' }}>AI:</span> Consider adding more
            <br />
            sensory details to the cafe
            <br />
            scene...
            <br />
            <br />
            <span style={{ color: '#f59e0b' }}>Suggestion:</span>
            <br />
            "The aroma of fresh espresso
            <br />
            mingles with..."
          </div>
          <div
            style={{
              marginTop: 30,
              fontSize: 18,
              color: '#6b7280',
              fontFamily: 'Arial, sans-serif',
              fontStyle: 'italic',
            }}
          >
            AI collaboration workspace
          </div>
        </div>
      </div>

      {/* Description */}
      <div
        style={{
          opacity: descOpacity,
          fontSize: 28,
          color: 'rgba(255,255,255,0.9)',
          fontFamily: 'Arial, sans-serif',
          textAlign: 'center',
          marginTop: 40,
        }}
      >
        Separate your final output from AI experimentation
      </div>
    </AbsoluteFill>
  );
};
