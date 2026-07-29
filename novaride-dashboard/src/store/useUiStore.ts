import { create } from 'zustand';

/** Selection and drawer state shared across screens (drawer lands in phase 3). */
interface UiState {
  selectedRiderId: string | null;
  focusRiderId: string | null;
  riderDrawerOpen: boolean;
  selectRider: (riderId: string | null) => void;
  focusRider: (riderId: string | null) => void;
  setRiderDrawerOpen: (open: boolean) => void;
}

export const useUiStore = create<UiState>((set) => ({
  selectedRiderId: null,
  focusRiderId: null,
  riderDrawerOpen: false,
  selectRider: (riderId) => set({ selectedRiderId: riderId, focusRiderId: riderId }),
  focusRider: (riderId) => set({ focusRiderId: riderId }),
  setRiderDrawerOpen: (open) => set({ riderDrawerOpen: open }),
}));
