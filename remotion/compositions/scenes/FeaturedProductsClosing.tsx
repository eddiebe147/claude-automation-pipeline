import React from 'react';
import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion';
import { NeuralNetworkBackground } from './NeuralNetworkBackground';

// Product badge configuration
const PRODUCTS = [
  { name: 'Composer', color: '#FF6B35' },
  { name: 'DeepStack', color: '#10B981' },
  { name: 'MILO', color: '#06B6D4' },
] as const;

export const FeaturedProductsClosing: React.FC = () => {
  const frame = useCurrentFrame();

  // Fade in animations
  const fadeIn = interpolate(frame, [0, 60], [0, 1], { extrapolateRight: 'clamp' });
  const scaleUp = interpolate(frame, [0, 60], [0.8, 1], { extrapolateRight: 'clamp' });
  const bottomTextFadeIn = interpolate(frame, [90, 150], [0, 1], { extrapolateRight: 'clamp' });

  // Pre-compute badge animations to avoid inline calculations
  const badgeAnimations = PRODUCTS.map((_, index) => {
    const start = 60 + index * 20;
    const end = 90 + index * 20;
    return {
      opacity: interpolate(frame, [start, end], [0, 1], { extrapolateRight: 'clamp' }),
      translateY: interpolate(frame, [start, end], [20, 0], { extrapolateRight: 'clamp' }),
    };
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: '#0a0a0a',
        overflow: 'hidden',
      }}
    >
      {/* Neural Network Background */}
      <NeuralNetworkBackground />

      {/* Gradient background - multiple product colors */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `linear-gradient(135deg,
            rgba(255, 107, 53, 0.1) 0%,
            rgba(16, 185, 129, 0.1) 33%,
            rgba(6, 182, 212, 0.1) 66%,
            transparent 100%)`,
          pointerEvents: 'none',
        }}
      />

      {/* Animated accent circles */}
      <div
        style={{
          position: 'absolute',
          top: '20%',
          left: '10%',
          width: 300,
          height: 300,
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(255, 107, 53, 0.15) 0%, transparent 70%)',
          filter: 'blur(40px)',
          opacity: fadeIn * 0.6,
        }}
      />

      <div
        style={{
          position: 'absolute',
          bottom: '15%',
          right: '10%',
          width: 400,
          height: 400,
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(6, 182, 212, 0.15) 0%, transparent 70%)',
          filter: 'blur(50px)',
          opacity: fadeIn * 0.5,
        }}
      />

      {/* Main content */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
          textAlign: 'center',
          opacity: fadeIn,
          transform: `scale(${scaleUp})`,
        }}
      >
        {/* Main heading */}
        <h1
          style={{
            fontSize: 88,
            fontWeight: 'bold',
            color: '#FAFAFA',
            fontFamily: 'system-ui, -apple-system, sans-serif',
            margin: 0,
            marginBottom: 30,
            lineHeight: 1.1,
            maxWidth: 1200,
          }}
        >
          Build the Future
        </h1>

        {/* Subheading */}
        <p
          style={{
            fontSize: 40,
            color: '#A3A3A3',
            fontFamily: 'system-ui, -apple-system, sans-serif',
            margin: 0,
            marginBottom: 60,
            maxWidth: 800,
          }}
        >
          Powerful AI tools designed for builders and creators
        </p>

        {/* Product badges */}
        <div
          style={{
            display: 'flex',
            gap: 20,
            justifyContent: 'center',
            marginBottom: 60,
            flexWrap: 'wrap',
          }}
        >
          {PRODUCTS.map((product, index) => (
            <div
              key={product.name}
              style={{
                padding: '12px 24px',
                borderRadius: 12,
                border: `2px solid ${product.color}`,
                background: `${product.color}15`,
                opacity: badgeAnimations[index].opacity,
                transform: `translateY(${badgeAnimations[index].translateY}px)`,
              }}
            >
              <span
                style={{
                  fontSize: 18,
                  fontWeight: 600,
                  color: product.color,
                  fontFamily: 'system-ui, -apple-system, sans-serif',
                  letterSpacing: 1,
                }}
              >
                {product.name}
              </span>
            </div>
          ))}
        </div>

        {/* Divider */}
        <div
          style={{
            width: 120,
            height: 2,
            background: 'linear-gradient(90deg, transparent, #FF6B35, transparent)',
            marginBottom: 40,
          }}
        />

        {/* CTA Text */}
        <p
          style={{
            opacity: bottomTextFadeIn,
            fontSize: 32,
            color: '#737373',
            fontFamily: 'system-ui, -apple-system, sans-serif',
            margin: 0,
          }}
        >
          Visit <span style={{ color: '#FF6B35', fontWeight: 600 }}>id8labs.com</span> today
        </p>
      </div>

      {/* Bottom accent line */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 3,
          background: `linear-gradient(90deg,
            #FF6B35 0%,
            #10B981 50%,
            #06B6D4 100%)`,
          opacity: fadeIn,
        }}
      />
    </AbsoluteFill>
  );
};
