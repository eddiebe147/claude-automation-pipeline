import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
} from 'remotion';

export const OpeningScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Logo animation
  const logoScale = spring({
    frame,
    fps,
    config: {
      damping: 100,
      stiffness: 200,
      mass: 0.5,
    },
  });

  // Title fade in
  const titleOpacity = interpolate(frame, [20, 40], [0, 1], {
    extrapolateRight: 'clamp',
  });

  // Subtitle fade in
  const subtitleOpacity = interpolate(frame, [40, 60], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      {/* Logo */}
      <div
        style={{
          transform: `scale(${logoScale})`,
          marginBottom: 40,
        }}
      >
        <div
          style={{
            fontSize: 120,
            fontWeight: 'bold',
            color: 'white',
            fontFamily: 'Arial, sans-serif',
            textShadow: '0 4px 20px rgba(0,0,0,0.3)',
          }}
        >
          ID8
        </div>
      </div>

      {/* Title */}
      <div
        style={{
          opacity: titleOpacity,
          fontSize: 72,
          fontWeight: 'bold',
          color: 'white',
          fontFamily: 'Arial, sans-serif',
          marginBottom: 20,
          textShadow: '0 2px 10px rgba(0,0,0,0.3)',
        }}
      >
        ID8Composer
      </div>

      {/* Subtitle */}
      <div
        style={{
          opacity: subtitleOpacity,
          fontSize: 36,
          color: 'rgba(255,255,255,0.9)',
          fontFamily: 'Arial, sans-serif',
          textAlign: 'center',
          maxWidth: 800,
          textShadow: '0 2px 8px rgba(0,0,0,0.2)',
        }}
      >
        AI-Powered Episodic TV Production Platform
      </div>
    </AbsoluteFill>
  );
};
