/* ================== Scoreboard (minimal, robust, with fade) ================== */

const IDS = {
  law:  'lawmenCount',
  med:  'medicCount',
  gov:  'govCount',
  tot:  'totalCount',
  title:'scoreboardTitle',
  root: 'scoreboard',
  side: 'sidebar',
  clock: 'clock',
};

const NUMBER_FORMAT = false; // set true to add grouping (e.g., 1,234)

/* ---------- UI builders ---------- */
function createSidebar() {
  const sidebar = document.getElementById(IDS.side);
  if (!sidebar) return;
  sidebar.innerHTML = '';

  const counts = [
    { id: IDS.law, label: '🛡️ Police'   },
    { id: IDS.med, label: '💉 Medic'     },
    { id: IDS.gov, label: '👑 Governor'  },
    { id: IDS.tot, label: '👥 Players'   }
  ];

  for (const item of counts) {
    const box = document.createElement('div');
    box.className = 'duty-count';

    const value = document.createElement('span');
    value.className = 'value';
    value.id = item.id;
    value.textContent = '0';

    const label = document.createElement('span');
    label.className = 'label';
    label.textContent = item.label;

    box.appendChild(value);
    box.appendChild(label);
    sidebar.appendChild(box);
  }
}

/* ---------- helpers ---------- */
function safeNum(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

function fmt(n) {
  if (!NUMBER_FORMAT) return String(n);
  try { return n.toLocaleString(); } catch { return String(n); }
}

function setCount(id, value) {
  const el = document.getElementById(id);
  if (!el) return;
  const prev = Number(el.dataset.prev || '0');
  const v = safeNum(value, 0);
  el.textContent = fmt(v);
  el.dataset.prev = String(v);

  // pulse on change
  if (v !== prev) {
    el.classList.remove('pulse');
    void el.offsetWidth; // reflow
    el.classList.add('pulse');
    setTimeout(() => el.classList.remove('pulse'), 250);
  }
}

/* ---------- boot ---------- */
createSidebar();

const root = document.getElementById(IDS.root);
let fadeListener = null;

// start hidden (and reset classes)
if (root) {
  root.style.display = 'none';
  root.classList.remove('fade-in', 'fade-out');
}

/* ---------- fade helpers ---------- */
function showWithFade() {
  if (!root) return;
  root.removeEventListener('transitionend', fadeListener || (()=>{}));
  root.classList.remove('fade-out');
  root.style.display = 'block';
  // next frame: apply fade-in
  requestAnimationFrame(() => root.classList.add('fade-in'));
}

function hideWithFade() {
  if (!root) return;
  root.classList.remove('fade-in');
  root.classList.add('fade-out');

  // after transition, hide from layout (fallback timeout in case no transitionend fires)
  const done = () => {
    root.style.display = 'none';
    root.removeEventListener('transitionend', done);
    fadeListener = null;
  };
  fadeListener = done;
  root.addEventListener('transitionend', done);
  setTimeout(done, 220); // safety fallback (matches ~160ms CSS + buffer)
}

/* ---------- NUI messages ---------- */
window.addEventListener('message', (event) => {
  const data = event.data || {};

  if (data.type === 'toggle') {
    if (data.display) showWithFade();
    else hideWithFade();
    return;
  }

  if (data.type === 'clock') {
    const el = document.getElementById(IDS.clock);
    if (el && typeof data.text === 'string') {
      el.textContent = data.text;
    }
    return;
  }

  if (data.type === 'update') {
    const titleEl = document.getElementById(IDS.title);
    if (titleEl && typeof data.title === 'string' && data.title.trim() !== '') {
      titleEl.textContent = data.title;
    }

    setCount(IDS.law, safeNum(data.lawmen, 0));
    setCount(IDS.med, safeNum(data.medics, 0));
    setCount(IDS.gov, safeNum(data.governors, 0));
    setCount(IDS.tot, safeNum(data.total, 0));
  }
});

/* ---------- (no Esc/Backspace closer anymore) ---------- */
// If you ever want it back, re-add a key listener and POST to hideUI.
