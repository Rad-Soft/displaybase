"use client";

import { useEffect, useRef } from "react";

const vertex = "attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }";

// a warped blend of four points, then an 8x8 ordered dither
const fragment = `
precision highp float;
uniform vec2 size;
uniform float time;
uniform float seed;

float bayer2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }

void main() {
  vec2 uv = gl_FragCoord.xy / size;
  vec2 p = vec2(uv.x * size.x / size.y, uv.y);
  float wide = size.x / size.y;
  p += 0.16 * vec2(sin(p.y * 3.1 + time * 0.22 + seed), cos(p.x * 2.3 - time * 0.18 + seed * 1.7));
  p += 0.07 * vec2(sin(p.y * 7.0 - time * 0.3), cos(p.x * 6.0 + time * 0.26));

  vec3 night = vec3(0.004, 0.030, 0.050);
  vec3 deep = vec3(0.010, 0.125, 0.185);
  vec3 sky = vec3(0.631, 0.784, 0.875);
  vec3 clay = vec3(0.945, 0.655, 0.510);

  vec2 a = vec2(wide * (0.93 + 0.04 * sin(time * 0.17 + seed)), 0.52 + 0.08 * cos(time * 0.21));
  vec2 b = vec2(wide * (0.56 + 0.06 * cos(time * 0.19)), 0.10 + 0.06 * sin(time * 0.15 + seed));
  vec2 c = vec2(wide * 0.30, 0.84);
  vec2 d = vec2(wide * 1.02, 0.02);

  float wa = 1.0 / pow(distance(p, a) + 0.08, 2.6);
  float wb = 1.0 / pow(distance(p, b) + 0.10, 2.4);
  float wc = 4.2 / pow(distance(p, c) + 0.12, 2.2);
  float wd = 1.5 / pow(distance(p, d) + 0.14, 2.2);
  vec3 color = (clay * wa + sky * wb + night * wc + deep * wd) / (wa + wb + wc + wd);

  float levels = 7.0;
  color = floor(color * levels + bayer8(gl_FragCoord.xy)) / levels;
  gl_FragColor = vec4(color, 1.0);
}`;

function compile(gl: WebGLRenderingContext, type: number, source: string) {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  return gl.getShaderParameter(shader, gl.COMPILE_STATUS) ? shader : null;
}

export function Mesh({ className = "", seed = 0 }: { className?: string; seed?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    const gl = canvas?.getContext("webgl", { antialias: false, depth: false });
    if (!canvas || !gl) return;

    const program = gl.createProgram();
    const shaders = [compile(gl, gl.VERTEX_SHADER, vertex), compile(gl, gl.FRAGMENT_SHADER, fragment)];
    if (!program || shaders.includes(null)) return;
    for (const shader of shaders) gl.attachShader(program, shader!);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return;
    gl.useProgram(program);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    const position = gl.getAttribLocation(program, "p");
    gl.enableVertexAttribArray(position);
    gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
    const size = gl.getUniformLocation(program, "size");
    const time = gl.getUniformLocation(program, "time");
    gl.uniform1f(gl.getUniformLocation(program, "seed"), seed);

    const still = matchMedia("(prefers-reduced-motion: reduce)");
    let frame = 0;
    let last = -1000;
    let visible = false;

    function draw(now: number) {
      // a third of the resolution, so the dither shows and it stays cheap
      const width = Math.max(1, Math.round(canvas!.clientWidth / 2.5));
      const height = Math.max(1, Math.round(canvas!.clientHeight / 2.5));
      if (canvas!.width !== width || canvas!.height !== height) {
        canvas!.width = width;
        canvas!.height = height;
        gl!.viewport(0, 0, width, height);
      }
      gl!.uniform2f(size, width, height);
      gl!.uniform1f(time, still.matches ? 8 : 8 + now / 1000);
      gl!.drawArrays(gl!.TRIANGLES, 0, 3);
    }

    function loop(now: number) {
      if (now - last > 50) {
        last = now;
        draw(now);
      }
      frame = requestAnimationFrame(loop);
    }

    function update() {
      cancelAnimationFrame(frame);
      if (!visible) return;
      if (still.matches) draw(0);
      else frame = requestAnimationFrame(loop);
    }

    const seen = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      update();
    });
    const sized = new ResizeObserver(() => visible && draw(performance.now()));
    seen.observe(canvas);
    sized.observe(canvas);
    still.addEventListener("change", update);
    return () => {
      cancelAnimationFrame(frame);
      seen.disconnect();
      sized.disconnect();
      still.removeEventListener("change", update);
    };
  }, [seed]);

  return (
    <div aria-hidden className={`mesh ${className}`}>
      <canvas ref={ref} className="size-full" />
    </div>
  );
}
