import { create } from "zustand";

interface AudioState {
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  buffered: number;
  playbackRate: number;
  volume: number;
  isMuted: boolean;
  isLoading: boolean;

  _onSeekRequest: ((time: number) => void) | null;
  _setOnSeekRequest: (cb: ((time: number) => void) | null) => void;

  seekTo: (time: number) => void;

  setPlaying: (playing: boolean) => void;
  setCurrentTime: (time: number) => void;
  setDuration: (duration: number) => void;
  setBuffered: (buffered: number) => void;
  setPlaybackRate: (rate: number) => void;
  setVolume: (volume: number) => void;
  setMuted: (muted: boolean) => void;
  setLoading: (loading: boolean) => void;
  reset: () => void;
}

const initialState = {
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  buffered: 0,
  playbackRate: 1,
  volume: 1,
  isMuted: false,
  isLoading: false,
  _onSeekRequest: null as ((time: number) => void) | null,
};

export const useAudioStore = create<AudioState>((set, get) => ({
  ...initialState,

  _setOnSeekRequest: (cb) => set({ _onSeekRequest: cb }),

  seekTo: (time) => {
    const onSeek = get()._onSeekRequest;
    if (onSeek) onSeek(time);
  },

  setPlaying: (playing) => set({ isPlaying: playing }),
  setCurrentTime: (time) => set({ currentTime: time }),
  setDuration: (duration) => set({ duration }),
  setBuffered: (buffered) => set({ buffered }),
  setPlaybackRate: (rate) => set({ playbackRate: rate }),
  setVolume: (volume) => set({ volume }),
  setMuted: (muted) => set({ isMuted: muted }),
  setLoading: (loading) => set({ isLoading: loading }),
  reset: () => set(initialState),
}));
