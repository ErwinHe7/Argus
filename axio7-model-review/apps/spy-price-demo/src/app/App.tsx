import type { JSX } from "react";
import { ReplayPage } from "../features/replay/ReplayPage/ReplayPage";
import type { ReplayLoaders } from "../features/replay/artifact/loadArtifact";

interface AppProps {
  loaders?: ReplayLoaders;
}

export function App({ loaders }: AppProps = {}): JSX.Element {
  return loaders === undefined ? <ReplayPage /> : <ReplayPage loaders={loaders} />;
}
