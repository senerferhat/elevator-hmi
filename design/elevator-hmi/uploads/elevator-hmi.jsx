import { useState, useEffect, useRef } from "react";

const FLOORS = ["B2", "B1", "G", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"];
const FLOOR_INDEX = Object.fromEntries(FLOORS.map((f, i) => [f, i]));

function pad(n) { return String(n).padStart(2, "0"); }

function Clock() {
  const [t, setT] = useState(new Date());
  useEffect(() => { const id = setInterval(() => setT(new Date()), 1000); return () => clearInterval(id); }, []);
  return (
    <div style={{ fontFamily: "'Courier New', monospace", color: "#b8a060", fontSize: 22, letterSpacing: 4, textAlign: "right" }}>
      <div style={{ fontSize: 32, fontWeight: 700 }}>
        {pad(t.getHours())}:{pad(t.getMinutes())}:{pad(t.getSeconds())}
      </div>
      <div style={{ fontSize: 14, opacity: 0.6, marginTop: 2 }}>
        {t.toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short", year: "numeric" }).toUpperCase()}
      </div>
    </div>
  );
}

function DirectionArrow({ dir }) {
  const up = dir === "up";
  const idle = dir === "idle";
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
      <svg width={44} height={44} viewBox="0 0 44 44">
        <polygon
          points="22,4 40,36 4,36"
          fill={up && !idle ? "#e8c84a" : "#2a2820"}
          stroke={up && !idle ? "#e8c84a" : "#3a3830"}
          strokeWidth={1.5}
          style={{ transition: "fill 0.4s, filter 0.4s", filter: up && !idle ? "drop-shadow(0 0 8px #e8c84a88)" : "none" }}
        />
      </svg>
      <svg width={44} height={44} viewBox="0 0 44 44">
        <polygon
          points="22,40 40,8 4,8"
          fill={!up && !idle ? "#e8c84a" : "#2a2820"}
          stroke={!up && !idle ? "#e8c84a" : "#3a3830"}
          strokeWidth={1.5}
          style={{ transition: "fill 0.4s, filter 0.4s", filter: !up && !idle ? "drop-shadow(0 0 8px #e8c84a88)" : "none" }}
        />
      </svg>
    </div>
  );
}

function FloorIndicatorBar({ current, destination, direction }) {
  return (
    <div style={{ display: "flex", flexDirection: "column-reverse", gap: 3, alignItems: "center" }}>
      {FLOORS.map((f) => {
        const isCurrent = f === current;
        const isDest = f === destination;
        const isPassed = direction === "up"
          ? FLOOR_INDEX[f] <= FLOOR_INDEX[current]
          : FLOOR_INDEX[f] >= FLOOR_INDEX[current];
        return (
          <div key={f} style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{
              width: isCurrent ? 36 : isDest ? 28 : 18,
              height: 7,
              borderRadius: 4,
              background: isCurrent
                ? "#e8c84a"
                : isDest
                  ? "#8a7230"
                  : isPassed
                    ? "#3a3620"
                    : "#222018",
              boxShadow: isCurrent ? "0 0 10px #e8c84a99" : "none",
              transition: "all 0.3s",
            }} />
            <span style={{
              fontFamily: "'Courier New', monospace",
              fontSize: 11,
              color: isCurrent ? "#e8c84a" : isDest ? "#8a7230" : "#444",
              width: 20,
              fontWeight: isCurrent ? 700 : 400,
              transition: "color 0.3s",
            }}>{f}</span>
          </div>
        );
      })}
    </div>
  );
}

