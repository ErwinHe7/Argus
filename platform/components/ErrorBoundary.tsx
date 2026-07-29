'use client';

import { Component, type ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}
interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  render() {
    if (this.state.error) {
      return (
        this.props.fallback ?? (
          <div className="mx-auto mt-8 max-w-lg rounded-xl border border-red-200 bg-red-50 p-5 text-sm text-red-800">
            <p className="font-semibold">Something went wrong</p>
            <p className="mt-1 font-mono text-xs opacity-70">{this.state.error.message}</p>
          </div>
        )
      );
    }
    return this.props.children;
  }
}
