# DI-M6 — UI Update: Hardware Mode Toggle + Badge

**File to modify:** `E:\539Labs\demo\templates\index.html`
**No other files change in this directive.**

Prerequisite: DI-M5 COMPLETE. Flask now responds with `hardware`, `wall_ms`, `sim_us`,
`sim_cycles`, and `trace` (may be `null`) in `/api/hash` responses, and serves
`/api/get_mode` / `/api/set_mode`.

---

## Overview of changes

1. **CSS** — add hardware-mode CSS block inside `<style>`
2. **HTML** — insert mode-bar div inside Hash panel; augment hash-output with badge, timing, trace placeholder
3. **JavaScript** — add state vars, toggle handler, `updateModeText` function, update hash click handler, extend load handler

All changes are confined to `#tab-hash` and the `<script>` block. No other tab HTML changes.

---

## EDIT 1 — CSS additions

Find this line in `<style>` (near end of existing CSS, before `/* ── Responsive ──`):

```
    .badge-phase.gold {
      background: rgba(244, 196, 48, 0.08); border-color: rgba(244, 196, 48, 0.2);
      color: var(--gold);
    }
```

**Insert AFTER that block** (before the next comment `/* ── Hamming stat`):

```css
    /* ── Hardware mode UI ─────────────────────────────────────── */
    .hw-mode-bar {
      display: none;
      align-items: center; gap: 0.75rem;
      padding: 0.5rem 0.9rem; margin-bottom: 0.75rem;
      background: var(--surface-2); border: 1px solid var(--border);
      border-radius: 6px; font-size: 0.78rem;
    }
    .hw-mode-bar.visible { display: flex; }
    .hw-mode-label {
      color: var(--text-3); font-size: 0.72rem;
      text-transform: uppercase; letter-spacing: 0.08em;
    }
    .hw-toggle-track {
      position: relative; display: inline-block;
      width: 40px; height: 20px; cursor: pointer;
    }
    .hw-toggle-track input { opacity: 0; width: 0; height: 0; position: absolute; }
    .hw-toggle-thumb {
      position: absolute; inset: 0; border-radius: 20px;
      background: var(--surface); border: 1px solid var(--border);
      transition: background 0.2s, border-color 0.2s;
    }
    .hw-toggle-thumb::after {
      content: ''; position: absolute; left: 2px; top: 2px;
      width: 14px; height: 14px; border-radius: 50%;
      background: var(--text-3); transition: transform 0.2s, background 0.2s;
    }
    .hw-toggle-track input:checked + .hw-toggle-thumb {
      background: rgba(0, 212, 170, 0.15);
      border-color: rgba(0, 212, 170, 0.5);
    }
    .hw-toggle-track input:checked + .hw-toggle-thumb::after {
      transform: translateX(20px); background: var(--accent);
    }
    .hw-mode-text { color: var(--text-2); font-family: var(--mono); font-size: 0.78rem; }
    .hw-mode-text.active { color: var(--accent); }
    .hw-badge {
      display: inline-flex; align-items: center; gap: 0.35rem;
      background: rgba(0, 212, 170, 0.1); border: 1px solid rgba(0, 212, 170, 0.3);
      border-radius: 4px; color: var(--accent);
      font-size: 0.72rem; font-weight: 600; padding: 0.15rem 0.5rem;
      font-family: var(--mono);
    }
    .hw-timing {
      display: none;
      font-size: 0.72rem; color: var(--text-3); font-family: var(--mono);
      padding: 0.5rem 0.75rem; margin-bottom: 0.5rem;
      background: rgba(0, 212, 170, 0.04);
      border: 1px solid rgba(0, 212, 170, 0.12); border-radius: 6px;
    }
    .hw-timing.visible { display: block; }
    .hw-timing span { color: var(--accent); }
    #hash-trace-na {
      display: none;
      font-size: 0.75rem; color: var(--text-3); font-style: italic;
      margin-bottom: 0.4rem;
    }
```

---

## EDIT 2 — Mode bar HTML (inside Hash panel)

Find this exact block (closes the flex-row containing mode select + hash button):

```html
        <div style="padding-top:1.35rem;">
          <button id="hash-btn" class="btn-primary">Compute Hash</button>
        </div>
      </div>

      <div id="hash-output" style="display:none;">
```

Replace with:

```html
        <div style="padding-top:1.35rem;">
          <button id="hash-btn" class="btn-primary">Compute Hash</button>
        </div>
      </div>

      <!-- hardware mode bar — hidden until XSim available -->
      <div class="hw-mode-bar" id="hw-mode-bar">
        <span class="hw-mode-label">Compute Engine</span>
        <label class="hw-toggle-track">
          <input type="checkbox" id="hw-toggle">
          <span class="hw-toggle-thumb"></span>
        </label>
        <span id="hw-mode-text" class="hw-mode-text">Software Model</span>
      </div>

      <div id="hash-output" style="display:none;">
```

---

## EDIT 3 — Augment hash-output section

Find this exact block inside `#hash-output`:

