'use client';

/**
 * Portrait Background Tool — Commercial-grade v3
 *
 * Architecture (unchanged):
 * - origCanvas:    full-res original RGB, never modified
 * - alphaMask:     full-res Float32Array (0.0–1.0), brush + auto-polish edit this
 * - previewCanvas: composited display canvas, CSS-scaled
 *
 * New in v3:
 * - Provider/model selector (Auto / remove.bg / Photoroom / Clipdrop)
 * - Auto polish edges (halo removal, edge smoothing, gap fill)
 * - Matte/halo cleanup during compositing
 * - Quality score display
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { Download, Loader2, Sparkles, Undo2, Upload } from 'lucide-react';

// ─── Constants ────────────────────────────────────────────────────────────────

const BG_OPTIONS = [
  { label: 'White', value: '#ffffff' },
  { label: 'Red',   value: '#d71920' },
  { label: 'Blue',  value: '#2f5eea' },
  { label: 'Gray',  value: '#6b7280' },
];

const FORMAT_OPTIONS = [
  { label: 'PNG',  mime: 'image/png',  ext: 'png',  quality: undefined },
  { label: 'JPG',  mime: 'image/jpeg', ext: 'jpg',  quality: 0.95 },
  { label: 'WebP', mime: 'image/webp', ext: 'webp', quality: 0.95 },
];

// Static provider definitions — availability is filled in from API / response headers
const PROVIDER_DEFS = [
  { id: 'auto',      name: 'Auto Best',  tag: 'recommended', description: 'Tries all providers, picks best result' },
  { id: 'removebg',  name: 'remove.bg',  tag: 'best hair',   description: 'Best for portraits and hair detail' },
  { id: 'photoroom', name: 'Photoroom',  tag: 'ID photos',   description: 'Good for complex mixed objects' },
  { id: 'clipdrop',  name: 'Clipdrop',   tag: 'fast',        description: 'Fast alternative model' },
] as const;

type ProviderId = 'auto' | 'removebg' | 'photoroom' | 'clipdrop';
type Status     = 'idle' | 'uploading' | 'done' | 'error';
type BrushMode  = 'erase' | 'restore';
type ExportFmt  = 'png' | 'jpg' | 'webp';

// ─── Pure functions (no React deps) ──────────────────────────────────────────

function hexToRgb(hex: string): [number, number, number] {
  return [parseInt(hex.slice(1,3),16), parseInt(hex.slice(3,5),16), parseInt(hex.slice(5,7),16)];
}

function loadImg(src: string): Promise<HTMLImageElement> {
  return new Promise((res, rej) => {
    const img = new Image();
    img.onload = () => res(img);
    img.onerror = () => rej(new Error('Cannot load image'));
    img.src = src;
  });
}

function imageToCanvas(img: HTMLImageElement): HTMLCanvasElement {
  const cv = document.createElement('canvas');
  cv.width = img.naturalWidth;
  cv.height = img.naturalHeight;
  cv.getContext('2d')!.drawImage(img, 0, 0);
  return cv;
}

function extractAlphaMask(subjectImg: HTMLImageElement, fullW: number, fullH: number): Float32Array {
  const cv = document.createElement('canvas');
  cv.width = fullW; cv.height = fullH;
  cv.getContext('2d')!.drawImage(subjectImg, 0, 0, fullW, fullH);
  const px = cv.getContext('2d')!.getImageData(0, 0, fullW, fullH).data;
  const mask = new Float32Array(fullW * fullH);
  for (let i = 0; i < fullW * fullH; i++) mask[i] = px[i * 4 + 3] / 255;
  return mask;
}

/**
 * Composite origCanvas + alphaMask + bgColor → output canvas.
 * Includes optional matte correction for semi-transparent edge pixels.
 */
