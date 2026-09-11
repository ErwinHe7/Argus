export const NOTEBOOK_KEY = 'leo.iv-lab.notebook.v1';
export type ResearchNote = {
  id: string; savedAt: string; symbol: string; artifactGeneratedAt: string;
  configurationId: string; elapsedDays: number; spotMovePercent: number; ivShiftPp: number;
  thesis: string; invalidate: string; result: string;
};
export function parseNotebook(raw: string | null): ResearchNote[] {
  if (!raw) return [];
  try {
    const value: unknown = JSON.parse(raw);
    if (!Array.isArray(value)) return [];
    return value.filter((item): item is ResearchNote => {
      if (!item || typeof item !== 'object') return false;
      return ['id', 'savedAt', 'symbol', 'artifactGeneratedAt', 'configurationId', 'thesis', 'invalidate', 'result'].every((key) => typeof item[key] === 'string')
        && ['elapsedDays', 'spotMovePercent', 'ivShiftPp'].every((key) => Number.isFinite(item[key]));
    }).slice(0, 100);
  } catch { return []; }
}
export function downloadResearch(filename: string, value: unknown) {
  const blob = new Blob([JSON.stringify(value, null, 2)], { type: 'application/json;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url; anchor.download = filename; anchor.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
