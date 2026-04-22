"use client";

import { useState, useRef, useEffect, useCallback, useMemo } from "react";
import { ChevronDown, ChevronUp } from "lucide-react";
import { Button } from "@/components/ui/button";

interface ExpandableDescriptionProps {
  content: string;
  maxLines?: number;
}

function stripHtmlTags(html: string): string {
  return html.replace(/<[^>]*>/g, "").trim();
}

function isHtmlContent(text: string): boolean {
  return /<[a-zA-Z][^>]*>/.test(text);
}

export function ExpandableDescription({
  content,
  maxLines = 4,
}: ExpandableDescriptionProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [hasOverflow, setHasOverflow] = useState(false);
  const textRef = useRef<HTMLDivElement>(null);

  const isHtml = useMemo(() => isHtmlContent(content), [content]);
  const plainText = useMemo(() => stripHtmlTags(content), [content]);

  const checkOverflow = useCallback(() => {
    const el = textRef.current;
    if (!el) return;
    setHasOverflow(el.scrollHeight > el.clientHeight + 4);
  }, []);

  useEffect(() => {
    checkOverflow();
    window.addEventListener("resize", checkOverflow);
    return () => window.removeEventListener("resize", checkOverflow);
  }, [checkOverflow, content, isExpanded]);

  const lineH = 1.75;
  const collapsedMaxHeight = `${maxLines * lineH * 16}px`;

  return (
    <div className="group/shownotes">
      <div
        ref={textRef}
        className="relative overflow-hidden transition-[max-height] duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]"
        style={{ maxHeight: isExpanded ? "none" : collapsedMaxHeight }}
      >
        {isHtml ? (
          <div
            className="shownotes-content"
            dangerouslySetInnerHTML={{ __html: content }}
          />
        ) : (
          <p className="text-[0.9375rem] leading-[1.75] text-foreground whitespace-pre-wrap">
            {content}
          </p>
        )}

        {!isExpanded && hasOverflow && (
          <div
            className="pointer-events-none absolute right-0 bottom-0 left-0 h-12"
            style={{
              background: `linear-gradient(to bottom, transparent, var(--card))`,
            }}
          />
        )}
      </div>

      {hasOverflow && (
        <Button
          variant="ghost"
          size="sm"
          className="mt-2 h-auto px-0 font-body text-xs tracking-wide text-muted-foreground transition-colors hover:text-primary"
          onClick={() => setIsExpanded(!isExpanded)}
        >
          {isExpanded ? (
            <>
              收起内容 <ChevronUp className="ml-0.5 h-3 w-3" />
            </>
          ) : (
            <>
              展开全文 <ChevronDown className="ml-0.5 h-3 w-3" />
            </>
          )}
        </Button>
      )}
    </div>
  );
}