function compositeToCanvas(
  origCanvas: HTMLCanvasElement,
  alphaMask: Float32Array,
  bgColor: string,
  outW: number,
  outH: number,
  matteStrength = 0,   // 0 = off, 0.35 = default, controls halo cleanup intensity
): HTMLCanvasElement {
  const [bgR, bgG, bgB] = hexToRgb(bgColor);
  const oc = document.createElement('canvas');
  oc.width = outW; oc.height = outH;
  const oCtx = oc.getContext('2d')!;

  const srcCv = document.createElement('canvas');
  srcCv.width = outW; srcCv.height = outH;
  srcCv.getContext('2d')!.drawImage(origCanvas, 0, 0, outW, outH);
  const srcPx = srcCv.getContext('2d')!.getImageData(0, 0, outW, outH).data;

  const outData = oCtx.createImageData(outW, outH);
  const op = outData.data;

  for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
      const mx = Math.min(Math.floor(x * origCanvas.width / outW), origCanvas.width - 1);
      const my = Math.min(Math.floor(y * origCanvas.height / outH), origCanvas.height - 1);
      let a = alphaMask[my * origCanvas.width + mx];

      const fi = (y * outW + x) * 4;
      let sR = srcPx[fi], sG = srcPx[fi+1], sB = srcPx[fi+2];

      // Matte correction: for semi-transparent edge pixels, reduce background
      // color contamination ("halo cleanup"). Only active in 0.05–0.95 alpha range.
      if (matteStrength > 0 && a > 0.05 && a < 0.95) {
        const fringeFactor = matteStrength * (1 - a) * 0.6;
        sR = Math.round(sR + (sR - bgR) * fringeFactor);
        sG = Math.round(sG + (sG - bgG) * fringeFactor);
        sB = Math.round(sB + (sB - bgB) * fringeFactor);
        sR = Math.max(0, Math.min(255, sR));
        sG = Math.max(0, Math.min(255, sG));
        sB = Math.max(0, Math.min(255, sB));
      }

      op[fi]   = Math.round(sR * a + bgR * (1 - a));
      op[fi+1] = Math.round(sG * a + bgG * (1 - a));
      op[fi+2] = Math.round(sB * a + bgB * (1 - a));
      op[fi+3] = 255;
    }
  }
  oCtx.putImageData(outData, 0, 0);
  return oc;
}

/**
 * Auto-polish alpha mask in-place.
 * Only modifies edge pixels (alpha 0.02–0.98); leaves solid subject/bg alone.
 * Returns the modified mask (same reference for performance).
 */
function autoPolishMask(
  mask: Float32Array,
  W: number,
  H: number,
  opts: { strength: number; removeHalo: boolean; preserveHair: boolean },
): Float32Array {
  const next = mask.slice();
  const s = opts.strength / 100;

  function getNeighbors(idx: number): number[] {
    const x = idx % W; const y = Math.floor(idx / W);
    const ns: number[] = [];
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (dx === 0 && dy === 0) continue;
        const nx = x + dx; const ny = y + dy;
        if (nx >= 0 && nx < W && ny >= 0 && ny < H) ns.push(mask[ny * W + nx]);
      }
    }
    return ns;
  }

  for (let i = 0; i < W * H; i++) {
    const a = mask[i];
    // Only process edge pixels; solid subject (>0.98) and solid bg (<0.02) unchanged
    if (a <= 0.02 || a >= 0.98) { next[i] = a; continue; }

    const ns = getNeighbors(i);
    if (ns.length === 0) continue;

    ns.sort((p, q) => p - q);
    const median = ns[Math.floor(ns.length / 2)];
    const personCount = ns.filter(v => v > 0.65).length;
    const bgCount     = ns.filter(v => v < 0.08).length;

    let newA = a;

    // 1. Hard-clamp near-bg edge pixels (remove small halo artifacts)
    if (opts.removeHalo && a < 0.08 && bgCount >= 4) {
      newA = 0;
    }
    // 2. Hard-clamp near-solid subject pixels
    else if (opts.removeHalo && a > 0.96 && personCount >= 4) {
      newA = 1;
    }
    // 3. Fill small gaps in subject (isolated low-alpha surrounded by subject)
    else if (personCount >= 6 && a < 0.50) {
      newA = a + (median - a) * s * 0.8;
    }
    // 4. Remove isolated noise in background area
    else if (bgCount >= 6 && a > 0.50) {
      newA = a + (median - a) * s * 0.8;
    }
    // 5. General edge smoothing
    else {
      // Preserve hair: thin semi-transparent regions should keep more detail
      const hairLikelihood = opts.preserveHair && a > 0.15 && a < 0.85 && personCount >= 2 && personCount <= 5 ? 0.35 : 1;
      newA = a + (median - a) * s * 0.4 * hairLikelihood;
    }

    next[i] = Math.max(0, Math.min(1, newA));
  }

  // Copy back to original array
  for (let i = 0; i < mask.length; i++) mask[i] = next[i];
  return mask;
}

// ─── Component ────────────────────────────────────────────────────────────────

