export function LightPage({ children }: { children: React.ReactNode }) {
  return (
    <div className="education-page-shell">
      <div className="education-page-paper" aria-hidden />
      <div className="relative z-10">{children}</div>
    </div>
  );
}
