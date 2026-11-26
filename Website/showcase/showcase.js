// Rokko booth showcase: one 24-second clock drives every chapter's beats.
// Kiosk (?screen=1…5): the wall clock, so all five monitors stay in step.
// ?screen=all: one monitor plays the five chapters in turn, one cycle each.
// Browser (no ?screen): each chapter starts from its first beat when it scrolls into view.
// ?t=8 freezes the clock at 8 s (for checking a frame).
(() => {
  const CYCLE = 24;                       // seconds per chapter; matches the data-at / data-until values
  const params = new URLSearchParams(location.search);
  const screenParam = params.get('screen');
  const frozen = params.has('t') ? +params.get('t') : null;
  const panels = [...document.querySelectorAll('.panel')];

  // Words: wrap each word so it can rise in on its own (keeps <em> emphasis)
  document.querySelectorAll('.words').forEach(el => {
    let i = 0;
    const wrap = node => {
      [...node.childNodes].forEach(n => {
        if (n.nodeType === 3) {
          const frag = document.createDocumentFragment();
          n.textContent.split(/(\s+)/).forEach(part => {
            if (!part) return;
            if (/^\s+$/.test(part)) { frag.append(part); return; }
            const s = document.createElement('span'); s.className = 'w'; s.style.setProperty('--i', i++); s.textContent = part; frag.append(s);
          });
          n.replaceWith(frag);
        } else if (n.nodeType === 1) {
          if (n.tagName === 'EM') { n.classList.add('w'); n.style.setProperty('--i', i++); } else wrap(n);
        }
      });
    };
    wrap(el);
  });

  const kiosk = !!screenParam;
  if (kiosk) document.documentElement.classList.add('kiosk');

  // Which chapter is on screen in kiosk mode
  const showPanel = n => panels.forEach(p => p.classList.toggle('current', p.dataset.screen === String(n)));
  const nowSeconds = () => frozen ?? Date.now() / 1000;
  const chapterFor = () => screenParam === 'all' ? Math.floor(nowSeconds() / CYCLE) % panels.length + 1 : +screenParam;
  if (kiosk) showPanel(chapterFor());

  // Browser: start each chapter's clock when it comes into view
  const started = new Map();
  const io = new IntersectionObserver(es => es.forEach(e => {
    if (e.isIntersecting && e.intersectionRatio > 0.55) { if (!started.has(e.target)) started.set(e.target, nowSeconds()); }
    else if (!e.isIntersecting) started.delete(e.target);
  }), { threshold: [0, 0.55] });
  if (!kiosk) panels.forEach(p => io.observe(p));

  function tick() {
    if (kiosk && screenParam === 'all') showPanel(chapterFor());
    panels.forEach(panel => {
      let t;
      if (kiosk) {
        if (!panel.classList.contains('current')) { setBeats(panel, -1); return; }
        t = frozen ?? nowSeconds() % CYCLE;
      } else {
        if (!started.has(panel)) { setBeats(panel, -1); return; }
        t = frozen ?? (nowSeconds() - started.get(panel)) % CYCLE;
      }
      setBeats(panel, t);
    });
  }

  function setBeats(panel, t) {
    panel.querySelectorAll('.beat').forEach(b => {
      const on = t >= +b.dataset.at && t < +b.dataset.until;
      if (on === b.classList.contains('on')) return;
      b.classList.toggle('on', on);
      if (b.tagName === 'VIDEO') {
        if (on) { if (b.hasAttribute('data-restart')) b.currentTime = 0; b.play().catch(() => {}); }
        else setTimeout(() => { if (!b.classList.contains('on')) b.pause(); }, 1000);
      }
    });
  }

  tick();
  setInterval(tick, 100);

  // Keys for the booth
  addEventListener('keydown', e => {
    const k = e.key.toLowerCase();
    if (k >= '1' && k <= '5') location.search = '?screen=' + k;
    if (k === 'a') location.search = '?screen=all';
    if (k === 'f') document.documentElement.requestFullscreen?.();
  });
})();
