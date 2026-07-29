import type { DataProvider } from './provider';
import { MockProvider } from './mock/MockProvider';

/**
 * The one line that swaps the backend.
 * Replace with `new FirebaseProvider()` once the Realtime Database is live —
 * nothing else in the app changes.
 */
export const dataProvider: DataProvider = new MockProvider();

export type { DataProvider } from './provider';
