import { useEffect, useRef } from 'react';

export function useAutoRefresh(onRefresh: () => Promise<void>, intervalMs: number): void {
  const onRefreshRef = useRef(onRefresh);
  onRefreshRef.current = onRefresh;

  useEffect(() => {
    let intervalId: ReturnType<typeof setInterval> | null = null;

    const startInterval = (): void => {
      intervalId = setInterval(() => {
        void onRefreshRef.current();
      }, intervalMs);
    };

    const clearCurrentInterval = (): void => {
      if (intervalId !== null) {
        clearInterval(intervalId);
        intervalId = null;
      }
    };

    const handleVisibilityChange = (): void => {
      if (document.visibilityState === 'hidden') {
        clearCurrentInterval();
      } else {
        void onRefreshRef.current();
        startInterval();
      }
    };

    void onRefreshRef.current();
    startInterval();

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      clearCurrentInterval();
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [intervalMs]);
}
