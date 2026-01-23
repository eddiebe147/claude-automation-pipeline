import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
} from 'remotion';

export const AIAssistantScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Title animation
  const titleScale = spring({
    frame,
    fps,
    config: {
      damping: 100,
    },
  });

  // Chat messages appear sequentially
  const message1Opacity = interpolate(frame, [20, 40], [0, 1], {
    extrapolateRight: 'clamp',
  });
  const message2Opacity = interpolate(frame, [50, 70], [0, 1], {
    extrapolateRight: 'clamp',
  });
  const message3Opacity = interpolate(frame, [80, 100], [0, 1], {
    extrapolateRight: 'clamp',
  });

  // Feature badges animation
  const badgesY = spring({
    frame: frame - 110,
    fps,
    from: 50,
    to: 0,
    config: {
      damping: 100,
    },
  });

  return (
    <AbsoluteFill
      style={{
        background: 'linear-gradient(135deg, #059669 0%, #10b981 100%)',
        padding: 60,
      }}
    >
      {/* Title */}
      <div
        style={{
          transform: `scale(${titleScale})`,
          fontSize: 56,
          fontWeight: 'bold',
          color: 'white',
          fontFamily: 'Arial, sans-serif',
          marginBottom: 50,
          textAlign: 'center',
        }}
      >
        AI Writing Assistant
      </div>

      {/* Chat Interface Mockup */}
      <div
        style={{
          maxWidth: 1000,
          margin: '0 auto',
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          gap: 30,
        }}
      >
        {/* User Message */}
        <div
          style={{
            opacity: message1Opacity,
            alignSelf: 'flex-end',
            maxWidth: '70%',
          }}
        >
          <div
            style={{
              backgroundColor: '#3b82f6',
              padding: 25,
              borderRadius: 20,
              boxShadow: '0 4px 20px rgba(0,0,0,0.2)',
            }}
          >
            <div
              style={{
                fontSize: 24,
                color: 'white',
                fontFamily: 'Arial, sans-serif',
                lineHeight: 1.6,
              }}
            >
              Help me develop Sarah's character arc for episode 3
            </div>
          </div>
        </div>

        {/* AI Response */}
        <div
          style={{
            opacity: message2Opacity,
            alignSelf: 'flex-start',
            maxWidth: '70%',
          }}
        >
          <div
            style={{
              backgroundColor: '#1f2937',
              padding: 25,
              borderRadius: 20,
              boxShadow: '0 4px 20px rgba(0,0,0,0.2)',
            }}
          >
            <div
              style={{
                fontSize: 20,
                color: '#10b981',
                fontWeight: 'bold',
                fontFamily: 'Arial, sans-serif',
                marginBottom: 12,
              }}
            >
              🤖 AI Assistant
            </div>
            <div
              style={{
                fontSize: 22,
                color: '#e5e7eb',
                fontFamily: 'Arial, sans-serif',
                lineHeight: 1.6,
              }}
            >
              Based on Sarah's profile in your Knowledge Base, she's facing a
              career crossroads. For episode 3, consider...
            </div>
          </div>
        </div>

        {/* Context Indicator */}
        <div
          style={{
            opacity: message3Opacity,
            alignSelf: 'center',
          }}
        >
          <div
            style={{
              backgroundColor: '#fbbf24',
              padding: 20,
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              gap: 15,
              boxShadow: '0 4px 15px rgba(0,0,0,0.15)',
            }}
          >
            <div style={{ fontSize: 32 }}>📚</div>
            <div
              style={{
                fontSize: 20,
                color: '#1f2937',
                fontWeight: 600,
                fontFamily: 'Arial, sans-serif',
              }}
            >
              Using 3 KB files: Sarah Profile • Season Arc • World Bible
            </div>
          </div>
        </div>
      </div>

      {/* Feature Badges */}
      <div
        style={{
          transform: `translateY(${badgesY}px)`,
          display: 'flex',
          justifyContent: 'center',
          gap: 30,
          marginTop: 40,
        }}
      >
        <Badge icon="🧠" text="Context-Aware" />
        <Badge icon="⚡" text="Real-time" />
        <Badge icon="🎯" text="KB Integration" />
      </div>
    </AbsoluteFill>
  );
};

const Badge: React.FC<{ icon: string; text: string }> = ({ icon, text }) => (
  <div
    style={{
      backgroundColor: 'rgba(255,255,255,0.2)',
      backdropFilter: 'blur(10px)',
      padding: '15px 30px',
      borderRadius: 25,
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      border: '2px solid rgba(255,255,255,0.3)',
    }}
  >
    <div style={{ fontSize: 28 }}>{icon}</div>
    <div
      style={{
        fontSize: 22,
        color: 'white',
        fontWeight: 600,
        fontFamily: 'Arial, sans-serif',
      }}
    >
      {text}
    </div>
  </div>
);