export function ProfilePhotoBackgroundTool() {
  // ── Core state ──────────────────────────────────────────────────────────────
  const [status,       setStatus]       = useState<Status>('idle');
  const [bgColor,      setBgColor]      = useState('#ffffff');
  const [stage,        setStage]        = useState('');
  const [errorMsg,     setErrorMsg]     = useState<string | null>(null);
  const [warnings,     setWarnings]     = useState<string[]>([]);
  const [usedProvider, setUsedProvider] = useState<string>('');
  const [qualityScore, setQualityScore] = useState<number | null>(null);
  const [configuredProviders, setConfiguredProviders] = useState<string[]>([]);
  const [skipProviders, setSkipProviders] = useState<string[]>([]);

  // ── Provider selector ────────────────────────────────────────────────────────
  const [selectedProvider, setSelectedProvider] = useState<ProviderId>('auto');

  // ── Auto-polish state ────────────────────────────────────────────────────────
  const [polishing,      setPolishing]     = useState(false);
  const [edgeStrength,   setEdgeStrength]  = useState(35);
  const [removeHalo,     setRemoveHalo]    = useState(true);
  const [preserveHair,   setPreserveHair]  = useState(true);
  const [matteCleanup,   setMatteCleanup]  = useState(true);

  // ── Brush state ─────────────────────────────────────────────────────────────
  const [refineMode, setRefineMode] = useState(false);
  const [brushMode,  setBrushMode]  = useState<BrushMode>('erase');
  const [brushSize,  setBrushSize]  = useState(30);
  const [brushSoft,  setBrushSoft]  = useState(70);
  const [cursor,     setCursor]     = useState({ visible: false, x: 0, y: 0 });

  // ── Undo ─────────────────────────────────────────────────────────────────────
  const [undoStack, setUndoStack] = useState<Float32Array[]>([]);

  // ── Export ───────────────────────────────────────────────────────────────────
  const [exportFmt, setExportFmt] = useState<ExportFmt>('png');

  // ── Refs ─────────────────────────────────────────────────────────────────────
  const origCanvasRef  = useRef<HTMLCanvasElement | null>(null);
  const alphaMaskRef   = useRef<Float32Array | null>(null);
  const previewRef     = useRef<HTMLCanvasElement>(null);
  const origUrl        = useRef<string | null>(null);
  const currentFile    = useRef<File | null>(null);
  const isPainting     = useRef(false);
  const fileRef        = useRef<HTMLInputElement>(null);
  const previewWrapRef = useRef<HTMLDivElement>(null);

  // ── Rendering ────────────────────────────────────────────────────────────────

  const doRender = useCallback(() => {
    const orig  = origCanvasRef.current;
    const alpha = alphaMaskRef.current;
    const pc    = previewRef.current;
    if (!orig || !alpha || !pc) return;

    const MAX = 900;
    const scale = Math.min(1, MAX / Math.max(orig.width, orig.height));
    const dW = Math.round(orig.width * scale);
    const dH = Math.round(orig.height * scale);

    const matte = matteCleanup ? edgeStrength / 100 * 0.4 : 0;
    const composed = compositeToCanvas(orig, alpha, bgColor, dW, dH, matte);
    pc.width  = composed.width;
    pc.height = composed.height;
    pc.getContext('2d')!.drawImage(composed, 0, 0);
  }, [bgColor, matteCleanup, edgeStrength]);

  useEffect(() => { if (status === 'done') doRender(); }, [bgColor, status, doRender]);

  // ── Upload & process ─────────────────────────────────────────────────────────

  async function processFile(
    file: File,
    providerOverride?: ProviderId,
    preserveOnError = false,
  ) {
    if (!file.type.startsWith('image/')) { setErrorMsg('Please upload a JPG, PNG, or WebP image.'); return; }
    if (file.size > 12 * 1024 * 1024) { setErrorMsg('Image too large. Max 12 MB.'); return; }

    currentFile.current = file;
    const hadResult = status === 'done' && Boolean(origCanvasRef.current);

    setStatus('uploading');
    setErrorMsg(null);

    if (!preserveOnError) {
      setWarnings([]); setUsedProvider(''); setQualityScore(null);
      setRefineMode(false); setUndoStack([]);
      if (origUrl.current) URL.revokeObjectURL(origUrl.current);
      origUrl.current = URL.createObjectURL(file);
    }

    const provider = providerOverride ?? selectedProvider;

    try {
      setStage(provider === 'auto' ? 'Removing background…' : `Removing background with ${provider}…`);

      const fd = new FormData();
      fd.append('image', file);
      fd.append('options', JSON.stringify({
        qualityMode: 'best',
        preferredProvider: provider,
        // If specific provider chosen, don't auto-fallback on failure
        skipProviders: provider !== 'auto' ? [] : skipProviders,
      }));

      const res = await fetch('/api/photo/remove-background', { method: 'POST', body: fd });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        const msg = body.error ?? `Error ${res.status}`;
        // preserveOnError = user switched provider; keep existing result visible
        throw new Error(preserveOnError ? `${PROVIDER_DEFS.find(p => p.id === provider)?.name ?? provider} failed: ${msg}. Current result preserved.` : msg);
      }

      const prov    = res.headers.get('X-Provider') ?? '';
      const qScore  = parseFloat(res.headers.get('X-Quality-Score') ?? '0');
      const warnStr = res.headers.get('X-Quality-Warnings') ?? '';
      const cfgProvs = (res.headers.get('X-Configured-Providers') ?? '').split(',').filter(Boolean);

      setUsedProvider(prov);
      setQualityScore(isNaN(qScore) ? null : qScore);
      setWarnings(warnStr ? warnStr.split(',').filter(Boolean) : []);
      if (cfgProvs.length > 0) setConfiguredProviders(cfgProvs);

      setStage('Loading result…');
      const pngBlob    = await res.blob();
      const subjectUrl = URL.createObjectURL(pngBlob);
      const [subjectImg, origImg] = await Promise.all([loadImg(subjectUrl), loadImg(origUrl.current!)]);
      URL.revokeObjectURL(subjectUrl);

      origCanvasRef.current = imageToCanvas(origImg);
      alphaMaskRef.current  = extractAlphaMask(subjectImg, origImg.naturalWidth, origImg.naturalHeight);

      setUndoStack([]);
      setRefineMode(false);
      setStage(''); setStatus('done'); doRender();
    } catch (err: any) {
      setErrorMsg(err?.message ?? 'Unknown error.');
      setStatus(preserveOnError && hadResult ? 'done' : 'error');
      setStage('');
    }
  }

  // When user clicks a different provider button:
  async function switchProvider(p: ProviderId) {
    setSelectedProvider(p);
    setSkipProviders([]); // reset skip list on manual switch
    if (currentFile.current) {
      await processFile(currentFile.current, p, /* preserveOnError */ true);
    }
  }

  // "Try higher quality" — skip current provider, try next
  async function tryHigherQuality() {
    if (!currentFile.current) return;
    const newSkip = usedProvider ? [...skipProviders, usedProvider] : skipProviders;
    setSkipProviders(newSkip);
    await processFile(currentFile.current, 'auto', true);
  }

  // ── Auto-polish ──────────────────────────────────────────────────────────────

  function autoPolish() {
    const alpha = alphaMaskRef.current;
    const orig  = origCanvasRef.current;
    if (!alpha || !orig) return;

    setPolishing(true);
    // Push undo before modifying
    setUndoStack(prev => [alpha.slice(), ...prev].slice(0, 30));

    // Run in next microtask so React can update the "polishing" spinner
    setTimeout(() => {
      autoPolishMask(alpha, orig.width, orig.height, {
        strength: edgeStrength,
        removeHalo,
        preserveHair,
      });
      doRender();
      setPolishing(false);
    }, 0);
  }

  // ── Brush ─────────────────────────────────────────────────────────────────────

  function pointerToMaskCoords(e: React.PointerEvent<HTMLCanvasElement>): [number, number] {
    const cv   = previewRef.current!;
    const rect = cv.getBoundingClientRect();
    const orig = origCanvasRef.current!;
    const cvX  = (e.clientX - rect.left) * (cv.width  / rect.width);
    const cvY  = (e.clientY - rect.top)  * (cv.height / rect.height);
    return [
      Math.round(cvX * (orig.width  / cv.width)),
      Math.round(cvY * (orig.height / cv.height)),
    ];
  }

  function brushRadiusInMask(): number {
    const cv   = previewRef.current;
    const orig = origCanvasRef.current;
    if (!cv || !orig) return brushSize;
    return (brushSize / 2) * (orig.width / cv.getBoundingClientRect().width);
  }

  function paintAtMask(mx: number, my: number) {
    const alpha = alphaMaskRef.current;
    const orig  = origCanvasRef.current;
    if (!alpha || !orig) return;
    const W = orig.width; const H = orig.height;
    const r = brushRadiusInMask();
    const soft = brushSoft / 100;
    const x0 = Math.max(0, Math.floor(mx-r-1)), y0 = Math.max(0, Math.floor(my-r-1));
    const x1 = Math.min(W, Math.ceil(mx+r+1)),  y1 = Math.min(H, Math.ceil(my+r+1));
    for (let py = y0; py < y1; py++) {
      for (let px = x0; px < x1; px++) {
        const dist = Math.sqrt((px-mx)**2+(py-my)**2);
        if (dist > r) continue;
        const hard  = Math.max(0, 1 - dist/r);
        const soft2 = Math.max(0, 1 - (dist/(r*0.8))**2);
        const t = hard*(1-soft) + soft2*soft;
        const idx = py*W+px;
        alpha[idx] = brushMode === 'erase' ? Math.max(0, alpha[idx]-t) : Math.min(1, alpha[idx]+t);
      }
    }
    doRender();
  }

  function onPointerDown(e: React.PointerEvent<HTMLCanvasElement>) {
    if (!refineMode) return;
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    isPainting.current = true;
    if (alphaMaskRef.current) setUndoStack(prev => [alphaMaskRef.current!.slice(), ...prev].slice(0, 30));
    paintAtMask(...pointerToMaskCoords(e));
  }
  function onPointerMove(e: React.PointerEvent<HTMLCanvasElement>) {
    const rect = previewRef.current!.getBoundingClientRect();
    setCursor({ visible: true, x: e.clientX - rect.left, y: e.clientY - rect.top });
    if (!refineMode || !isPainting.current) return;
    e.preventDefault();
    paintAtMask(...pointerToMaskCoords(e));
  }
  function onPointerUp(e: React.PointerEvent<HTMLCanvasElement>) {
    isPainting.current = false;
    e.currentTarget.releasePointerCapture(e.pointerId);
  }
  function onPointerLeave() {
    isPainting.current = false;
    setCursor(c => ({ ...c, visible: false }));
  }

  // ── Undo ─────────────────────────────────────────────────────────────────────

  function undo() {
    setUndoStack(prev => {
      const [last, ...rest] = prev;
      if (!last) return prev;
      alphaMaskRef.current = last;
      doRender();
      return rest;
    });
  }

  // ── Download ──────────────────────────────────────────────────────────────────

  function download() {
    const orig  = origCanvasRef.current;
    const alpha = alphaMaskRef.current;
    if (!orig || !alpha) return;
    const fmt  = FORMAT_OPTIONS.find(f => f.ext === exportFmt)!;
    const matte = matteCleanup ? edgeStrength / 100 * 0.4 : 0;
    const composed = compositeToCanvas(orig, alpha, bgColor, orig.width, orig.height, matte);
    const a = document.createElement('a');
    a.href = composed.toDataURL(fmt.mime, fmt.quality);
    a.download = `axio7-portrait.${fmt.ext}`;
    a.click();
  }

  // ── Derived ───────────────────────────────────────────────────────────────────

  const busy       = status === 'uploading';
  const hasWarning = warnings.some(w => w.includes('residue') || w.includes('transparent'));
  const allProviders = PROVIDER_DEFS.map(p => ({
    ...p,
    available: p.id === 'auto'
      ? (configuredProviders.length > 0 || true)  // always show auto
      : configuredProviders.includes(p.id) || configuredProviders.length === 0, // show as available before first call
  }));

  // ── Render ────────────────────────────────────────────────────────────────────

  return (
    <div className="rounded-[22px] p-5 space-y-4" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>

      {/* Header */}
      <div>
        <h2 className="text-lg font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>Portrait Background</h2>
        <p className="mt-0.5 text-sm" style={{ color: 'var(--lt-muted)' }}>
          Replace a portrait background with a solid color. Professional AI — not stored.
        </p>
      </div>

      {/* Model selector */}
      <div className="space-y-1.5">
        <span className="text-xs font-medium" style={{ color: 'var(--lt-muted)' }}>Model:</span>
        <div className="flex flex-wrap gap-2">
          {allProviders.map(p => {
            const isSelected = selectedProvider === p.id;
            const isRunning  = busy && usedProvider === p.id;
            return (
              <button
                key={p.id}
                onClick={() => switchProvider(p.id as ProviderId)}
                disabled={busy}
                title={p.description}
                className="inline-flex flex-col items-start rounded-xl px-3 py-2 text-left transition hover:opacity-90 disabled:opacity-60"
                style={isSelected
                  ? { background: 'var(--molt-shell)', color: 'white', minWidth: 90 }
                  : { background: 'rgba(0,0,0,0.05)', color: 'var(--lt-text)', minWidth: 90 }}
              >
                <span className="text-xs font-semibold flex items-center gap-1">
                  {p.name}
                  {isRunning && <Loader2 className="h-3 w-3 animate-spin" />}
                </span>
                <span className="text-[10px] mt-0.5" style={{ opacity: 0.7 }}>{p.tag}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Background color */}
      <div className="flex items-center gap-3 flex-wrap">
        <span className="text-xs font-medium" style={{ color: 'var(--lt-muted)' }}>Background:</span>
        {BG_OPTIONS.map(opt => (
          <button key={opt.value} onClick={() => setBgColor(opt.value)} title={opt.label}
            className="h-8 w-8 rounded-full transition hover:scale-110 active:scale-95"
            style={{ background: opt.value, outline: bgColor === opt.value ? '2.5px solid var(--molt-shell)' : '2px solid transparent', outlineOffset: '2px', border: opt.value === '#ffffff' ? '1px solid #e5e7eb' : 'none' }}
            aria-label={opt.label} />
        ))}
        <span className="text-xs" style={{ color: 'var(--lt-muted)' }}>{BG_OPTIONS.find(o => o.value === bgColor)?.label}</span>
      </div>

      {/* Upload zone */}
      <div
        onDrop={e => { e.preventDefault(); const f = e.dataTransfer.files?.[0]; if (f) processFile(f); }}
        onDragOver={e => e.preventDefault()}
        onClick={() => !busy && fileRef.current?.click()}
        className="flex flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed py-7 transition"
        style={{ borderColor: 'var(--lt-border)', color: 'var(--lt-muted)', cursor: busy ? 'default' : 'pointer' }}
      >
        {busy ? (
          <>
            <Loader2 className="h-7 w-7 animate-spin" style={{ color: 'var(--molt-shell)' }} />
            <p className="text-sm font-medium" style={{ color: 'var(--molt-shell)' }}>{stage || 'Processing…'}</p>
          </>
        ) : (
          <>
            <Upload className="h-6 w-6" />
            <p className="text-sm font-medium">{status === 'done' ? 'Upload another photo' : 'Click or drag portrait photo here'}</p>
            <p className="text-xs">JPG, PNG, WebP · Max 12 MB</p>
          </>
        )}
        <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp,image/*" className="sr-only"
          onChange={e => { const f = e.target.files?.[0]; if (f) processFile(f); e.target.value = ''; }}
          disabled={busy} />
      </div>

      {/* Error */}
      {errorMsg && (
        <div className="rounded-xl px-4 py-3 text-sm" style={{ background: 'rgba(220,38,38,0.07)', border: '1px solid rgba(220,38,38,0.2)', color: '#dc2626' }}>
          {errorMsg}
        </div>
      )}

      {/* Quality warning */}
      {status === 'done' && hasWarning && (
        <div className="rounded-xl px-4 py-3 space-y-2" style={{ background: 'rgba(251,191,36,0.1)', border: '1px solid rgba(251,191,36,0.3)', color: '#92400e' }}>
          <p className="text-sm font-semibold">⚠️ Complex background detected</p>
          <p className="text-xs">Try a different model above, or use Auto polish / Refine edges below.</p>
          <button onClick={tryHigherQuality} disabled={busy}
            className="rounded-lg px-3 py-1.5 text-xs font-semibold transition hover:opacity-90 disabled:opacity-50"
            style={{ background: '#d97706', color: 'white' }}>
            🔄 Try higher quality
          </button>
        </div>
      )}

      {/* Provider + quality info */}
      {status === 'done' && usedProvider && (
        <div className="flex items-center justify-between text-xs" style={{ color: 'var(--lt-muted)' }}>
          <span>
            Processed by: <b style={{ color: 'var(--lt-text)' }}>{usedProvider}</b>
            {qualityScore !== null && (
              <span className="ml-2" style={{ color: qualityScore > 0.7 ? '#059669' : qualityScore > 0.5 ? '#d97706' : '#dc2626' }}>
                · Quality: {(qualityScore * 100).toFixed(0)}%
              </span>
            )}
          </span>
          {!hasWarning && (
            <button onClick={tryHigherQuality} disabled={busy}
              className="rounded-lg px-2.5 py-1 text-xs font-medium transition hover:opacity-80 disabled:opacity-50"
              style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}>
              Try Auto Best
            </button>
          )}
        </div>
      )}

      {/* Before / After */}
      {status === 'done' && (
        <>
          <div className="grid grid-cols-2 gap-3">
            {/* Original */}
            <div className="space-y-1.5">
              <p className="text-[11px] font-semibold text-center uppercase tracking-wider" style={{ color: 'var(--lt-muted)' }}>Original</p>
              <div className="flex justify-center">
                <div className="overflow-hidden rounded-xl" style={{ border: '1px solid var(--lt-border)' }}>
                  {origUrl.current && (
                    <img src={origUrl.current} alt="Original"
                      style={{ display: 'block', width: 'auto', maxWidth: '100%', maxHeight: 420, objectFit: 'contain' }} />
                  )}
                </div>
              </div>
            </div>

            {/* Result */}
            <div className="space-y-1.5">
              <p className="text-[11px] font-semibold text-center uppercase tracking-wider" style={{ color: 'var(--lt-muted)' }}>
                {refineMode ? (brushMode === 'erase' ? '🧹 Erasing' : '✏️ Restoring') : 'Result'}
              </p>
              <div className="flex justify-center">
                <div
                  ref={previewWrapRef}
                  className="overflow-hidden rounded-xl"
                  style={{ position: 'relative', border: refineMode ? '2px solid var(--molt-shell)' : '1px solid var(--lt-border)', background: bgColor }}
                >
                  <canvas
                    ref={previewRef}
                    style={{ display: 'block', width: 'auto', maxWidth: '100%', maxHeight: 420, objectFit: 'contain', cursor: refineMode ? 'none' : 'default', touchAction: 'none' }}
                    onPointerDown={onPointerDown}
                    onPointerMove={onPointerMove}
                    onPointerUp={onPointerUp}
                    onPointerLeave={onPointerLeave}
                  />
                  {refineMode && cursor.visible && (
                    <div className="pointer-events-none absolute rounded-full"
                      style={{
                        width: brushSize, height: brushSize,
                        left: cursor.x - brushSize/2, top: cursor.y - brushSize/2,
                        border: `2px solid ${brushMode === 'erase' ? '#dc2626' : '#059669'}`,
                        background: brushMode === 'erase' ? 'rgba(220,38,38,0.10)' : 'rgba(5,150,105,0.10)',
                        boxShadow: '0 0 0 1px rgba(255,255,255,0.8)',
                      }} />
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Edge Refinement toolbar */}
          <div className="rounded-xl p-4 space-y-3" style={{ background: 'rgba(0,0,0,0.04)', border: '1px solid var(--lt-border)' }}>
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold" style={{ color: 'var(--lt-text)' }}>Edge Refinement</span>
              <button
                onClick={() => { setRefineMode(v => !v); setCursor(c => ({ ...c, visible: false })); }}
                className="rounded-lg px-3 py-1.5 text-xs font-semibold transition hover:opacity-90"
                style={refineMode ? { background: 'rgba(0,0,0,0.08)', color: 'var(--lt-text)' } : { background: 'var(--molt-shell)', color: 'white' }}>
                {refineMode ? 'Done' : '✏️ Refine edges'}
              </button>
            </div>

            {/* Auto polish — always visible in refinement area */}
            <div className="rounded-lg p-3 space-y-2.5" style={{ background: 'rgba(124,58,237,0.06)', border: '1px solid rgba(124,58,237,0.18)' }}>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs font-semibold" style={{ color: '#7c3aed' }}>
                    <Sparkles className="inline h-3.5 w-3.5 mr-1" />Auto polish edges
                  </p>
                  <p className="text-[11px]" style={{ color: 'var(--lt-muted)' }}>Cleans small halos and jagged edges without changing the person.</p>
                </div>
                <button onClick={autoPolish} disabled={polishing || busy}
                  className="ml-3 flex-shrink-0 rounded-lg px-3 py-1.5 text-xs font-semibold transition hover:opacity-90 disabled:opacity-50"
                  style={{ background: '#7c3aed', color: 'white' }}>
                  {polishing ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : 'Polish'}
                </button>
              </div>

              <div className="flex items-center gap-3">
                <span className="text-xs w-24 flex-shrink-0" style={{ color: 'var(--lt-muted)' }}>Edge strength: {edgeStrength}</span>
                <input type="range" min={0} max={100} value={edgeStrength} onChange={e => setEdgeStrength(Number(e.target.value))}
                  className="flex-1" style={{ accentColor: '#7c3aed' }} />
              </div>

              <div className="flex flex-wrap gap-3 text-xs">
                <label className="flex items-center gap-1.5 cursor-pointer" style={{ color: 'var(--lt-muted)' }}>
                  <input type="checkbox" checked={removeHalo} onChange={e => setRemoveHalo(e.target.checked)} style={{ accentColor: '#7c3aed' }} />
                  Remove halo
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer" style={{ color: 'var(--lt-muted)' }}>
                  <input type="checkbox" checked={preserveHair} onChange={e => setPreserveHair(e.target.checked)} style={{ accentColor: '#7c3aed' }} />
                  Preserve hair detail
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer" style={{ color: 'var(--lt-muted)' }}>
                  <input type="checkbox" checked={matteCleanup} onChange={e => setMatteCleanup(e.target.checked)} style={{ accentColor: '#7c3aed' }} />
                  Matte cleanup
                </label>
              </div>
            </div>

            {refineMode && (
              <>
                <div className="flex gap-2">
                  <button onClick={() => setBrushMode('erase')} className="flex-1 rounded-lg py-2.5 text-xs font-semibold transition"
                    style={brushMode === 'erase' ? { background: '#dc2626', color: 'white' } : { background: 'rgba(220,38,38,0.08)', color: '#dc2626' }}>
                    🧹 Erase residue
                  </button>
                  <button onClick={() => setBrushMode('restore')} className="flex-1 rounded-lg py-2.5 text-xs font-semibold transition"
                    style={brushMode === 'restore' ? { background: '#059669', color: 'white' } : { background: 'rgba(5,150,105,0.08)', color: '#059669' }}>
                    ✏️ Restore person
                  </button>
                </div>

                <div className="space-y-2">
                  <div className="flex items-center gap-3">
                    <span className="text-xs w-20 flex-shrink-0" style={{ color: 'var(--lt-muted)' }}>Size: {brushSize}px</span>
                    <input type="range" min={2} max={120} value={brushSize} onChange={e => setBrushSize(Number(e.target.value))}
                      className="flex-1" style={{ accentColor: 'var(--molt-shell)' }} />
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs w-20 flex-shrink-0" style={{ color: 'var(--lt-muted)' }}>Softness: {brushSoft}%</span>
                    <input type="range" min={0} max={100} value={brushSoft} onChange={e => setBrushSoft(Number(e.target.value))}
                      className="flex-1" style={{ accentColor: 'var(--molt-shell)' }} />
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <button onClick={undo} disabled={undoStack.length === 0}
                    className="inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium transition disabled:opacity-40 hover:opacity-80"
                    style={{ background: 'rgba(0,0,0,0.07)', color: 'var(--lt-text)' }}>
                    <Undo2 className="h-3.5 w-3.5" /> Undo last stroke
                  </button>
                  {undoStack.length > 0 && (
                    <span className="text-[11px]" style={{ color: 'var(--lt-subtle)' }}>{undoStack.length} step{undoStack.length !== 1 ? 's' : ''}</span>
                  )}
                </div>

                <p className="text-[11px]" style={{ color: 'var(--lt-muted)' }}>
                  Move cursor over Result to see brush. <b>Erase</b> removes residue; <b>Restore</b> recovers cut edges.
                </p>
              </>
            )}
          </div>

          {/* Format + download */}
          <div className="flex items-center gap-2">
            <span className="text-xs font-medium flex-shrink-0" style={{ color: 'var(--lt-muted)' }}>Format:</span>
            <div className="flex gap-1.5">
              {FORMAT_OPTIONS.map(f => (
                <button key={f.ext} onClick={() => setExportFmt(f.ext as ExportFmt)}
                  className="rounded-lg px-3 py-1.5 text-xs font-semibold transition"
                  style={exportFmt === f.ext ? { background: 'var(--molt-shell)', color: 'white' } : { background: 'rgba(0,0,0,0.06)', color: 'var(--lt-muted)' }}>
                  {f.label}
                </button>
              ))}
            </div>
          </div>

          <button onClick={download}
            className="flex w-full items-center justify-center gap-2 rounded-xl py-3 text-sm font-semibold text-white transition hover:opacity-90 active:scale-[0.98]"
            style={{ background: 'var(--molt-shell)' }}>
            <Download className="h-4 w-4" />
            Download {FORMAT_OPTIONS.find(f => f.ext === exportFmt)?.label} (full resolution)
          </button>

          <p className="text-[11px] text-center" style={{ color: 'var(--lt-subtle)' }}>
            For official documents, review carefully. AXIO7 does not guarantee government approval.
          </p>
        </>
      )}
    </div>
  );
}