```html
      <div id="hash-output" style="display:none;">
        <div class="spacer-sm">
          <label class="field-label">Digest (512-bit)</label>
          <div class="hex-wrapper">
            <div id="hash-digest" class="hex-box"></div>
            <button class="copy-btn" data-copy="hash-digest">copy</button>
          </div>
        </div>
        <div class="spacer-sm">
          <canvas id="hash-chart" height="110"></canvas>
        </div>
        <div class="flex-tags spacer-sm">
```

Replace with:

```html
      <div id="hash-output" style="display:none;">
        <div class="spacer-sm">
          <label class="field-label">Digest (512-bit)</label>
          <div id="hw-result-badge" style="display:none; margin-bottom:0.5rem;">
            <span class="hw-badge">&#x26A1; Hardware Simulation &nbsp;&middot;&nbsp; XSim RTL</span>
          </div>
          <div class="hw-timing" id="hw-timing"></div>
          <div class="hex-wrapper">
            <div id="hash-digest" class="hex-box"></div>
            <button class="copy-btn" data-copy="hash-digest">copy</button>
          </div>
        </div>
        <div class="spacer-sm">
          <div id="hash-trace-na">Bit-width trajectory not available in hardware simulation mode.</div>
          <canvas id="hash-chart" height="110"></canvas>
        </div>
        <div class="flex-tags spacer-sm">
```

---

## EDIT 4 — JavaScript state variables

Find this line near the top of the `<script>` block:

```javascript
  // ── Phase boundary plugin ─────────────────────────────────────
```

**Insert BEFORE it**:

```javascript
  // ── Hardware mode state ───────────────────────────────────────
  let xsimAvailable = false;
  let hardwareModeActive = false;

```

---

## EDIT 5 — Toggle handler + updateModeText

Find this block:

```javascript
  // ── Auto-sync av2 with av1 ────────────────────────────────────
  document.getElementById('av1').addEventListener('input', function() {
    document.getElementById('av2').value = this.value;
  });
```

**Insert BEFORE it**:

```javascript
  // ── Hardware mode toggle ──────────────────────────────────────
  document.getElementById('hw-toggle').addEventListener('change', async function() {
    const wantHw = this.checked;
    try {
      const res = await fetch('/api/set_mode', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({mode: wantHw ? 'hardware' : 'software'})
      });
      const d = await res.json();
      hardwareModeActive = d.mode === 'hardware';
    } catch (e) {
      hardwareModeActive = false;
    }
    this.checked = hardwareModeActive;
    updateModeText(hardwareModeActive);
  });

  function updateModeText(hw) {
    const el = document.getElementById('hw-mode-text');
    el.textContent = hw ? 'Hardware Simulation' : 'Software Model';
    el.classList.toggle('active', hw);
  }

```

---

## EDIT 6 — Replace hash click handler

Find and replace the **entire** existing hash click listener. The old block starts with:

```javascript
  // ── Hash ─────────────────────────────────────────────────────
  document.getElementById('hash-btn').addEventListener('click', async () => {
    const msg  = document.getElementById('hash-message').value || 'Enter any message...';
    const mode = document.getElementById('hash-mode').value;
    const res  = await fetch('/api/hash', {
```

...and ends with (inclusive):

```javascript
    });
  });
```

Replace the **entire block** from `// ── Hash ──` through the closing `});` with:

