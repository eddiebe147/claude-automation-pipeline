import React, { useEffect, useRef } from 'react';

export const NeuralNetworkBackground: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animationId: number;
    let startTime = Date.now();

    const animate = () => {
      const width = canvas.width;
      const height = canvas.height;
      const elapsed = (Date.now() - startTime) / 1000;

      // Clear with dark background
      ctx.fillStyle = '#0a0a0a';
      ctx.fillRect(0, 0, width, height);

      // Generate nodes
      const nodeCount = 50;
      const nodes: Array<{ x: number; y: number }> = [];

      for (let i = 0; i < nodeCount; i++) {
        const angle = (i / nodeCount) * Math.PI * 2;
        const radius = 150 + Math.sin(elapsed * 0.3 + i * 0.5) * 80;
        const x = width / 2 + Math.cos(angle + elapsed * 0.1) * radius;
        const y = height / 2 + Math.sin(angle + elapsed * 0.1) * radius;
        nodes.push({ x, y });
      }

      // Draw connections
      ctx.strokeStyle = 'rgba(255, 122, 77, 0.15)';
      ctx.lineWidth = 1;

      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < Math.min(i + 5, nodes.length); j++) {
          const dx = nodes[j].x - nodes[i].x;
          const dy = nodes[j].y - nodes[i].y;
          const distance = Math.sqrt(dx * dx + dy * dy);

          if (distance < 250) {
            const alpha = 1 - distance / 250;
            ctx.strokeStyle = `rgba(255, 122, 77, ${0.2 * alpha})`;
            ctx.beginPath();
            ctx.moveTo(nodes[i].x, nodes[i].y);
            ctx.lineTo(nodes[j].x, nodes[j].y);
            ctx.stroke();
          }
        }
      }

      // Draw nodes
      for (let i = 0; i < nodes.length; i++) {
        const pulse = 0.5 + Math.sin(elapsed * 3 + i) * 0.3;

        // Main node
        ctx.fillStyle = `rgba(255, 122, 77, ${0.4 * pulse})`;
        ctx.beginPath();
        ctx.arc(nodes[i].x, nodes[i].y, 3 * pulse, 0, Math.PI * 2);
        ctx.fill();

        // Glow for every 4th node
        if (i % 4 === 0) {
          ctx.fillStyle = `rgba(255, 122, 77, ${0.15 * pulse})`;
          ctx.beginPath();
          ctx.arc(nodes[i].x, nodes[i].y, 8 * pulse, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      animationId = requestAnimationFrame(animate);
    };

    animate();

    return () => cancelAnimationFrame(animationId);
  }, []);

  return (
    <canvas
      ref={canvasRef}
      width={1920}
      height={1080}
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
      }}
    />
  );
};
