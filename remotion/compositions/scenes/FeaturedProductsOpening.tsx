import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
} from 'remotion';
import { NeuralNetworkBackground } from './NeuralNetworkBackground';

export const FeaturedProductsOpening: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Animations - slower
  const logoScale = interpolate(frame, [0, 50], [0.5, 1], {
    extrapolateRight: 'clamp',
  });

  const logoOpacity = interpolate(frame, [0, 30], [0, 1], {
    extrapolateRight: 'clamp',
  });

  const titleOpacity = interpolate(frame, [40, 90], [0, 1], {
    extrapolateRight: 'clamp',
  });

  const subtitleOpacity = interpolate(frame, [70, 120], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{ backgroundColor: '#0a0a0a', overflow: 'hidden' }}>
      {/* Neural Network Background */}
      <NeuralNetworkBackground />

      {/* Dark overlay for text readability */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'radial-gradient(circle at center, rgba(10,10,10,0.4) 0%, rgba(10,10,10,0.7) 100%)',
        }}
      />

      {/* Content */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
          textAlign: 'center',
        }}
      >
        {/* Logo */}
        <div
          style={{
            opacity: logoOpacity,
            transform: `scale(${logoScale})`,
            marginBottom: 40,
            transition: 'all 0.3s ease',
          }}
        >
          <div
            style={{
              fontSize: 80,
              fontWeight: 'bold',
              color: '#FF6B35',
              fontFamily: 'system-ui, -apple-system, sans-serif',
              textShadow: '0 0 30px rgba(255, 107, 53, 0.6)',
              letterSpacing: 2,
            }}
          >
            ID8LABS
          </div>
        </div>

        {/* Divider */}
        <div
          style={{
            opacity: logoOpacity,
            width: 100,
            height: 2,
            background: 'linear-gradient(90deg, transparent, #FF6B35, transparent)',
            marginBottom: 40,
          }}
        />

        {/* Title */}
        <div
          style={{
            opacity: titleOpacity,
            fontSize: 64,
            fontWeight: 'bold',
            color: '#FAFAFA',
            fontFamily: 'system-ui, -apple-system, sans-serif',
            marginBottom: 20,
          }}
        >
          Featured Products
        </div>

        {/* Subtitle */}
        <div
          style={{
            opacity: subtitleOpacity,
            fontSize: 32,
            color: '#A3A3A3',
            fontFamily: 'system-ui, -apple-system, sans-serif',
            maxWidth: 800,
          }}
        >
          AI-Powered Tools for Innovation
        </div>
      </div>
    </AbsoluteFill>
  );
};
