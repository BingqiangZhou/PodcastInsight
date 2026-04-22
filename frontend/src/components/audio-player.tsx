"use client";

import {
  Play,
  Pause,
  SkipBack,
  SkipForward,
  Volume2,
  Volume1,
  VolumeX,
  Loader2,
  PanelRightClose,
  ListMusic,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useAudioPlayer } from "@/hooks/use-audio-player";
import { useAudioStore } from "@/stores/audio-store";
import { formatTimeDisplay, cn } from "@/lib/utils";
import { useMemo, useState, useCallback, useEffect } from "react";

const SPEED_OPTIONS = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];

interface AudioPlayerProps {
  audioUrl: string;
  title: string;
  podcastName?: string;
  coverUrl?: string;
}

function VolumeIcon({ volume, isMuted }: { volume: number; isMuted: boolean }) {
  if (isMuted || volume === 0) return <VolumeX className="h-4 w-4" />;
  if (volume < 0.5) return <Volume1 className="h-4 w-4" />;
  return <Volume2 className="h-4 w-4" />;
}

function CoverArt({
  coverUrl,
  isPlaying,
}: {
  coverUrl?: string;
  isPlaying: boolean;
}) {
  return (
    <div className="relative shrink-0">
      {/* Glow behind cover */}
      {isPlaying && coverUrl && (
        <div
          className="absolute inset-2 rounded-3xl blur-2xl opacity-40 transition-opacity duration-700"
          style={{ background: "var(--player-accent)" }}
        />
      )}
      <div className="relative h-44 w-44 overflow-hidden rounded-3xl shadow-2xl ring-1 ring-white/5">
        {coverUrl ? (
          <img
            src={coverUrl}
            alt="Cover"
            className={cn(
              "h-full w-full object-cover transition-transform duration-700",
              isPlaying && "scale-110"
            )}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-player-accent/40 via-player-accent/20 to-transparent">
            <ListMusic className="h-14 w-14 text-player-accent/60" />
          </div>
        )}
        {/* Equalizer overlay */}
        {isPlaying && (
          <div className="absolute inset-0 flex items-end justify-center pb-4 bg-gradient-to-t from-black/40 to-transparent">
            <div className="flex items-end gap-[3px]">
              {[0, 0.2, 0.4].map((delay, i) => (
                <span
                  key={i}
                  className="w-[3px] rounded-full bg-white/90"
                  style={{
                    height: 12,
                    animation: `equalizer-${i + 1} 0.6s ease-in-out ${delay}s infinite`,
                  }}
                />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export function AudioPlayer({ audioUrl, title, podcastName, coverUrl }: AudioPlayerProps) {
  const { audioRef, togglePlay, skip, changeRate, changeVolume, toggleMute } = useAudioPlayer(audioUrl);

  const isPlaying = useAudioStore((s) => s.isPlaying);
  const currentTime = useAudioStore((s) => s.currentTime);
  const duration = useAudioStore((s) => s.duration);
  const buffered = useAudioStore((s) => s.buffered);
  const playbackRate = useAudioStore((s) => s.playbackRate);
  const volume = useAudioStore((s) => s.volume);
  const isMuted = useAudioStore((s) => s.isMuted);
  const isLoading = useAudioStore((s) => s.isLoading);

  const [isOpen, setIsOpen] = useState(false);
  const [tooltipVisible, setTooltipVisible] = useState(false);
  const [tooltipPct, setTooltipPct] = useState(0);
  const [tooltipTime, setTooltipTime] = useState("");

  const playedPct = duration > 0 ? (currentTime / duration) * 100 : 0;
  const bufferedPct = duration > 0 ? (buffered / duration) * 100 : 0;

  const seekTrackStyle = useMemo(
    () => ({
      background: `linear-gradient(to right,
        var(--player-accent) 0%, var(--player-accent) ${playedPct}%,
        var(--player-buffered) ${playedPct}%, var(--player-buffered) ${bufferedPct}%,
        var(--player-track) ${bufferedPct}%, var(--player-track) 100%)`,
    }),
    [playedPct, bufferedPct]
  );

  const volumePct = isMuted ? 0 : volume * 100;
  const volumeTrackStyle = useMemo(
    () => ({
      background: `linear-gradient(to right,
        var(--player-fg) 0%, var(--player-fg) ${volumePct}%,
        var(--player-track) ${volumePct}%, var(--player-track) 100%)`,
    }),
    [volumePct]
  );

  const handleProgressMouseMove = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      const rect = e.currentTarget.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const pct = Math.max(0, Math.min(1, x / rect.width));
      setTooltipPct(pct * 100);
      setTooltipTime(formatTimeDisplay(pct * duration));
      setTooltipVisible(true);
    },
    [duration]
  );

  const handleProgressMouseLeave = useCallback(() => setTooltipVisible(false), []);

  const handleSeek = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const t = parseFloat(e.target.value);
      if (audioRef.current) audioRef.current.currentTime = t;
    },
    [audioRef]
  );

  // Keyboard shortcuts
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && isOpen) {
        setIsOpen(false);
        return;
      }
      // Only handle shortcuts when player is open and no input is focused
      if (!isOpen) return;
      const tag = (e.target as HTMLElement).tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;

      switch (e.key) {
        case " ":
          e.preventDefault();
          togglePlay();
          break;
        case "ArrowLeft":
          e.preventDefault();
          skip(-5);
          break;
        case "ArrowRight":
          e.preventDefault();
          skip(5);
          break;
        case "ArrowUp":
          e.preventDefault();
          changeVolume(Math.min(1, volume + 0.1));
          break;
        case "ArrowDown":
          e.preventDefault();
          changeVolume(Math.max(0, volume - 0.1));
          break;
      }
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [isOpen, togglePlay, skip, changeVolume, volume]);

  if (!audioUrl) return null;

  return (
    <>
      <audio ref={audioRef} preload="metadata" className="hidden" />

      {/* Backdrop */}
      <div
        className={cn(
          "fixed inset-0 z-40 bg-black/40 backdrop-blur-sm transition-opacity duration-300",
          isOpen ? "opacity-100 pointer-events-auto" : "opacity-0 pointer-events-none"
        )}
        onClick={() => setIsOpen(false)}
      />

      {/* Floating toggle button */}
      {!isOpen && (
        <button
          onClick={() => setIsOpen(true)}
          className="fixed bottom-6 right-6 z-50 group"
          aria-label="打开播放器"
        >
          <span
            className="absolute inset-0 rounded-full opacity-30 group-hover:opacity-50 transition-opacity duration-300"
            style={{ background: "var(--player-accent)", filter: "blur(14px)" }}
          />
          <span
            className="relative flex h-13 w-13 items-center justify-center rounded-full transition-all duration-200 group-hover:scale-105 group-active:scale-95"
            style={{
              background: "var(--player-accent)",
              boxShadow: "0 4px 24px hsl(0 0% 0% / 0.3)",
              width: 52,
              height: 52,
            }}
          >
            {isLoading ? (
              <Loader2 className="h-5 w-5 text-white animate-spin" />
            ) : isPlaying ? (
              <Pause className="h-5 w-5 text-white" />
            ) : (
              <Play className="h-5 w-5 text-white translate-x-[1px]" />
            )}
          </span>
          {/* Mini progress ring on FAB */}
          {duration > 0 && (
            <svg
              className="absolute inset-0 -rotate-90"
              width={52}
              height={52}
              viewBox="0 0 52 52"
            >
              <circle
                cx="26" cy="26" r="24"
                fill="none"
                stroke="rgba(255,255,255,0.15)"
                strokeWidth="2"
              />
              <circle
                cx="26" cy="26" r="24"
                fill="none"
                stroke="rgba(255,255,255,0.8)"
                strokeWidth="2"
                strokeLinecap="round"
                strokeDasharray={`${2 * Math.PI * 24}`}
                strokeDashoffset={`${2 * Math.PI * 24 * (1 - playedPct / 100)}`}
                className="transition-[stroke-dashoffset] duration-300"
              />
            </svg>
          )}
        </button>
      )}

      {/* Right-side drawer panel */}
      <div
        className={cn(
          "fixed top-0 right-0 z-50 h-full w-[340px] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]",
          isOpen ? "translate-x-0" : "translate-x-full"
        )}
        style={{
          background: "linear-gradient(180deg, var(--player-bg) 0%, color-mix(in srgb, var(--player-bg) 95%, var(--player-accent)) 100%)",
          borderLeft: "1px solid var(--player-track)",
        }}
      >
        {/* Header bar */}
        <div className="flex items-center justify-between px-5 py-3.5" style={{ borderBottom: "1px solid var(--player-track)" }}>
          <div className="flex items-center gap-2">
            <span
              className={cn(
                "h-2 w-2 rounded-full transition-colors duration-300",
                isPlaying ? "bg-green-400" : "bg-player-muted"
              )}
              style={isPlaying ? { boxShadow: "0 0 6px rgba(74, 222, 128, 0.5)" } : undefined}
            />
            <span className="text-[11px] font-semibold tracking-widest uppercase text-player-fg/40">
              {isPlaying ? "正在播放" : "播放器"}
            </span>
          </div>
          <button
            className="flex h-7 w-7 items-center justify-center rounded-full text-player-muted/60 transition-colors hover:bg-white/10 hover:text-player-fg"
            onClick={() => setIsOpen(false)}
            aria-label="收起播放器"
          >
            <PanelRightClose className="h-4 w-4" />
          </button>
        </div>

        {/* Cover art + track info */}
        <div className="flex flex-col items-center px-6 pt-8 pb-4">
          <CoverArt coverUrl={coverUrl} isPlaying={isPlaying} />
          <div className="mt-6 w-full text-center">
            <p className="text-sm font-semibold text-player-fg leading-snug line-clamp-2">
              {title}
            </p>
            {podcastName && (
              <p className="mt-1 text-xs text-player-muted">
                {podcastName}
              </p>
            )}
          </div>
        </div>

        {/* Progress section */}
        <div className="relative px-6">
          <div
            className="relative"
            onMouseMove={handleProgressMouseMove}
            onMouseLeave={handleProgressMouseLeave}
          >
            <input
              type="range"
              className="audio-slider"
              min={0}
              max={duration || 0}
              step={0.1}
              value={currentTime}
              onChange={handleSeek}
              style={seekTrackStyle}
              aria-label="播放进度"
            />
            <div className="mt-1.5 flex items-center justify-between">
              <span className="text-[11px] font-mono tabular-nums text-player-muted/70">
                {formatTimeDisplay(currentTime)}
              </span>
              <span className="text-[11px] font-mono tabular-nums text-player-muted/70">
                -{formatTimeDisplay(Math.max(0, duration - currentTime))}
              </span>
            </div>
          </div>
          {/* Tooltip */}
          {tooltipVisible && (
            <div
              className="progress-tooltip visible"
              style={{ left: `${tooltipPct}%` }}
            >
              {tooltipTime}
            </div>
          )}
        </div>

        {/* Transport controls */}
        <div className="flex items-center justify-center gap-5 px-6 py-5">
          <button
            className="flex h-9 w-9 items-center justify-center rounded-full text-player-muted transition-all hover:bg-white/10 hover:text-player-fg active:scale-90"
            onClick={() => skip(-15)}
            aria-label="后退15秒"
          >
            <div className="relative">
              <SkipBack className="h-5 w-5" />
            </div>
          </button>

          <button
            className="flex h-9 w-9 items-center justify-center rounded-full text-player-muted transition-all hover:bg-white/10 hover:text-player-fg active:scale-90"
            onClick={() => skip(-5)}
            aria-label="后退5秒"
          >
            <Rewind5 />
          </button>

          {/* Main play/pause button */}
          <button
            className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full transition-all duration-200 active:scale-90"
            style={{
              background: "var(--player-accent)",
              color: "var(--player-bg)",
              boxShadow: "0 0 0 4px hsl(0 0% 100% / 0.06), 0 8px 32px hsl(0 0% 0% / 0.4)",
            }}
            onClick={togglePlay}
            disabled={isLoading}
            aria-label={isPlaying ? "暂停" : "播放"}
          >
            {isLoading ? (
              <Loader2 className="h-6 w-6 animate-spin" />
            ) : isPlaying ? (
              <Pause className="h-7 w-7" />
            ) : (
              <Play className="h-7 w-7 translate-x-[2px]" />
            )}
          </button>

          <button
            className="flex h-9 w-9 items-center justify-center rounded-full text-player-muted transition-all hover:bg-white/10 hover:text-player-fg active:scale-90"
            onClick={() => skip(5)}
            aria-label="快进5秒"
          >
            <Forward5 />
          </button>

          <button
            className="flex h-9 w-9 items-center justify-center rounded-full text-player-muted transition-all hover:bg-white/10 hover:text-player-fg active:scale-90"
            onClick={() => skip(15)}
            aria-label="快进15秒"
          >
            <SkipForward className="h-5 w-5" />
          </button>
        </div>

        {/* Speed + Volume row */}
        <div className="mx-6 rounded-xl p-4 space-y-4" style={{ background: "var(--player-track)" }}>
          {/* Speed */}
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-medium text-player-muted uppercase tracking-wide">
              播放速度
            </span>
            <div className="flex gap-1">
              {SPEED_OPTIONS.filter((r) => [1, 1.25, 1.5, 2].includes(r)).map((rate) => (
                <button
                  key={rate}
                  className={cn(
                    "h-6 min-w-[32px] rounded-md px-1.5 text-[11px] font-semibold transition-all",
                    playbackRate === rate
                      ? "bg-player-accent text-white shadow-sm"
                      : "text-player-muted hover:text-player-fg hover:bg-white/5"
                  )}
                  onClick={() => changeRate(rate)}
                >
                  {rate}x
                </button>
              ))}
              <Select value={String(playbackRate)} onValueChange={(v) => changeRate(parseFloat(v))}>
                <SelectTrigger
                  className="h-6 w-[36px] border-none p-0 text-[11px] font-semibold hover:bg-white/5"
                  style={{ background: "transparent", color: "var(--player-muted)" }}
                >
                  <span className="sr-only">更多速度</span>
                  <span className="text-player-muted">...</span>
                </SelectTrigger>
                <SelectContent>
                  {SPEED_OPTIONS.map((rate) => (
                    <SelectItem key={rate} value={String(rate)}>
                      {rate}x
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Volume */}
          <div className="flex items-center gap-3">
            <button
              className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-player-muted transition-colors hover:bg-white/10 hover:text-player-fg"
              onClick={toggleMute}
              aria-label={isMuted ? "取消静音" : "静音"}
            >
              <VolumeIcon volume={volume} isMuted={isMuted} />
            </button>
            <input
              type="range"
              className="audio-slider flex-1"
              min={0}
              max={1}
              step={0.01}
              value={isMuted ? 0 : volume}
              onChange={(e) => changeVolume(parseFloat(e.target.value))}
              style={volumeTrackStyle}
              aria-label="音量"
            />
            <span className="min-w-[28px] text-right text-[10px] font-mono tabular-nums text-player-muted/60">
              {Math.round(volumePct)}%
            </span>
          </div>
        </div>

        {/* Keyboard shortcuts hint */}
        <div className="mt-auto px-6 py-4">
          <div className="flex flex-wrap justify-center gap-x-3 gap-y-1">
            {[
              ["Space", "播放"],
              ["← →", "快退/快进"],
              ["↑ ↓", "音量"],
              ["Esc", "收起"],
            ].map(([key, label]) => (
              <span key={key} className="text-[10px] text-player-muted/30">
                <kbd className="rounded bg-white/5 px-1 py-0.5 text-player-muted/50 font-mono">{key}</kbd>
                {" "}{label}
              </span>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}

/* ===== Custom skip icons with "5" label ===== */

function Rewind5() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M1 4v6h6" />
      <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" />
      <text x="13" y="16" fontSize="8" fontWeight="bold" fill="currentColor" stroke="none" textAnchor="middle">5</text>
    </svg>
  );
}

function Forward5() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="m23 4-6 6H1" />
      <path d="m23 10-6 6H1" transform="scale(-1,1) translate(-24,0)" style={{ transform: "scaleX(-1) translateX(-24px)" }} />
      <path d="M23 4v6h-6" />
      <path d="M20.49 15a9 9 0 1 1-2.13-9.36L23 10" />
      <text x="11" y="16" fontSize="8" fontWeight="bold" fill="currentColor" stroke="none" textAnchor="middle">5</text>
    </svg>
  );
}
