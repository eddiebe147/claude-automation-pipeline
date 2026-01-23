import React from 'react';
import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion';
import { NeuralNetworkBackground } from './NeuralNetworkBackground';

interface Product {
  name: string;
  tagline: string;
  description: string;
  color: string;
  features: string[];
  url: string;
}

interface ProductShowcaseProps {
  product: Product;
  index: number;
}

export const ProductShowcase: React.FC<ProductShowcaseProps> = ({
  product,
  index,
}) => {
  const frame = useCurrentFrame();

  // Slide in animation - slower
  const slideInX = interpolate(frame, [0, 50], [1920, 0], {
    extrapolateRight: 'clamp',
  });

  const contentOpacity = interpolate(frame, [20, 70], [0, 1], {
    extrapolateRight: 'clamp',
  });

  // Feature items stagger animation - slower
  const featureAnimations = product.features.map((_, i) => ({
    opacity: interpolate(frame, [70 + i * 15, 90 + i * 15], [0, 1], {
      extrapolateRight: 'clamp',
    }),
    y: interpolate(frame, [70 + i * 15, 90 + i * 15], [20, 0], {
      extrapolateRight: 'clamp',
    }),
  }));

  // Slide out at the very end - slower
  const slideOutX = interpolate(frame, [210, 240], [0, -1920], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: '#0a0a0a',
        overflow: 'hidden',
        transform: `translateX(${slideOutX}px)`,
      }}
    >
      {/* Neural Network Background */}
      <NeuralNetworkBackground />

      {/* Gradient background with product color */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `linear-gradient(135deg, ${product.color}15 0%, ${product.color}05 50%, transparent 100%)`,
          pointerEvents: 'none',
        }}
      />

      {/* Left accent bar */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          bottom: 0,
          width: 4,
          background: product.color,
          boxShadow: `0 0 30px ${product.color}`,
        }}
      />

      {/* Content container */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'flex-start',
          paddingLeft: 120,
          paddingRight: 120,
          opacity: contentOpacity,
        }}
      >
        {/* Product number */}
        <div
          style={{
            fontSize: 20,
            color: product.color,
            fontWeight: 600,
            fontFamily: 'system-ui, -apple-system, sans-serif',
            marginBottom: 20,
            letterSpacing: 4,
            textTransform: 'uppercase',
          }}
        >
          0{index + 1}
        </div>

        {/* Product name */}
        <h1
          style={{
            fontSize: 96,
            fontWeight: 'bold',
            color: '#FAFAFA',
            fontFamily: 'system-ui, -apple-system, sans-serif',
            margin: 0,
            marginBottom: 20,
            lineHeight: 1,
          }}
        >
          {product.name}
        </h1>

        {/* Tagline */}
        <p
          style={{
            fontSize: 28,
            color: product.color,
            fontFamily: 'system-ui, -apple-system, sans-serif',
            margin: 0,
            marginBottom: 20,
            fontWeight: 500,
          }}
        >
          {product.tagline}
        </p>

        {/* Description */}
        <p
          style={{
            fontSize: 32,
            color: '#737373',
            fontFamily: 'system-ui, -apple-system, sans-serif',
            margin: 0,
            marginBottom: 40,
            fontStyle: 'italic',
          }}
        >
          "{product.description}"
        </p>

        {/* Features grid */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(2, 1fr)',
            gap: 20,
            marginTop: 40,
          }}
        >
          {product.features.map((feature, i) => (
            <div
              key={i}
              style={{
                opacity: featureAnimations[i].opacity,
                transform: `translateY(${featureAnimations[i].y}px)`,
                display: 'flex',
                alignItems: 'center',
                gap: 12,
              }}
            >
              {/* Feature dot */}
              <div
                style={{
                  width: 12,
                  height: 12,
                  borderRadius: 6,
                  background: product.color,
                  flexShrink: 0,
                  boxShadow: `0 0 12px ${product.color}`,
                }}
              />
              {/* Feature text */}
              <span
                style={{
                  fontSize: 20,
                  color: '#A3A3A3',
                  fontFamily: 'system-ui, -apple-system, sans-serif',
                  fontWeight: 500,
                }}
              >
                {feature}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Right side - placeholder for screenshot */}
      <div
        style={{
          position: 'absolute',
          right: 120,
          top: '50%',
          transform: 'translateY(-50%)',
          opacity: contentOpacity * 0.6,
        }}
      >
        <div
          style={{
            width: 500,
            height: 400,
            borderRadius: 24,
            background: `linear-gradient(135deg, ${product.color}20 0%, ${product.color}05 100%)`,
            border: `2px solid ${product.color}40`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 18,
            color: product.color,
            fontFamily: 'system-ui, -apple-system, sans-serif',
            boxShadow: `0 0 40px ${product.color}20`,
          }}
        >
          [Product Screenshot]
        </div>
      </div>
    </AbsoluteFill>
  );
};
