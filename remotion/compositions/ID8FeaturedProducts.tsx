import React from 'react';
import {
  AbsoluteFill,
  Sequence,
} from 'remotion';
import { FeaturedProductsOpening } from './scenes/FeaturedProductsOpening';
import { ProductShowcase } from './scenes/ProductShowcase';
import { FeaturedProductsClosing } from './scenes/FeaturedProductsClosing';

// Scene durations in frames (30fps)
const SCENE_DURATIONS = {
  opening: 150,    // 5 seconds
  composer: 240,   // 8 seconds
  deepstack: 240,  // 8 seconds
  milo: 240,       // 8 seconds
  closing: 210,    // 7 seconds
} as const;

// Compute cumulative start frames
const SCENE_STARTS = {
  opening: 0,
  composer: SCENE_DURATIONS.opening,
  deepstack: SCENE_DURATIONS.opening + SCENE_DURATIONS.composer,
  milo: SCENE_DURATIONS.opening + SCENE_DURATIONS.composer + SCENE_DURATIONS.deepstack,
  closing: SCENE_DURATIONS.opening + SCENE_DURATIONS.composer + SCENE_DURATIONS.deepstack + SCENE_DURATIONS.milo,
} as const;

// Product data
const PRODUCTS = [
  {
    name: 'Composer',
    tagline: 'AI Writing Partner with Memory',
    description: 'Create. Think. Remember.',
    color: '#FF6B35',
    features: ['Knowledge Bases', 'Canvas Mode', 'Memory System', 'Story Bible'],
    url: 'https://id8composer.app',
  },
  {
    name: 'DeepStack',
    tagline: 'Trading Research with Claude',
    description: 'Think Deeper. Trade Smarter.',
    color: '#10B981',
    features: ['30+ Analysis Tools', 'Thesis Tracking', 'Emotion-Aware', 'Rule Engine'],
    url: 'https://deepstack.trade',
  },
  {
    name: 'MILO',
    tagline: 'Signal-to-Noise Task Manager',
    description: 'Focus on What Matters.',
    color: '#06B6D4',
    features: ['Natural Language', 'MCP Integration', 'Focus Mode', 'Smart Routing'],
    url: 'https://id8labs.com/products/milo',
  },
];

export const ID8FeaturedProducts: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: '#0a0a0a' }}>
      <Sequence durationInFrames={SCENE_DURATIONS.opening}>
        <FeaturedProductsOpening />
      </Sequence>

      <Sequence from={SCENE_STARTS.composer} durationInFrames={SCENE_DURATIONS.composer}>
        <ProductShowcase product={PRODUCTS[0]} index={0} />
      </Sequence>

      <Sequence from={SCENE_STARTS.deepstack} durationInFrames={SCENE_DURATIONS.deepstack}>
        <ProductShowcase product={PRODUCTS[1]} index={1} />
      </Sequence>

      <Sequence from={SCENE_STARTS.milo} durationInFrames={SCENE_DURATIONS.milo}>
        <ProductShowcase product={PRODUCTS[2]} index={2} />
      </Sequence>

      <Sequence from={SCENE_STARTS.closing} durationInFrames={SCENE_DURATIONS.closing}>
        <FeaturedProductsClosing />
      </Sequence>
    </AbsoluteFill>
  );
};
