// Rokko website motion. Mirrors the app's home screen (RokkoMotion):
// parallax far 0.25 / mid 0.55, neighbouring cards at 0.92 scale and 0.75 saturation.
// Reduce Motion: no parallax or scaling, fades only.
(() => {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const NEIGHBOUR_SCALE = 0.92, NEIGHBOUR_SATURATION = 0.75;

  // Reveal sections as they arrive (screen fade)
  const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }),
    { rootMargin: '0px 0px -8% 0px' });
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));

  // Hero parallax, driven by scroll (never a timer)
  const layers = [...document.querySelectorAll('.scenery .layer')];
  let ticking = false;
  const onScroll = () => {
    if (!ticking) requestAnimationFrame(() => {
      const y = scrollY;
      if (!still) layers.forEach(l => l.style.transform = `translate3d(0, ${y * l.dataset.depth}px, 0)`);
      stickyUpdate();
      ticking = false;
    });
    ticking = true;
  };

  // Sticky CTA on phones: after the hero, hidden when the beta section is on screen
  const sticky = document.querySelector('.sticky-cta'), hero = document.querySelector('.hero'), beta = document.getElementById('beta');
  function stickyUpdate() {
    if (!sticky) return;
    const pastHero = hero.getBoundingClientRect().bottom < 0;
    const b = beta.getBoundingClientRect(), betaVisible = b.top < innerHeight && b.bottom > 0;
    sticky.classList.toggle('show', pastHero && !betaVisible);
  }
  addEventListener('scroll', onScroll, { passive: true }); onScroll();

  // Carousel, like the lesson map
  document.querySelectorAll('[data-carousel]').forEach(c => {
    const track = c.querySelector('.track'), slides = [...track.children], dots = c.querySelector('.dots');
    slides.forEach((s, i) => {
      const b = document.createElement('button');
      b.setAttribute('role', 'tab'); b.setAttribute('aria-label', s.querySelector('figcaption').textContent);
      b.onclick = () => go(i); dots.appendChild(b);
    });
    const go = i => { const s = slides[Math.max(0, Math.min(slides.length - 1, i))];
      track.scrollTo({ left: s.offsetLeft - (track.clientWidth - s.clientWidth) / 2, behavior: still ? 'auto' : 'smooth' }); };
    let current = 0;
    c.querySelectorAll('.arrow').forEach(a => a.onclick = () => go(current + +a.dataset.dir));
    const update = () => {
      const mid = track.scrollLeft + track.clientWidth / 2;
      let best = 0, bestD = Infinity;
      slides.forEach((s, i) => {
        const d = (s.offsetLeft + s.clientWidth / 2 - mid) / (s.clientWidth + 1);   // -1 … 1 per card
        if (Math.abs(d) < bestD) { bestD = Math.abs(d); best = i; }
        if (still) return;
        const t = Math.min(1, Math.abs(d));
        s.style.transform = `scale(${1 - (1 - NEIGHBOUR_SCALE) * t})`;
        s.style.filter = `saturate(${1 - (1 - NEIGHBOUR_SATURATION) * t})`;
      });
      current = best;
      [...dots.children].forEach((b, i) => b.setAttribute('aria-selected', i === best));
    };
    track.addEventListener('scroll', () => requestAnimationFrame(update), { passive: true });
    addEventListener('resize', update); update();
    addEventListener('load', () => go(0));
  });

  // "Send this to my iPad": phone visitors aren't on the iPad yet
  const share = document.querySelector('[data-share]'), note = document.querySelector('[data-share-note]');
  if (share) share.onclick = async () => {
    const data = { title: 'Rokko — chess for autistic children (iPad beta)', url: 'https://testflight.apple.com/join/FBrUsJDh' };
    try { if (navigator.share) { await navigator.share(data); return; } } catch { return; }
    try { await navigator.clipboard.writeText(data.url); note.hidden = false; } catch { location.href = data.url; }
  };
})();
