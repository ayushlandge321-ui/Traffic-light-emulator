# 8086 Traffic Light Emulator

A single-file web page (`traffic-light-emulator.html`) that emulates an 8086 assembly traffic light program. It has a landing page and an emulator view. There are no libraries, no build step and no images. Open the file in any modern browser.

- **Course:** Microprocessor Lab
- **Submitted to:** Dr. Sujith M, Associate Professor
- **Students (PRN):** 2125UIDM1080, 2125UIDM1031, 2125UIDF1102, 2125UIDM1116

---

## 1. What it does

The page runs the assembly program below as an animation. It highlights each instruction as it "executes", prints to a fake DOS screen, and lights a traffic signal.

```asm
.MODEL SMALL
.STACK 100H

.DATA
HI DB 'Hello Prof. Sujit',13,10,'$'
R  DB 'RED    - STOP',13,10,'$'
G  DB 'GREEN  - GO',13,10,'$'
Y  DB 'YELLOW - READY',13,10,'$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX        ; point DS to data
    MOV AH, 09H       ; print greeting once
    LEA DX, HI
    INT 21H
AGAIN:
    LEA DX, R
    CALL SHOW         ; red
    LEA DX, Y
    CALL SHOW         ; yellow
    LEA DX, G
    CALL SHOW         ; green
    MOV AH, 01H       ; check keyboard
    INT 16H
    JZ AGAIN          ; no key: repeat
    MOV AH, 4CH       ; key: exit
    INT 21H
MAIN ENDP

SHOW PROC             ; print DX, wait 3 s
    MOV AH, 09H
    INT 21H
    MOV AH, 86H       ; BIOS wait
    MOV CX, 002DH
    MOV DX, 0C6C0H
    INT 15H
    RET
SHOW ENDP
END MAIN
```

Key points of the program:

| Part | Purpose |
|---|---|
| `INT 21H, AH=09H` | DOS: print the `$`-terminated string at DS:DX |
| `INT 15H, AH=86H` | BIOS: wait CX:DX microseconds. `002DC6C0h` = 3,000,000 us = 3 s |
| `INT 16H, AH=01H` | BIOS: check keyboard without waiting. ZF=1 means no key |
| `INT 21H, AH=4CH` | DOS: exit the program |
| `CALL SHOW / RET` | Reusable print-and-wait procedure |

---

## 2. File structure

Everything lives in one HTML file with three blocks.

```
traffic-light-emulator.html
├── <style>     all CSS (landing styles + emulator styles)
├── <body>
│   └── <main>
│       ├── #home   landing page
│       └── #emu    emulator page (hidden until opened)
└── <script>    page switching + emulator logic
```

### HTML layout

**Landing page (`#home`)**
- `.top` header strip (course name, "8086 Assembly")
- `.hero` two columns: text and call-to-action on the left, animated signal on the right
- `.strip` three feature tiles (Live listing, DOS screen, Explained)
- `.credits` submitted-to and PRN details

**Emulator page (`#emu`)**
- `.topbar` "Home" link and breadcrumb
- Header panel: title, intro text, submitted-to and student details
- `.cols` two columns:
  - Left: **Emulator Screen** panel with `.light` (three lamps), `.term` (terminal), Run and "Press a key" buttons, and a status bar showing status and ZF
  - Right: **traffic.asm** panel with the line-numbered listing
- **Explanation** panel with a definition list, a note, and an instruction table

---

## 3. How the two pages switch

Both pages are in the same file. The URL hash decides which one is visible.

| URL hash | Result |
|---|---|
| (none) or `#home` | Landing page shown |
| `#emulator` | Emulator page shown |

```js
function route(){
  const emu = location.hash === '#emulator';
  if(!emu && typeof stopRun === 'function') stopRun();
  homeEl.hidden = emu;
  emuEl.hidden = !emu;
  window.scrollTo(0,0);
}
addEventListener('hashchange', route);
```

- The links are plain `<a href="#emulator">` and `<a href="#home">`.
- Visibility uses the HTML `hidden` attribute. CSS contains `[hidden]{display:none!important}` so it always wins.
- The browser Back button works because each switch is a hash change.
- `stopRun()` cancels a running program when you leave the emulator, and resets the screen.

---

## 4. Emulator logic (JavaScript)

### 4.1 The listing is data

The assembly is stored as an array of `[code, comment]` pairs in `LINES`. Each pair becomes one `<div id="L0">`, `<div id="L1">`, and so on. The line number is the array index, which is how the animation can highlight any line by number.

```js
const LINES = [
  [".MODEL SMALL",""],
  ...
  ["    MOV DS, AX","; point DS to data"],
  ...
];
```

`<` and `&` are escaped before being inserted into the HTML. The comment goes in a `<span class="c">` so it can be coloured separately.

### 4.2 Helper functions

| Function | Job |
|---|---|
| `paint()` | Shows the last 10 terminal lines in `#term` |
| `out(t)` | Adds a line to the terminal |
| `hl(i)` | Highlights listing line `i` (or clears it for `-1`) and scrolls it into view |
| `lamp(k)` | Turns on one lamp (`'R'`, `'Y'`, `'G'`) or all off (`null`) |
| `sleep(ms)` | Promise-based delay |
| `step(i, t, ms)` | Highlights line `i`, waits `ms` (default 400), and aborts if the run was cancelled |
| `show(...)` | Plays the `SHOW` procedure: print, light the lamp, wait 3 seconds |
| `run()` | The main program |
| `press()` | Simulates a key press |
| `stopRun()` | Cancels a running program (used when leaving the emulator page) |

### 4.3 Cancelling with a token

