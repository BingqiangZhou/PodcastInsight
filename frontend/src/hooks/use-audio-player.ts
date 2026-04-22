"use client";

import { useRef, useEffect, useCallback } from "react";
import { useAudioStore } from "@/stores/audio-store";

export function useAudioPlayer(audioUrl: string) {
  const audioRef = useRef<HTMLAudioElement>(null);
  const rafRef = useRef<number>(0);

  const store = useAudioStore;

  const updateCurrentTime = useCallback(() => {
    const audio = audioRef.current;
    if (audio) {
      store.getState().setCurrentTime(audio.currentTime);
    }
    if (store.getState().isPlaying) {
      rafRef.current = requestAnimationFrame(updateCurrentTime);
    }
  }, [store]);

  const togglePlay = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    if (audio.paused) {
      audio.play().catch(() => {});
    } else {
      audio.pause();
    }
  }, []);

  const skip = useCallback((seconds: number) => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.currentTime = Math.max(
      0,
      Math.min(audio.currentTime + seconds, audio.duration || 0)
    );
  }, []);

  const changeRate = useCallback((rate: number) => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.playbackRate = rate;
    store.getState().setPlaybackRate(rate);
  }, [store]);

  const changeVolume = useCallback((vol: number) => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.volume = vol;
    store.getState().setVolume(vol);
    if (vol > 0 && audio.muted) {
      audio.muted = false;
      store.getState().setMuted(false);
    }
  }, [store]);

  const toggleMute = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.muted = !audio.muted;
    store.getState().setMuted(audio.muted);
  }, [store]);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    audio.src = audioUrl;
    audio.preload = "metadata";
    store.getState().reset();

    const onLoadedMetadata = () => {
      store.getState().setDuration(audio.duration);
    };

    const onDurationChange = () => {
      store.getState().setDuration(audio.duration);
    };

    const onProgress = () => {
      if (audio.buffered.length > 0) {
        store
          .getState()
          .setBuffered(audio.buffered.end(audio.buffered.length - 1));
      }
    };

    const onPlay = () => {
      store.getState().setPlaying(true);
      rafRef.current = requestAnimationFrame(updateCurrentTime);
    };

    const onPause = () => {
      store.getState().setPlaying(false);
      cancelAnimationFrame(rafRef.current);
      store.getState().setCurrentTime(audio.currentTime);
    };

    const onWaiting = () => store.getState().setLoading(true);
    const onCanPlay = () => store.getState().setLoading(false);
    const onEnded = () => {
      store.getState().setPlaying(false);
      cancelAnimationFrame(rafRef.current);
    };

    audio.addEventListener("loadedmetadata", onLoadedMetadata);
    audio.addEventListener("durationchange", onDurationChange);
    audio.addEventListener("progress", onProgress);
    audio.addEventListener("play", onPlay);
    audio.addEventListener("pause", onPause);
    audio.addEventListener("waiting", onWaiting);
    audio.addEventListener("canplay", onCanPlay);
    audio.addEventListener("ended", onEnded);

    store.getState()._setOnSeekRequest((time: number) => {
      audio.currentTime = time;
      store.getState().setCurrentTime(time);
    });

    return () => {
      audio.removeEventListener("loadedmetadata", onLoadedMetadata);
      audio.removeEventListener("durationchange", onDurationChange);
      audio.removeEventListener("progress", onProgress);
      audio.removeEventListener("play", onPlay);
      audio.removeEventListener("pause", onPause);
      audio.removeEventListener("waiting", onWaiting);
      audio.removeEventListener("canplay", onCanPlay);
      audio.removeEventListener("ended", onEnded);
      cancelAnimationFrame(rafRef.current);
      store.getState()._setOnSeekRequest(null);
      audio.pause();
      audio.removeAttribute("src");
      audio.load();
    };
  }, [audioUrl, store, updateCurrentTime]);

  return {
    audioRef,
    togglePlay,
    skip,
    changeRate,
    changeVolume,
    toggleMute,
  };
}
