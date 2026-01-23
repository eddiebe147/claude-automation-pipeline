import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
} from 'remotion';

export const KnowledgeBaseScene: React.FC = () => {
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

  // Three tiers appear sequentially
  const tier1Scale = spring({
    frame: frame - 20,
    fps,
    config: {
      damping: 100,
    },
  });
  const tier2Scale = spring({
    frame: frame - 50,
    fps,
    config: {
      damping: 100,
    },
  });
  const tier3Scale = spring({
    frame: frame - 80,
    fps,
    config: {
      damping: 100,
    },
  });

  // Description fade in
  const descOpacity = interpolate(frame, [110, 130], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        background: 'linear-gradient(135deg, #7c3aed 0%, #a855f7 100%)',
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
          marginBottom: 60,
          textAlign: 'center',
        }}
      >
        3-Tier Knowledge Base System
      </div>

      {/* Three Tiers */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          gap: 50,
          flex: 1,
        }}
      >
        {/* Global Scope */}
        <KBTier
          scale={tier1Scale}
          color="#ef4444"
          icon="🌍"
          title="Global"
          subtitle="World Bible"
          items={['Character Profiles', 'World Rules', 'Story Bible']}
          highlight="All Episodes"
        />

        {/* Regional Scope */}
        <KBTier
          scale={tier2Scale}
          color="#f59e0b"
          icon="🎬"
          title="Regional"
          subtitle="Season Arc"
          items={['Season Plot', 'Production Notes', 'Character Growth']}
          highlight="Current Season"
        />

        {/* Local Scope */}
        <KBTier
          scale={tier3Scale}
          color="#10b981"
          icon="📝"
          title="Local"
          subtitle="Episode Focus"
          items={['Episode Notes', 'Scene Ideas', 'Drafts']}
          highlight="Current Episode"
        />
      </div>

      {/* Description */}
      <div
        style={{
          opacity: descOpacity,
          fontSize: 28,
          color: 'rgba(255,255,255,0.95)',
          fontFamily: 'Arial, sans-serif',
          textAlign: 'center',
          marginTop: 40,
        }}
      >
        Organize your story world with scope-based AI context
      </div>
    </AbsoluteFill>
  );
};

const KBTier: React.FC<{
  scale: number;
  color: string;
  icon: string;
  title: string;
  subtitle: string;
  items: string[];
  highlight: string;
}> = ({ scale, color, icon, title, subtitle, items, highlight }) => (
  <div
    style={{
      transform: `scale(${scale})`,
      width: 400,
    }}
  >
    <div
      style={{
        backgroundColor: '#1f2937',
        borderRadius: 16,
        padding: 30,
        boxShadow: '0 10px 40px rgba(0,0,0,0.3)',
        border: `3px solid ${color}`,
      }}
    >
      {/* Header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 15,
          marginBottom: 25,
        }}
      >
        <div style={{ fontSize: 48 }}>{icon}</div>
        <div>
          <div
            style={{
              fontSize: 32,
              fontWeight: 'bold',
              color: color,
              fontFamily: 'Arial, sans-serif',
            }}
          >
            {title}
          </div>
          <div
            style={{
              fontSize: 18,
              color: '#9ca3af',
              fontFamily: 'Arial, sans-serif',
            }}
          >
            {subtitle}
          </div>
        </div>
      </div>

      {/* Items */}
      <div style={{ marginBottom: 20 }}>
        {items.map((item, index) => (
          <div
            key={index}
            style={{
              fontSize: 18,
              color: '#e5e7eb',
              fontFamily: 'Arial, sans-serif',
              marginBottom: 10,
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <div
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                backgroundColor: color,
              }}
            />
            {item}
          </div>
        ))}
      </div>

      {/* Highlight Badge */}
      <div
        style={{
          backgroundColor: `${color}33`,
          padding: '10px 20px',
          borderRadius: 8,
          border: `2px solid ${color}`,
        }}
      >
        <div
          style={{
            fontSize: 16,
            color: 'white',
            fontWeight: 600,
            fontFamily: 'Arial, sans-serif',
            textAlign: 'center',
          }}
        >
          {highlight}
        </div>
      </div>
    </div>
  </div>
);
