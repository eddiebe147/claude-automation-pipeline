import React from 'react';
import { AbsoluteFill, Sequence } from 'remotion';
import { OpeningScene } from './scenes/OpeningScene';
import { DualPanelScene } from './scenes/DualPanelScene';
import { AIAssistantScene } from './scenes/AIAssistantScene';
import { KnowledgeBaseScene } from './scenes/KnowledgeBaseScene';
import { ClosingScene } from './scenes/ClosingScene';

// Scene durations in frames (30fps)
const SCENE_DURATIONS = {
  opening: 90,       // 3 seconds
  dualPanel: 180,    // 6 seconds
  aiAssistant: 180,  // 6 seconds
  knowledgeBase: 180, // 6 seconds
  closing: 270,      // 9 seconds
} as const;

// Compute cumulative start frames
const SCENE_STARTS = {
  opening: 0,
  dualPanel: SCENE_DURATIONS.opening,
  aiAssistant: SCENE_DURATIONS.opening + SCENE_DURATIONS.dualPanel,
  knowledgeBase: SCENE_DURATIONS.opening + SCENE_DURATIONS.dualPanel + SCENE_DURATIONS.aiAssistant,
  closing: SCENE_DURATIONS.opening + SCENE_DURATIONS.dualPanel + SCENE_DURATIONS.aiAssistant + SCENE_DURATIONS.knowledgeBase,
} as const;

export const ID8ComposerDemo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: '#0a0a0a' }}>
      <Sequence durationInFrames={SCENE_DURATIONS.opening}>
        <OpeningScene />
      </Sequence>

      <Sequence from={SCENE_STARTS.dualPanel} durationInFrames={SCENE_DURATIONS.dualPanel}>
        <DualPanelScene />
      </Sequence>

      <Sequence from={SCENE_STARTS.aiAssistant} durationInFrames={SCENE_DURATIONS.aiAssistant}>
        <AIAssistantScene />
      </Sequence>

      <Sequence from={SCENE_STARTS.knowledgeBase} durationInFrames={SCENE_DURATIONS.knowledgeBase}>
        <KnowledgeBaseScene />
      </Sequence>

      <Sequence from={SCENE_STARTS.closing} durationInFrames={SCENE_DURATIONS.closing}>
        <ClosingScene />
      </Sequence>
    </AbsoluteFill>
  );
};
