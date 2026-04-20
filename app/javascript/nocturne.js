/* ═══════════════════════════════════════════════════
   nocturne.js
   Place in: app/assets/javascripts/nocturne.js
   (or app/javascript/nocturne.js for Webpacker/esbuild)
   ═══════════════════════════════════════════════════
 
   Logic summary
   ─────────────
   • ncStartSession()  — reads minutes input, starts countdown & waveform
   • ncTogglePause()   — INTENTIONAL pause: timer stops, no modal on return
   • ncResetSession()  — resets everything back to setup state
   • ncFinishSession() — populates hidden form fields, submits form
   • ncHandleAbsence() — called by modal buttons (work / browser / break)
 
   Visibility rule 
   ───────────────
   User leaves tab WITHOUT clicking Pause → timer keeps running in the
   background. On return → modal appears asking Work / Browser / Break.
     • Work / Browser → time is counted as productive (focusMs unchanged)
     • Break          → away time is SUBTRACTED from focusMs
   User clicks Pause first → timer stops, no modal shown on return.
═══════════════════════════════════════════════════ */
 
(function () {
  'use strict';
 
  /* ── State ────────────────────────────────────── */
  var totalMs      = 0;
  var remainingMs  = 0;
  var focusMs      = 0;
  var ticker       = null;
  var isPaused     = false;    // intentional pause only
  var sessionLive  = false;
  var sessionStart = null;
 
  /* absence */
  var awayAt       = null;     // timestamp (ms) when tab was hidden
  var absenceLog   = [];
  var modalOpen    = false;
  var _awayStart   = null;
  var _awayEnd     = null;
  var _awayMs      = 0;
 
  /* waveform */
  var wavePoints   = [];
  var rafId        = null;
 
  /* insights */
  var insights = [
    'Your heart rate variability indicates high focus. This is an ideal time for complex problem solving.',
    "You're in a steady flow state. Avoid context switching to protect your momentum.",
    'Peak concentration window. Prioritise your hardest task right now.',
    'Flow state detected — silence notifications and stay in the zone.',
    'Sustained attention detected. This is a great time to tackle deep work.'
  ];
  var insightIdx = 0;
 
  /* ── Helpers ──────────────────────────────────── */
  function $id(id)  { return document.getElementById(id); }
  function pad(n)   { return n < 10 ? '0' + n : '' + n; }
  function submitSessionForm() {
    var form = $id('hidden-activity-form');
    if (form && typeof form.requestSubmit === 'function') {
      form.requestSubmit();
      return;
    }

    var trigger = $id('submit-trigger');
    if (trigger) trigger.click();
  }

  function show(id, display) {
    var el = $id(id);
    if (el) el.style.display = display || 'block';
  }
  function hide(id) {
    var el = $id(id);
    if (el) el.style.display = 'none';
  }
 
  /* ── Start ────────────────────────────────────── */
  window.ncStartSession = function () {
    var inp  = $id('minutes-input');
    var mins = Math.max(1, parseInt(inp ? inp.value : '25') || 25);
 
    totalMs      = mins * 60 * 1000;
    remainingMs  = totalMs;
    focusMs      = 0;
    isPaused     = false;
    sessionLive  = true;
    sessionStart = new Date();
    absenceLog   = [];
 
    var fsEl = $id('form-start-time');
    if (fsEl) fsEl.value = sessionStart.toISOString();
    var durationEl = $id('form-duration');
    if (durationEl) durationEl.value = mins;
    var focusEl = $id('form-focus-ms');
    if (focusEl) focusEl.value = 0;
    var sessionDataEl = $id('form-session-data');
    if (sessionDataEl) sessionDataEl.value = JSON.stringify({ absenceLog: [] });
 
    /* swap views */
    hide('timer-setup');
    show('timer-active', 'block');
    show('nc-noise-card', 'flex');
    show('nc-cta-row', 'grid');
    show('nc-insight', 'block');
 
    /* flow card */
    var fc = $id('flow-card');
    if (fc) {
      fc.style.display = 'block';
      setTimeout(function () { fc.classList.add('visible'); }, 40);
    }
 
    renderTimer();
    startTicker();
    initWave();
    startInsightCycle();
 
    /* wire finish button */
    var fb = $id('finish-btn');
    if (fb) fb.addEventListener('click', window.ncFinishSession);
  };
 
  /* ── Ticker ───────────────────────────────────── */
  function startTicker() {
    clearInterval(ticker);
    ticker = setInterval(function () {
      if (!sessionLive || isPaused) return;
      remainingMs -= 1000;
      focusMs     += 1000;
      renderTimer();
      if (remainingMs <= 0) {
        remainingMs = 0;
        clearInterval(ticker);
        renderTimer();
        window.ncFinishSession();
      }
    }, 1000);
  }
 
  function renderTimer() {
    var s   = Math.max(0, Math.round(remainingMs / 1000));
    var m   = Math.floor(s / 60);
    var sec = s % 60;
 
    var disp = $id('timer-display');
    if (disp) {
      disp.textContent = pad(m) + ':' + pad(sec);
      disp.classList.toggle('is-paused', isPaused);
    }
 
    /* flow % */
    if (totalMs > 0) {
      var elapsed = totalMs - remainingMs;
      var pct     = Math.min(99, Math.round(6 + (elapsed / totalMs) * 92));
      var pctEl   = $id('flow-pct');
      if (pctEl) pctEl.textContent = pct + '%';
    }
  }
 
  /* ── Pause / Resume ───────────────────────────── */
  window.ncTogglePause = function () {
    isPaused = !isPaused;
 
    var btn  = $id('pause-btn');
    var disp = $id('timer-display');
 
    if (isPaused) {
      if (btn)  { btn.textContent = 'Resume Session'; btn.classList.add('is-paused'); }
      if (disp) { disp.classList.add('is-paused'); }
    } else {
      if (btn)  { btn.textContent = 'Pause Session';  btn.classList.remove('is-paused'); }
      if (disp) { disp.classList.remove('is-paused'); }
    }
  };
 
  /* ── Reset ────────────────────────────────────── */
  window.ncResetSession = function () {
    if (!confirm('Reset the current session?')) return;
 
    clearInterval(ticker);
    cancelAnimationFrame(rafId);
    sessionLive = false;
    isPaused    = false;
 
    hide('timer-active');
    show('timer-setup', 'flex');
    hide('nc-noise-card');
    hide('nc-cta-row');
    hide('nc-insight');
 
    var fc = $id('flow-card');
    if (fc) { fc.classList.remove('visible'); fc.style.display = 'none'; }
 
    var btn = $id('pause-btn');
    if (btn) { btn.textContent = 'Pause Session'; btn.classList.remove('is-paused'); }
 
    var disp = $id('timer-display');
    if (disp) disp.classList.remove('is-paused');
  };
 
  /* ── Finish ───────────────────────────────────── */
  window.ncFinishSession = function () {
    if (!sessionLive) return;
    clearInterval(ticker);
    cancelAnimationFrame(rafId);

    var endTime = new Date();
    var durMins = Math.max(1, Math.round((totalMs - remainingMs) / 60000));

    var fields = {
      'form-end-time':     endTime.toISOString(),
      'form-duration':     durMins,
      'form-focus-ms':     focusMs,
      'form-session-data': JSON.stringify({ absenceLog: absenceLog })
    };
 
    for (var key in fields) {
      var el = $id(key);
      if (el) el.value = fields[key];
    }
 
    submitSessionForm();
  };
 
  /* ── Take Note ────────────────────────────────── */
  window.ncTakeNote = function () {
    var note = prompt('Quick note for this session:');
    if (note && note.trim()) {
      console.info('[Nocturne] Note:', note.trim());
    }
  };
 
  /* ── Insights ─────────────────────────────────── */
  function startInsightCycle() {
    updateInsight();
    setInterval(updateInsight, 20000);
  }
 
  function updateInsight() {
    var el = $id('insight-text');
    if (!el) return;
    el.style.opacity = '0';
    setTimeout(function () {
      el.textContent  = insights[insightIdx++ % insights.length];
      el.style.opacity = '1';
    }, 400);
  }
 
  /* ── Waveform ─────────────────────────────────── */
  function initWave() {
    var canvas = $id('flow-canvas');
    if (!canvas) return;
    var ctx = canvas.getContext('2d');
 
    wavePoints = [];
    for (var i = 0; i < 80; i++) {
      wavePoints.push(0.3 + Math.random() * 0.35);
    }
 
    function draw() {
      var W = canvas.offsetWidth  || 600;
      var H = canvas.offsetHeight || 130;
      canvas.width  = W;
      canvas.height = H;
      ctx.clearRect(0, 0, W, H);
 
      /* new data point */
      var t    = Date.now();
      var base = isPaused
        ? 0.42
        : 0.35 + Math.random() * 0.28 + Math.sin(t / 900) * 0.07;
      wavePoints.push(base);
      if (wavePoints.length > 120) wavePoints.shift();
 
      var pts  = wavePoints;
      var step = W / (pts.length - 1);
 
      /* fill under curve */
      var fillGrad = ctx.createLinearGradient(0, 0, 0, H);
      fillGrad.addColorStop(0,  'rgba(126,200,249,0.09)');
      fillGrad.addColorStop(1,  'rgba(126,200,249,0)');
      ctx.beginPath();
      pts.forEach(function (v, i) {
        var x = i * step, y = H * (1 - v);
        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });
      ctx.lineTo(W, H);
      ctx.lineTo(0, H);
      ctx.closePath();
      ctx.fillStyle = fillGrad;
      ctx.fill();
 
      /* stroke */
      var lineGrad = ctx.createLinearGradient(0, 0, W, 0);
      lineGrad.addColorStop(0,    'rgba(126,200,249,0)');
      lineGrad.addColorStop(0.25, 'rgba(126,200,249,0.35)');
      lineGrad.addColorStop(1,    'rgba(126,200,249,0.9)');
 
      ctx.beginPath();
      pts.forEach(function (v, i) {
        var x = i * step, y = H * (1 - v);
        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });
      ctx.strokeStyle = lineGrad;
      ctx.lineWidth   = 1.5;
      ctx.shadowColor = 'rgba(126,200,249,0.5)';
      ctx.shadowBlur  = 8;
      ctx.stroke();
      ctx.shadowBlur  = 0;
 
      /* live dot */
      var lx = (pts.length - 1) * step;
      var ly = H * (1 - pts[pts.length - 1]);
      ctx.beginPath();
      ctx.arc(lx, ly, 3.5, 0, Math.PI * 2);
      ctx.fillStyle   = '#7ec8f9';
      ctx.shadowColor = 'rgba(126,200,249,0.8)';
      ctx.shadowBlur  = 12;
      ctx.fill();
      ctx.shadowBlur  = 0;
 
      rafId = requestAnimationFrame(draw);
    }
 
    draw();
  }
 
  /* ── Page Visibility API ──────────────────────── */
  /*
     KEY RULE:
       - intentional Pause  → timer stops, NO modal on return
       - tab hidden WITHOUT pausing → timer keeps running, modal on return
  */
  document.addEventListener('visibilitychange', function () {
    if (!sessionLive) return;
 
    if (document.hidden) {
      /* record departure only if NOT intentionally paused */
      if (!isPaused) {
        awayAt = Date.now();
      }
    } else {
      /* returned — show modal only if there's an unhandled departure */
      if (awayAt !== null && !isPaused && !modalOpen) {
        _awayStart = awayAt;
        _awayEnd   = Date.now();
        _awayMs    = _awayEnd - _awayStart;
 
        var sec   = Math.round(_awayMs / 1000);
        var label = sec < 60
          ? sec + ' second' + (sec !== 1 ? 's' : '')
          : Math.round(sec / 60) + ' minute' + (Math.round(sec / 60) !== 1 ? 's' : '');
 
        var awayEl = $id('away-time');
        if (awayEl) awayEl.textContent = label;
 
        var backdrop = $id('nc-backdrop');
        if (backdrop) backdrop.classList.add('open');
 
        modalOpen = true;
      }
      awayAt = null;
    }
  });
 
  /* ── Modal choice ─────────────────────────────── */
  window.ncHandleAbsence = function (type) {
    var productive = (type !== 'break');
 
    /* break → subtract away time from productive focus */
    if (!productive) {
      focusMs = Math.max(0, focusMs - _awayMs);
    }
 
    absenceLog.push({
      start:      new Date(_awayStart || Date.now()).toISOString(),
      end:        new Date(_awayEnd   || Date.now()).toISOString(),
      durationMs: _awayMs,
      type:       type,
      productive: productive
    });
 
    var backdrop = $id('nc-backdrop');
    if (backdrop) backdrop.classList.remove('open');
 
    modalOpen  = false;
    _awayStart = null;
    _awayEnd   = null;
    _awayMs    = 0;
  };
 
})();
 
