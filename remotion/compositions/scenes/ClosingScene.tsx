import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
} from 'remotion';

// Animation constants
const FEATURE_START_FRAME = 30;
const FEATURE_STAGGER = 15;

export const ClosingScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Logo animation
  const logoScale = spring({
    frame,
    fps,
    config: { damping: 100, stiffness: 200 },
  });

  // Consolidated feature animations using array mapping
  const featureYValues = [0, 1, 2, 3].map((index) =>
    spring({
      frame: frame - (FEATURE_START_FRAME + index * FEATURE_STAGGER),
      fps,
      from: 50,
      to: 0,
      config: { damping: 100 },
    })
  );

  // CTA fade in
  const ctaOpacity = interpolate(frame, [120, 150], [0, 1], {
    extrapolateRight: 'clamp',
  });

  // CTA pulse
  const ctaScale = interpolate(
    frame,
    [150, 170, 190, 210, 230, 250],
    [1, 1.05, 1, 1.05, 1, 1.05],
    {
      extrapolateRight: 'clamp',
    }
  );

  return (
    <AbsoluteFill
      style={{
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        padding: 60,
      }}
    >
      {/* Logo */}
      <div
        style={{
          transform: `scale(${logoScale})`,
          display: 'flex',
          justifyContent: 'center',
          marginBottom: 50,
        }}
      >
        <div
          style={{
            fontSize: 80,
            fontWeight: 'bold',
            color: 'white',
            fontFamily: 'Arial, sans-serif',
            textShadow: '0 4px 20px rgba(0,0,0,0.3)',
          }}
        >
          ID8Composer
        </div>
      </div>

      {/* Features Grid */}
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          gap: 25,
          maxWidth: 1200,
          margin: '0 auto',
          marginBottom: 60,
        }}
      >
        <Feature
          y={featureYValues[0]}
          icon="[Edit]"
          text="Dual-Panel Editor for Canvas & Sandbox"
        />
        <Feature
          y={featureYValues[1]}
          icon="[AI]"
          text="AI Writing Assistant with Full KB Awareness"
        />
        <Feature
          y={featureYValues[2]}
          icon="[KB]"
          text="3-Tier Knowledge Base System"
        />
        <Feature
          y={featureYValues[3]}
          icon="[Save]"
          text="Auto-Save & Version Control"
        />
      </div>

      {/* Stats */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          gap: 60,
          marginBottom: 50,
        }}
      >
        <Stat value="A+" label="Security Grade" />
        <Stat value="98%+" label="Test Coverage" />
        <Stat value="Production" label="Ready" />
      </div>

      {/* CTA */}
      <div
        style={{
          opacity: ctaOpacity,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 25,
        }}
      >
        <div
          style={{
            transform: `scale(${ctaScale})`,
            backgroundColor: 'white',
            padding: '20px 60px',
            borderRadius: 50,
            boxShadow: '0 10px 40px rgba(0,0,0,0.3)',
            cursor: 'pointer',
          }}
        >
          <div
            style={{
              fontSize: 36,
              fontWeight: 'bold',
              color: '#667eea',
              fontFamily: 'Arial, sans-serif',
            }}
          >
            www.id8composer.app
          </div>
        </div>
        <div
          style={{
            fontSize: 28,
            color: 'rgba(255,255,255,0.9)',
            fontFamily: 'Arial, sans-serif',
            textAlign: 'center',
          }}
        >
          Start writing your next hit series today
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Feature: React.FC<{ y: number; icon: string; text: string }> = ({
  y,
  icon,
  text,
}) => (
  <div
    style={{
      transform: `translateY(${y}px)`,
      backgroundColor: 'rgba(255,255,255,0.15)',
      backdropFilter: 'blur(10px)',
      padding: '20px 40px',
      borderRadius: 16,
      display: 'flex',
      alignItems: 'center',
      gap: 20,
      border: '2px solid rgba(255,255,255,0.3)',
    }}
  >
    <div style={{ fontSize: 40 }}>{icon}</div>
    <div
      style={{
        fontSize: 28,
        color: 'white',
        fontWeight: 500,
        fontFamily: 'Arial, sans-serif',
      }}
    >
      {text}
    </div>
  </div>
);

const Stat: React.FC<{ value: string; label: string }> = ({ value, label }) => (
  <div
    style={{
      textAlign: 'center',
    }}
  >
    <div
      style={{
        fontSize: 48,
        fontWeight: 'bold',
        color: 'white',
        fontFamily: 'Arial, sans-serif',
        marginBottom: 8,
      }}
    >
      {value}
    </div>
    <div
      style={{
        fontSize: 22,
        color: 'rgba(255,255,255,0.8)',
        fontFamily: 'Arial, sans-serif',
      }}
    >
      {label}
    </div>
  </div>
);
