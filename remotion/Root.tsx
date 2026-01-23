import React from 'react';
import { Composition } from 'remotion';
import { ID8ComposerDemo } from './compositions/ID8ComposerDemo';
import { ID8FeaturedProducts } from './compositions/ID8FeaturedProducts';

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="ID8ComposerDemo"
        component={ID8ComposerDemo}
        durationInFrames={900} // 30 seconds at 30fps
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="ID8FeaturedProducts"
        component={ID8FeaturedProducts}
        durationInFrames={1080} // 36 seconds at 30fps
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
