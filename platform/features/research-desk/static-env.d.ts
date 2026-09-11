// The static overlay must typecheck without a generated Next.js build directory.
declare module '*.module.css' {
  const classes: Readonly<Record<string, string>>;
  export default classes;
}