Each run gets a number from `const t = ++token`. Every `step()` checks `if(t !== token) throw 0`. If `token` changes (a new run starts, or `stopRun()` is called), the old run throws and stops cleanly, and the `catch` swallows it. This avoids two programs running at once.

### 4.4 How `run()` mirrors the assembly

```
setup lines 11–15      →  prints "Hello Prof. Sujit" once
AGAIN (line 16)        →  loop start
  LEA DX,R + CALL SHOW →  RED, light red, wait 3 s
  LEA DX,Y + CALL SHOW →  YELLOW, light yellow, wait 3 s
  LEA DX,G + CALL SHOW →  GREEN, light green, wait 3 s
  INT 16H check        →  ZF = 1 if no key, 0 if a key was pressed
  JZ AGAIN             →  loop again unless a key was pressed
exit (lines 26–27)     →  "Program terminated." and back to C:\>
```

Inside `show()`, the lines highlighted for the call and body are 31–38 of the listing. The wait is shown as a 3-second countdown (`Status: waiting 3 s`, then `2`, then `1`), one second each.

### 4.5 Keyboard check

The keyboard is only checked once per cycle, after green, exactly like the assembly. Pressing any key (or the "Press a key" button) sets `keyHit = true`. The program notices at the check, so it finishes the current cycle first (up to 9 seconds). The Tab key is ignored so keyboard navigation still works.

---

## 5. Design system

The look is a warm "paper and ink" style with flat offset shadows. It avoids glossy gradients and neon colours. The only saturated colours are the three signal colours.

### 5.1 Colour palette (CSS variables)

| Variable | Hex | Used for |
|---|---|---|
| `--paper` | `#ece6d8` | Page background |
| `--card` | `#f7f3ea` | Panels and tiles |
| `--ink` | `#1c1a16` | Text, borders, shadows, title bars |
| `--muted` | `#6b6558` | Secondary text |
| `--line` | `#cdc5b1` | Thin borders inside panels |
| `--red` | `#c4382c` | Red lamp, accents, focus rings |
| `--amber` | `#d99a1e` | Yellow lamp |
| `--green` | `#3d8a4e` | Green lamp |
| `--night` | `#1a1815` | Signal housing and terminal background |
| `--cream` | `#efe9da` | Text on dark backgrounds |

Other fixed colours: `#fff9ea` (inset surfaces and table cells), `#3a3631` (unlit lamp), `#38342d` (body copy), `#5f7a3e` and `#b5cf8a` (assembly comments on light and highlighted lines).

### 5.2 Typography

No web fonts are loaded, so the page loads fast and works offline. The fonts come from the user's system.

| Variable | Stack | Used for |
|---|---|---|
| `--mono` | `ui-monospace, "SF Mono", "Cascadia Mono", "Courier New", Courier, monospace` | Body, code, terminal, buttons |
| `--serif` | `Georgia, "Iowan Old Style", "Times New Roman", serif` | Headings and tile titles |

- Body: 14px, line-height 1.6
- Landing headline: `clamp(38px, 7vw, 74px)`, scales with screen width
- Emulator headline: `clamp(26px, 4.4vw, 38px)`
- Small labels: 11.5 to 12.5px, uppercase with letter-spacing

### 5.3 Visual details

- **Background:** a faint dot grid made from `radial-gradient(...)` with `background-size:22px`.
- **Panels:** 1.5px ink border, 4px radius, and a hard offset shadow (`5px 5px 0 var(--ink)`) with no blur.
- **Title bars:** ink background with a small red dot added by `::before`.
- **Buttons:** flat with a hard shadow. On hover they move up-left, and on press they sink into the shadow.
- **Signal lamps:** a dim grey when off. When on they get the colour plus a soft glow (`box-shadow`).
- **Landing signal:** the three bulbs light in turn using a 9-second CSS animation (`@keyframes hr`, `hy`, `hg`), each bulb on for about a third of the cycle.

### 5.4 CSS organisation

Styles are scoped so the two pages never clash.

- `#home .something` for landing styles
- `#emu .something` for emulator styles
- Shared variables, body, links and the `[hidden]` rule at the top

---

## 6. Responsive behaviour

| Breakpoint | Changes |
|---|---|
| `max-width: 820px` | Landing hero becomes one column, with the signal first. Tiles and credits stack. Emulator columns and info boxes stack |
| `max-width: 480px` | Emulator stage narrows (lamp column 96px, lamps 46px) and shadows shrink |
| `prefers-reduced-motion` | Transitions are off and the landing signal stops animating, staying on red |

Other mobile touches:
- `viewport-fit=cover` plus `env(safe-area-inset-*)` padding keeps content clear of notches.
- `-webkit-text-size-adjust:100%` stops text from resizing on phones.
- The code listing and instruction table scroll sideways when too wide.

---

## 7. Accessibility

- Terminal has `role="log"` and `aria-live="polite"`, so screen readers announce new output.
- Decorative lamps are `aria-hidden="true"`.
- The landing signal link has `aria-label="Open the emulator"`.
- The listing has an `aria-label`.
- Visible focus ring (`2px solid var(--red)`) on links and buttons.
- Disabled Run button shows reduced opacity and a not-allowed cursor.

---

## 8. How to run

1. Save `traffic-light-emulator.html` anywhere.
2. Double-click it to open in a browser. No server is needed.
3. Click the signal or the "Open the emulator" button.
4. Press **Run**. Watch the lines highlight, the lamps change and the terminal print.
5. Press any key or the **Press a key** button to stop. The program exits after the current cycle.

---

## 9. Possible extensions

- A speed control (change the 400 ms step and the 1000 ms countdown tick).
- A "step" mode that advances one instruction per click.
- Showing register values (AX, DX, DS) next to the listing.
- Switching the order to red, green, yellow like a real light.
