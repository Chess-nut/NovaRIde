import clsx, { type ClassValue } from 'clsx';

/** Single class-name helper used across the app. */
export function cn(...inputs: ClassValue[]): string {
  return clsx(inputs);
}
