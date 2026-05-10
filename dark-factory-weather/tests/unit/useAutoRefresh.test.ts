import { renderHook, act } from '@testing-library/react-hooks';
import { useAutoRefresh } from '../../src/webparts/darkFactoryWeather/hooks/useAutoRefresh';

describe('useAutoRefresh', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('calls onRefresh on mount', async () => {
    const onRefresh = jest.fn().mockResolvedValue(undefined);

    renderHook(() => useAutoRefresh(onRefresh, 5000));

    await act(async () => {
      await Promise.resolve();
    });

    expect(onRefresh).toHaveBeenCalledTimes(1);
  });

  it('calls onRefresh after each interval', async () => {
    const onRefresh = jest.fn().mockResolvedValue(undefined);

    renderHook(() => useAutoRefresh(onRefresh, 5000));

    await act(async () => {
      await Promise.resolve();
    });

    expect(onRefresh).toHaveBeenCalledTimes(1);

    await act(async () => {
      jest.advanceTimersByTime(5000);
      await Promise.resolve();
    });

    expect(onRefresh).toHaveBeenCalledTimes(2);
  });

  it('clears interval when tab becomes hidden', async () => {
    const onRefresh = jest.fn().mockResolvedValue(undefined);

    renderHook(() => useAutoRefresh(onRefresh, 5000));

    await act(async () => {
      await Promise.resolve();
    });

    const callCount = onRefresh.mock.calls.length;

    // Simulate tab hidden
    Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));

    await act(async () => {
      jest.advanceTimersByTime(10000);
      await Promise.resolve();
    });

    // Should not have called onRefresh again after hidden
    expect(onRefresh).toHaveBeenCalledTimes(callCount);
  });

  it('calls onRefresh immediately when tab becomes visible again', async () => {
    const onRefresh = jest.fn().mockResolvedValue(undefined);

    renderHook(() => useAutoRefresh(onRefresh, 5000));

    await act(async () => {
      await Promise.resolve();
    });

    // Hide tab
    Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));

    const callCountAfterHide = onRefresh.mock.calls.length;

    // Show tab again
    Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));

    await act(async () => {
      await Promise.resolve();
    });

    expect(onRefresh).toHaveBeenCalledTimes(callCountAfterHide + 1);
  });

  it('clears interval and removes listener on unmount', async () => {
    const onRefresh = jest.fn().mockResolvedValue(undefined);
    const removeEventListenerSpy = jest.spyOn(document, 'removeEventListener');

    const { unmount } = renderHook(() => useAutoRefresh(onRefresh, 5000));

    await act(async () => {
      await Promise.resolve();
    });

    unmount();

    expect(removeEventListenerSpy).toHaveBeenCalledWith('visibilitychange', expect.any(Function));

    const callCountAfterUnmount = onRefresh.mock.calls.length;

    await act(async () => {
      jest.advanceTimersByTime(10000);
      await Promise.resolve();
    });

    // No more calls after unmount
    expect(onRefresh).toHaveBeenCalledTimes(callCountAfterUnmount);

    removeEventListenerSpy.mockRestore();
  });
});