function DoorStatus({ open }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
      <div style={{
        width: open ? 8 : 22,
        height: 40,
        background: open ? "#2a2820" : "#5a4f2a",
        borderRadius: 3,
        transition: "width 0.5s ease",
        boxShadow: open ? "none" : "inset -2px 0 4px #00000044",
      }} />
      <div style={{
        width: 20, height: 40, border: "1px dashed #3a3830",
        borderRadius: 3, display: "flex", alignItems: "center",
        justifyContent: "center",
      }}>
        <div style={{ width: 2, height: 20, background: "#3a3830" }} />
      </div>
      <div style={{
        width: open ? 8 : 22,
        height: 40,
        background: open ? "#2a2820" : "#5a4f2a",
        borderRadius: 3,
        transition: "width 0.5s ease",
        boxShadow: open ? "none" : "inset 2px 0 4px #00000044",
      }} />
      <span style={{
        fontFamily: "'Courier New', monospace",
        fontSize: 11,
        color: open ? "#e8c84a" : "#666",
        letterSpacing: 2,
        marginLeft: 4,
        transition: "color 0.4s",
      }}>{open ? "OPEN" : "CLOSED"}</span>
    </div>
  );
}

function WeightBar({ pct }) {
  const color = pct > 85 ? "#e84a4a" : pct > 60 ? "#e8a84a" : "#4ae88a";
  return (
    <div style={{ width: "100%", display: "flex", alignItems: "center", gap: 10 }}>
      <span style={{ fontFamily: "'Courier New', monospace", fontSize: 10, color: "#555", letterSpacing: 2, minWidth: 52 }}>LOAD</span>
      <div style={{ flex: 1, height: 6, background: "#1e1c14", borderRadius: 3, overflow: "hidden" }}>
        <div style={{
          width: `${pct}%`, height: "100%", background: color,
          borderRadius: 3, transition: "width 0.8s ease, background 0.4s",
          boxShadow: `0 0 6px ${color}88`,
        }} />
      </div>
      <span style={{ fontFamily: "'Courier New', monospace", fontSize: 10, color, minWidth: 36, textAlign: "right" }}>{pct}%</span>
    </div>
  );
}

