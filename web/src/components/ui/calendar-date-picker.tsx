"use client";

import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import { createPortal } from "react-dom";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface CalendarDatePickerProps {
  id: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  maxDate?: Date;
}

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = Array.from({ length: 12 }, (_, month) =>
  new Intl.DateTimeFormat("en", { month: "long" }).format(new Date(2020, month, 1)),
);
const DISPLAY_FORMATTER = new Intl.DateTimeFormat("en", {
  day: "2-digit",
  month: "short",
  year: "numeric",
});

function parseDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const [year, month, day] = value.split("-").map(Number);
  const parsed = new Date(year, month - 1, day);
  return parsed.getFullYear() === year &&
    parsed.getMonth() === month - 1 &&
    parsed.getDate() === day
    ? parsed
    : null;
}

function toDateValue(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function isSameDay(first: Date | null, second: Date) {
  return Boolean(
    first &&
    first.getFullYear() === second.getFullYear() &&
    first.getMonth() === second.getMonth() &&
    first.getDate() === second.getDate(),
  );
}

function isAfter(first: Date, second: Date) {
  return startOfDay(first).getTime() > startOfDay(second).getTime();
}

export function CalendarDatePicker({
  id,
  value,
  onChange,
  placeholder = "Select date",
  maxDate = new Date(),
}: CalendarDatePickerProps) {
  const triggerRef = useRef<HTMLButtonElement>(null);
  const calendarRef = useRef<HTMLDivElement>(null);
  const selectedDate = parseDate(value);
  const [open, setOpen] = useState(false);
  const [isPositioned, setIsPositioned] = useState(false);
  const [viewMode, setViewMode] = useState<"days" | "months" | "years">("days");
  const [viewDate, setViewDate] = useState(() => selectedDate ?? new Date());
  const [yearPageStart, setYearPageStart] = useState(() => {
    const year = (selectedDate ?? new Date()).getFullYear();
    return year - (year % 12);
  });
  const [position, setPosition] = useState({ top: 0, left: 0, width: 336 });

  const updatePosition = useCallback(() => {
    const trigger = triggerRef.current;
    if (!trigger) return;

    const rect = trigger.getBoundingClientRect();
    const width = Math.min(336, window.innerWidth - 32);
    const left = Math.min(Math.max(16, rect.left), window.innerWidth - width - 16);
    const roomBelow = window.innerHeight - rect.bottom;
    const estimatedHeight = 350;
    const top =
      roomBelow >= estimatedHeight || rect.top < estimatedHeight
        ? rect.bottom + 8
        : rect.top - estimatedHeight - 8;
    setPosition({ top: Math.max(16, top), left, width });
  }, []);

  useEffect(() => {
    if (!open) {
      setIsPositioned(false);
      return;
    }

    updatePosition();
    setIsPositioned(true);
    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (!triggerRef.current?.contains(target) && !calendarRef.current?.contains(target)) {
        setOpen(false);
      }
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };

    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    window.addEventListener("resize", updatePosition);
    window.addEventListener("scroll", updatePosition, true);
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("resize", updatePosition);
      window.removeEventListener("scroll", updatePosition, true);
    };
  }, [open, updatePosition]);

  const days = useMemo(() => {
    const firstDay = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1);
    const start = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1 - firstDay.getDay());
    return Array.from({ length: 42 }, (_, index) => {
      const day = new Date(start);
      day.setDate(start.getDate() + index);
      return day;
    });
  }, [viewDate]);

  const selectDate = (date: Date) => {
    if (isAfter(date, maxDate)) return;
    onChange(toDateValue(date));
    setViewDate(date);
    setOpen(false);
  };

  const shiftMonth = (amount: number) => {
    setViewDate((current) => new Date(current.getFullYear(), current.getMonth() + amount, 1));
  };

  return (
    <>
      <button
        ref={triggerRef}
        id={id}
        type="button"
        className="border-border bg-background/88 text-foreground hover:border-primary/50 focus-visible:ring-primary/20 flex h-11 w-full items-center justify-between gap-3 rounded-xl border px-4 text-left text-sm shadow-none transition-colors focus-visible:ring-2 focus-visible:outline-none"
        aria-haspopup="dialog"
        aria-expanded={open}
        onClick={() => {
          setViewDate(selectedDate ?? new Date());
          setViewMode("days");
          setIsPositioned(false);
          setOpen((current) => !current);
        }}
      >
        <span className={cn(!selectedDate && "text-muted-foreground")}>
          {selectedDate ? DISPLAY_FORMATTER.format(selectedDate) : placeholder}
        </span>
        <CalendarDays className="text-muted-foreground size-4 shrink-0" aria-hidden="true" />
      </button>

      {open &&
        isPositioned &&
        typeof document !== "undefined" &&
        createPortal(
          <div
            ref={calendarRef}
            role="dialog"
            aria-label="Choose date of birth"
            className="border-border/70 bg-popover text-popover-foreground fixed z-110 rounded-2xl border p-4 shadow-(--shadow-popover) backdrop-blur-xl"
            style={{ top: position.top, left: position.left, width: position.width }}
          >
            <div className="mb-4 flex items-center justify-between gap-3">
              <div className="flex items-center gap-1">
                <button
                  type="button"
                  className={cn(
                    "text-foreground hover:bg-accent rounded-lg px-2 py-1.5 text-sm font-semibold transition-colors",
                    viewMode === "months" && "bg-accent",
                  )}
                  onClick={() => setViewMode(viewMode === "months" ? "days" : "months")}
                  aria-label="Choose month"
                  aria-pressed={viewMode === "months"}
                >
                  {MONTHS[viewDate.getMonth()]}
                </button>
                <button
                  type="button"
                  className={cn(
                    "text-foreground hover:bg-accent rounded-lg px-2 py-1.5 text-sm font-semibold transition-colors",
                    viewMode === "years" && "bg-accent",
                  )}
                  onClick={() => {
                    setYearPageStart(viewDate.getFullYear() - (viewDate.getFullYear() % 12));
                    setViewMode(viewMode === "years" ? "days" : "years");
                  }}
                  aria-label="Choose year"
                  aria-pressed={viewMode === "years"}
                >
                  {viewDate.getFullYear()}
                </button>
              </div>
              <div className="flex items-center gap-1">
                <Button
                  type="button"
                  size="icon"
                  variant="ghost"
                  className="size-8 rounded-lg"
                  onClick={() => {
                    if (viewMode === "months") {
                      setViewDate(
                        (current) => new Date(current.getFullYear() - 1, current.getMonth(), 1),
                      );
                    } else if (viewMode === "years") {
                      setYearPageStart((current) => current - 12);
                    } else {
                      shiftMonth(-1);
                    }
                  }}
                  aria-label={viewMode === "years" ? "Previous years" : "Previous month"}
                >
                  <ChevronLeft className="size-4" />
                </Button>
                <Button
                  type="button"
                  size="icon"
                  variant="ghost"
                  className="size-8 rounded-lg"
                  onClick={() => {
                    if (viewMode === "months") {
                      setViewDate(
                        (current) => new Date(current.getFullYear() + 1, current.getMonth(), 1),
                      );
                    } else if (viewMode === "years") {
                      setYearPageStart((current) => current + 12);
                    } else {
                      shiftMonth(1);
                    }
                  }}
                  aria-label={viewMode === "years" ? "Next years" : "Next month"}
                >
                  <ChevronRight className="size-4" />
                </Button>
              </div>
            </div>

            {viewMode === "days" && (
              <div className="grid grid-cols-7 gap-1 text-center">
                {WEEKDAYS.map((day) => (
                  <span key={day} className="text-muted-foreground py-1 text-[11px] font-medium">
                    {day}
                  </span>
                ))}
                {days.map((day) => {
                  const isCurrentMonth = day.getMonth() === viewDate.getMonth();
                  const isDisabled = isAfter(day, maxDate);
                  return (
                    <button
                      key={toDateValue(day)}
                      type="button"
                      disabled={isDisabled}
                      className={cn(
                        "focus-visible:ring-primary/30 flex aspect-square items-center justify-center rounded-lg text-sm transition-colors focus-visible:ring-2 focus-visible:outline-none",
                        isCurrentMonth ? "text-foreground" : "text-muted-foreground/45",
                        isSameDay(selectedDate, day) &&
                          "bg-primary text-primary-foreground font-semibold",
                        !isSameDay(selectedDate, day) && !isDisabled && "hover:bg-accent",
                        isDisabled && "cursor-not-allowed opacity-35",
                      )}
                      onClick={() => selectDate(day)}
                      aria-label={DISPLAY_FORMATTER.format(day)}
                      aria-pressed={isSameDay(selectedDate, day)}
                    >
                      {day.getDate()}
                    </button>
                  );
                })}
              </div>
            )}

            {viewMode === "months" && (
              <div className="grid grid-cols-3 gap-2">
                {MONTHS.map((month, index) => {
                  const monthDate = new Date(viewDate.getFullYear(), index, 1);
                  const isDisabled = isAfter(monthDate, maxDate);
                  const isSelected = index === viewDate.getMonth();
                  return (
                    <button
                      key={month}
                      type="button"
                      disabled={isDisabled}
                      className={cn(
                        "focus-visible:ring-primary/30 min-h-11 rounded-xl px-2 text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:outline-none",
                        isSelected && "bg-primary text-primary-foreground",
                        !isSelected && !isDisabled && "text-foreground hover:bg-accent",
                        isDisabled && "text-muted-foreground/40 cursor-not-allowed",
                      )}
                      onClick={() => {
                        setViewDate(new Date(viewDate.getFullYear(), index, 1));
                        setViewMode("days");
                      }}
                    >
                      {month}
                    </button>
                  );
                })}
              </div>
            )}

            {viewMode === "years" && (
              <div className="grid grid-cols-3 gap-2">
                {Array.from({ length: 12 }, (_, index) => yearPageStart + index).map((year) => {
                  const isDisabled = year > maxDate.getFullYear();
                  const isSelected = year === viewDate.getFullYear();
                  return (
                    <button
                      key={year}
                      type="button"
                      disabled={isDisabled}
                      className={cn(
                        "focus-visible:ring-primary/30 min-h-11 rounded-xl px-2 text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:outline-none",
                        isSelected && "bg-primary text-primary-foreground",
                        !isSelected && !isDisabled && "text-foreground hover:bg-accent",
                        isDisabled && "text-muted-foreground/40 cursor-not-allowed",
                      )}
                      onClick={() => {
                        setViewDate(new Date(year, viewDate.getMonth(), 1));
                        setViewMode("days");
                      }}
                    >
                      {year}
                    </button>
                  );
                })}
              </div>
            )}

            <div className="border-border/60 mt-4 flex items-center justify-between border-t pt-3">
              <button
                type="button"
                className="text-primary hover:bg-primary/10 rounded-lg px-2 py-1.5 text-xs font-medium transition-colors"
                onClick={() => selectDate(maxDate)}
              >
                Use today
              </button>
              {selectedDate && (
                <button
                  type="button"
                  className="text-muted-foreground hover:bg-muted hover:text-foreground rounded-lg px-2 py-1.5 text-xs font-medium transition-colors"
                  onClick={() => {
                    onChange("");
                    setOpen(false);
                  }}
                >
                  Clear
                </button>
              )}
            </div>
          </div>,
          document.body,
        )}
    </>
  );
}