```javascript
  // ── Hash ─────────────────────────────────────────────────────
  document.getElementById('hash-btn').addEventListener('click', async () => {
    const btn  = document.getElementById('hash-btn');
    const msg  = document.getElementById('hash-message').value || 'Enter any message...';
    const mode = document.getElementById('hash-mode').value;

    btn.disabled = true;
    btn.textContent = hardwareModeActive
      ? 'Simulating: 9,225 cycles @ 100 MHz…'
      : 'Computing…';

    try {
      const res  = await fetch('/api/hash', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({message: msg, mode})
      });
      const data = await res.json();
      if (!res.ok) { alert('Hash error: ' + (data.error || res.status)); return; }

      document.getElementById('hash-digest').textContent = data.digest;

      // Hardware badge
      const badge = document.getElementById('hw-result-badge');
      badge.style.display = data.hardware ? 'block' : 'none';

      // Timing row
      const timingEl = document.getElementById('hw-timing');
      if (data.hardware && data.sim_us != null) {
        timingEl.innerHTML =
          'Simulated latency: <span>' + data.sim_us + ' μs</span> &nbsp;&middot;&nbsp; ' +
          'Cycles: <span>' + data.sim_cycles.toLocaleString() + '</span> @ 100 MHz &nbsp;&middot;&nbsp; ' +
          'Wall-clock: <span>' + (data.wall_ms / 1000).toFixed(2) + ' s</span>';
        timingEl.classList.add('visible');
      } else {
        timingEl.classList.remove('visible');
      }

      document.getElementById('hash-output').style.display = 'block';

      // Trace chart vs hardware placeholder
      const traceNA     = document.getElementById('hash-trace-na');
      const chartCanvas = document.getElementById('hash-chart');
      if (!data.trace) {
        traceNA.style.display = 'block';
        chartCanvas.style.display = 'none';
        if (window.hashChart) { window.hashChart.destroy(); window.hashChart = null; }
      } else {
        traceNA.style.display = 'none';
        chartCanvas.style.display = '';
        if (typeof Chart === 'undefined') return;
        Chart.register(phaseBoundaryPlugin);
        if (window.hashChart) window.hashChart.destroy();
        window.hashChart = new Chart(chartCanvas, {
          type: 'line',
          data: {
            labels: Array.from({length: 540}, (_, i) => i),
            datasets: [{
              label: 'State Bit Width',
              data: data.trace,
              borderColor: 'rgba(0, 212, 170, 0.9)',
              backgroundColor: 'rgba(0, 212, 170, 0.04)',
              borderWidth: 1.5,
              tension: 0.25,
              pointRadius: 0,
              fill: true
            }]
          },
          options: {
            animation: {duration: 400},
            scales: {
              x: {
                ticks: {color: '#58626b', font: {size: 11}, maxTicksLimit: 12},
                grid:  {color: 'rgba(48,54,61,0.5)'},
                title: {display: true, text: 'Step', color: '#58626b', font: {size: 11}}
              },
              y: {
                ticks: {color: '#58626b', font: {size: 11}},
                grid:  {color: 'rgba(48,54,61,0.5)'},
                title: {display: true, text: 'State Bit Width', color: '#58626b', font: {size: 11}}
              }
            },
            plugins: {
              legend: {display: false},
              tooltip: {
                backgroundColor: '#0d1117',
                borderColor: 'rgba(48,54,61,0.8)', borderWidth: 1,
                titleColor: '#8b949e', bodyColor: '#00d4aa',
                titleFont: {family: 'JetBrains Mono, monospace', size: 11},
                bodyFont:  {family: 'JetBrains Mono, monospace', size: 11},
                callbacks: {
                  title: items => 'Step ' + items[0].label,
                  label: item  => item.parsed.y + ' bits'
                }
              }
            }
          }
        });
      }
    } finally {
      btn.disabled = false;
      btn.textContent = 'Compute Hash';
    }
  });
```

---

## EDIT 7 — Extend load handler to restore mode

Find this block (near end of script):

```javascript
  // ── Init ─────────────────────────────────────────────────────
  window.addEventListener('load', () => {
    document.getElementById('hash-message').value = '539 Labs';
    document.getElementById('enc-pt').value       = 'Hello 539 Labs';
  });
```

Replace with:

```javascript
  // ── Init ─────────────────────────────────────────────────────
  window.addEventListener('load', () => {
    document.getElementById('hash-message').value = '539 Labs';
    document.getElementById('enc-pt').value       = 'Hello 539 Labs';

    // Restore hardware mode state from Flask (no-op if XSim not available)
    fetch('/api/get_mode')
      .then(r => r.json())
      .then(d => {
        xsimAvailable = d.available;
        hardwareModeActive = d.mode === 'hardware';
        if (xsimAvailable) {
          document.getElementById('hw-mode-bar').classList.add('visible');
          const tog = document.getElementById('hw-toggle');
          tog.checked = hardwareModeActive;
          updateModeText(hardwareModeActive);
        }
      })
      .catch(() => {}); // Vivado not present — silently ignore
  });
```

---

## Verification

Run Flask with `HQH539_USE_XSIM=false` (default). Open http://localhost:5391.

**Test 1 — No XSim: mode bar invisible**
- The `#hw-mode-bar` div must NOT be visible. Hash panel looks identical to pre-DI-M6.
- Compute Hash → digest + trace chart rendered normally. No badge, no timing row.

Run Flask with `HQH539_USE_XSIM=true`.

**Test 2 — XSim available: mode bar shows, default software**
- On page load, `#hw-mode-bar` is visible, toggle is OFF, text reads "Software Model".
- Compute Hash (STD) → digest + trace chart. No hardware badge. Button restores to "Compute Hash".

**Test 3 — Switch to hardware mode**
- Click toggle ON → text changes to "Hardware Simulation" (accent colour).
- Compute Hash (message="hello", mode=STD) → button shows "Simulating: 9,225 cycles @ 100 MHz…" during wait.
- Result: `⚡ Hardware Simulation · XSim RTL` badge visible.
- Timing row visible: shows sim_us, cycle count, wall-clock seconds.
- Trace chart canvas is hidden. "Bit-width trajectory not available…" text shown.
- Button restores to "Compute Hash" after result.

**Test 4 — KDF mode with hardware ON**
- Select mode=KDF, compute hash → `data.hardware` is `false` in response.
- Badge NOT shown, timing row NOT shown, trace chart IS shown (Python fallback returns trace).

**Test 5 — Page reload restores toggle state**
- With hardware mode ON, reload page → get_mode restores toggle to ON, text reads "Hardware Simulation".

**Test 6 — Switch back to software**
- Click toggle OFF → text returns to "Software Model".
- Compute Hash (STD) → trace chart shown, no badge.

---

*Directive written by Orchestrator (Claude) | Builder: Grok | 539 Labs LLC*