export default function ElevatorHMI() {
  const [current, setCurrent] = useState("G");
  const [destination, setDestination] = useState("5");
  const [direction, setDirection] = useState("up");
  const [moving, setMoving] = useState(true);
  const [doorOpen, setDoorOpen] = useState(false);
  const [load, setLoad] = useState(42);
  const intervalRef = useRef(null);

  useEffect(() => {
    if (!moving) return;
    intervalRef.current = setInterval(() => {
      setCurrent(prev => {
        const ci = FLOOR_INDEX[prev];
        const di = FLOOR_INDEX[destination];
        if (ci === di) {
          setMoving(false);
          setDoorOpen(true);
          setDirection("idle");
          setTimeout(() => setDoorOpen(false), 3000);
          return prev;
        }
        const next = ci < di ? FLOORS[ci + 1] : FLOORS[ci - 1];
        setDirection(ci < di ? "up" : "down");
        return next;
      });
    }, 1200);
    return () => clearInterval(intervalRef.current);
  }, [moving, destination]);

  const handleFloorSelect = (f) => {
    if (f === current) return;
    setDestination(f);
    setMoving(true);
    setDoorOpen(false);
  };

  useEffect(() => {
    const id = setInterval(() => setLoad(l => Math.max(10, Math.min(95, l + (Math.random() > 0.5 ? 1 : -1)))), 3000);
    return () => clearInterval(id);
  }, []);

  return (
    <div style={{
      width: "100vw", height: "100vh",
      background: "#0a0904",
      display: "flex", alignItems: "center", justifyContent: "center",
    }}>
      <div style={{
        width: 900, height: 560,
        background: "linear-gradient(160deg, #18170f 0%, #111009 100%)",
        border: "1px solid #2e2c1e",
        borderRadius: 12,
        boxShadow: "0 0 80px #00000088, inset 0 1px 0 #3a3820",
        display: "grid",
        gridTemplateColumns: "200px 1fr 180px",
        overflow: "hidden",
        position: "relative",
      }}>
        {/* Scanline overlay */}
        <div style={{
          position: "absolute", inset: 0, pointerEvents: "none", zIndex: 10,
          backgroundImage: "repeating-linear-gradient(0deg, transparent, transparent 3px, rgba(0,0,0,0.06) 3px, rgba(0,0,0,0.06) 4px)",
        }} />

        {/* LEFT — Floor indicator */}
        <div style={{
          borderRight: "1px solid #1e1c12",
          display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center",
          padding: "24px 16px", gap: 16,
        }}>
          <span style={{ fontFamily: "'Courier New', monospace", fontSize: 9, color: "#444", letterSpacing: 3, marginBottom: 8 }}>FLOORS</span>
          <FloorIndicatorBar current={current} destination={destination} direction={direction} />
        </div>

        {/* CENTER — Main display */}
        <div style={{
          display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "space-between",
          padding: "28px 32px",
        }}>
          {/* Top row */}
          <div style={{ width: "100%", display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <div>
              <div style={{ fontFamily: "'Courier New', monospace", fontSize: 10, color: "#444", letterSpacing: 3, marginBottom: 4 }}>STATUS</div>
              <div style={{
                fontFamily: "'Courier New', monospace", fontSize: 13,
                color: moving ? "#e8c84a" : doorOpen ? "#4ae8a8" : "#666",
                letterSpacing: 2, transition: "color 0.3s",
              }}>
                {moving ? "● IN TRANSIT" : doorOpen ? "● DOORS OPEN" : "○ STANDBY"}
              </div>
            </div>
            <Clock />
          </div>

          {/* Hero floor number */}
          <div style={{ textAlign: "center" }}>
            <div style={{
              fontFamily: "'Courier New', monospace",
              fontSize: 160, fontWeight: 900,
              color: "#e8c84a", lineHeight: 1, letterSpacing: -8,
              textShadow: "0 0 40px #e8c84a44, 0 0 80px #e8c84a22",
              transition: "all 0.3s",
              minWidth: 200, textAlign: "center",
            }}>
              {current}
            </div>
            <div style={{ fontFamily: "'Courier New', monospace", fontSize: 12, color: "#555", letterSpacing: 4, marginTop: -8 }}>
              CURRENT FLOOR
            </div>
          </div>

          {/* Bottom controls */}
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 14, width: "100%" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 24 }}>
              <DirectionArrow dir={direction} />
              <DoorStatus open={doorOpen} />
            </div>
            <WeightBar pct={load} />
          </div>
        </div>

        {/* RIGHT — Floor selector */}
        <div style={{
          borderLeft: "1px solid #1e1c12",
          display: "flex", flexDirection: "column",
          padding: "20px 14px", gap: 8, overflowY: "auto",
        }}>
          <span style={{ fontFamily: "'Courier New', monospace", fontSize: 9, color: "#444", letterSpacing: 3, marginBottom: 4, textAlign: "center" }}>SELECT</span>
          {[...FLOORS].reverse().map(f => {
            const isCurrent = f === current;
            const isDest = f === destination;
            return (
              <button key={f} onClick={() => handleFloorSelect(f)} style={{
                background: isCurrent ? "#e8c84a" : isDest ? "#3a3010" : "#18170f",
                border: `1px solid ${isCurrent ? "#e8c84a" : isDest ? "#8a7030" : "#2a2820"}`,
                borderRadius: 6,
                color: isCurrent ? "#0e0d09" : isDest ? "#e8c84a" : "#555",
                fontFamily: "'Courier New', monospace",
                fontSize: 16, fontWeight: isCurrent || isDest ? 700 : 400,
                padding: "8px 0", cursor: isCurrent ? "default" : "pointer",
                transition: "all 0.2s", letterSpacing: 1,
                boxShadow: isCurrent ? "0 0 12px #e8c84a66" : isDest ? "0 0 8px #8a703044" : "none",
              }}>
                {f}
              </button>
            );
          })}
        </div>
      </div>

      <div style={{
        position: "fixed", bottom: 16, left: 0, right: 0, textAlign: "center",
        fontFamily: "'Courier New', monospace", fontSize: 11, color: "#333", letterSpacing: 2,
      }}>
        ELEVATOR HMI — 10" LCD DEMO · Click floor buttons to simulate
      </div>
    </div>
  );
}
