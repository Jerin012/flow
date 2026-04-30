(function () {
  'use strict';

  var totalMs = 0;
  var remainingMs = 0;
  var focusMs = 0;
  var ticker = null;
  var syncTicker = null;
  var isPaused = false;
  var sessionLive = false;
  var sessionStart = null;

  var awayAt = null;
  var absenceLog = [];
  var modalOpen = false;
  var _awayStart = null;
  var _awayEnd = null;
  var _awayMs = 0;

  var wavePoints = [];
  var rafId = null;
  var insightTicker = null;

  var insights = [
    'Your heart rate variability indicates high focus. This is an ideal time for complex problem solving.',
    "You're in a steady flow state. Avoid context switching to protect your momentum.",
    'Peak concentration window. Prioritise your hardest task right now.',
    'Flow state detected - silence notifications and stay in the zone.',
    'Sustained attention detected. This is a great time to tackle deep work.'
  ];
  var insightIdx = 0;

  function $id(id) { return document.getElementById(id); }
  function pad(n) { return n < 10 ? '0' + n : '' + n; }
  function timerCard() { return $id('nc-timer-card'); }
  function storageKey() {
    var id = focusSessionId();
    return id ? 'nc_timer_state_' + id : '';
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute('content') : '';
  }

  function setText(id, text) {
    var el = $id(id);
    if (el) el.textContent = text;
  }

  function show(id, display) {
    var el = $id(id);
    if (el) el.style.display = display || 'block';
  }

  function hide(id) {
    var el = $id(id);
    if (el) el.style.display = 'none';
  }

  function showSyncStatus(message, isError) {
    var el = $id('nc-sync-status');
    if (!el) return;

    el.textContent = message;
    el.classList.toggle('is-error', !!isError);
    el.classList.toggle('is-visible', !!message);
  }

  function timerEndpoint(name) {
    var card = timerCard();
    return card ? card.dataset[name] : '';
  }

  function focusSessionId() {
    var card = timerCard();
    return card ? card.dataset.focusSessionId : '';
  }

  function parsedResumeState() {
    var card = timerCard();
    if (!card || !card.dataset.resumeState) return {};

    try {
      return JSON.parse(card.dataset.resumeState);
    } catch (_error) {
      return {};
    }
  }

  function persistLocalState(statusOverride) {
    var key = storageKey();
    if (!key || !window.localStorage) return;

    try {
      window.localStorage.setItem(key, JSON.stringify({
        status: statusOverride || (isPaused ? 'paused' : 'active'),
        started_at: sessionStart ? sessionStart.toISOString() : '',
        last_synced_at: new Date().toISOString(),
        planned_duration_minutes: Math.round(totalMs / 60000),
        state: {
          total_ms: totalMs,
          remaining_ms: remainingMs,
          focus_ms: focusMs,
          absence_log: absenceLog
        }
      }));
    } catch (_error) {
      return;
    }
  }

  function clearLocalState() {
    var key = storageKey();
    if (!key || !window.localStorage) return;

    try {
      window.localStorage.removeItem(key);
    } catch (_error) {
      return;
    }
  }

  function localResumeState() {
    var key = storageKey();
    if (!key || !window.localStorage) return {};

    try {
      return JSON.parse(window.localStorage.getItem(key) || '{}');
    } catch (_error) {
      return {};
    }
  }

  function submitSessionForm() {
    var form = $id('hidden-activity-form');
    if (form && typeof form.requestSubmit === 'function') {
      form.requestSubmit();
      return;
    }

    var trigger = $id('submit-trigger');
    if (trigger) trigger.click();
  }

  function fetchJson(url, body) {
    return fetch(url, {
      method: 'PATCH',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken()
      },
      body: JSON.stringify(body)
    }).then(function (response) {
      return response.json().then(function (data) {
        if (!response.ok) throw data;
        return data;
      });
    });
  }

  function currentTimerState(statusOverride) {
    return {
      timer: {
        status: statusOverride || (isPaused ? 'paused' : 'active'),
        started_at: sessionStart ? sessionStart.toISOString() : '',
        planned_duration_minutes: Math.round(totalMs / 60000),
        elapsed_focus_ms: focusMs,
        elapsed_break_ms: absenceLog.reduce(function (sum, entry) {
          return sum + ((entry.type === 'break' ? entry.durationMs : 0) || 0);
        }, 0),
        state: JSON.stringify({
          total_ms: totalMs,
          remaining_ms: remainingMs,
          focus_ms: focusMs,
          absence_log: absenceLog
        })
      }
    };
  }

  function syncSession(statusOverride, options) {
    var url = timerEndpoint('syncUrl');
    if (!url || !focusSessionId()) return Promise.resolve();

    options = options || {};

    persistLocalState(statusOverride);

    return fetchJson(url, currentTimerState(statusOverride))
      .then(function () {
        if (options.silent) return;
        showSyncStatus('Session saved', false);
      })
      .catch(function () {
        showSyncStatus('Session sync failed', true);
      });
  }

  function activateSession() {
    var url = timerEndpoint('activateUrl');
    if (!url || !focusSessionId()) return Promise.resolve();

    persistLocalState('active');

    return fetchJson(url, currentTimerState('active'))
      .then(function () {
        showSyncStatus('Session active', false);
      })
      .catch(function () {
        showSyncStatus('Could not activate session', true);
      });
  }

  function resetSessionState() {
    var url = timerEndpoint('resetUrl');
    if (!url || !focusSessionId()) return Promise.resolve();

    clearLocalState();

    return fetchJson(url, {})
      .then(function () {
        showSyncStatus('Session reset', false);
      })
      .catch(function () {
        showSyncStatus('Could not reset session', true);
      });
  }

  function renderTimer() {
    var seconds = Math.max(0, Math.round(remainingMs / 1000));
    var minutes = Math.floor(seconds / 60);
    var remainder = seconds % 60;

    var disp = $id('timer-display');
    if (disp) {
      disp.textContent = pad(minutes) + ':' + pad(remainder);
      disp.classList.toggle('is-paused', isPaused);
    }

    if (totalMs > 0) {
      var elapsed = totalMs - remainingMs;
      var pct = Math.min(99, Math.round(6 + (elapsed / totalMs) * 92));
      setText('flow-pct', pct + '%');
    }
  }

  function updatePauseButton() {
    var btn = $id('pause-btn');
    if (!btn) return;

    btn.textContent = isPaused ? 'Resume Session' : 'Pause Session';
    btn.classList.toggle('is-paused', isPaused);
  }

  function showActiveView() {
    hide('timer-setup');
    show('timer-active', 'block');
    show('nc-noise-card', 'flex');
    show('nc-cta-row', 'grid');
    show('nc-insight', 'block');

    var flowCard = $id('flow-card');
    if (flowCard) {
      flowCard.style.display = 'block';
      setTimeout(function () { flowCard.classList.add('visible'); }, 40);
    }

    updatePauseButton();
    renderTimer();
  }

  function resetUiOnly() {
    clearInterval(ticker);
    clearInterval(syncTicker);
    clearInterval(insightTicker);
    cancelAnimationFrame(rafId);

    sessionLive = false;
    isPaused = false;
    totalMs = 0;
    remainingMs = 0;
    focusMs = 0;
    sessionStart = null;
    absenceLog = [];
    awayAt = null;
    modalOpen = false;
    clearLocalState();

    hide('timer-active');
    show('timer-setup', 'flex');
    hide('nc-noise-card');
    hide('nc-cta-row');
    hide('nc-insight');

    var flowCard = $id('flow-card');
    if (flowCard) {
      flowCard.classList.remove('visible');
      flowCard.style.display = 'none';
    }

    var disp = $id('timer-display');
    if (disp) disp.classList.remove('is-paused');

    updatePauseButton();
    showSyncStatus('', false);
  }

  function startTicker() {
    clearInterval(ticker);
    clearInterval(syncTicker);

    ticker = setInterval(function () {
      if (!sessionLive || isPaused) return;

      remainingMs -= 1000;
      focusMs += 1000;
      persistLocalState();
      renderTimer();

      if (remainingMs <= 0) {
        remainingMs = 0;
        renderTimer();
        window.ncFinishSession();
      }
    }, 1000);

    syncTicker = setInterval(function () {
      if (!sessionLive) return;
      syncSession(null, { silent: true });
    }, 60000);
  }

  function updateInsight() {
    var el = $id('insight-text');
    if (!el) return;

    el.style.opacity = '0';
    setTimeout(function () {
      el.textContent = insights[insightIdx++ % insights.length];
      el.style.opacity = '1';
    }, 400);
  }

  function startInsightCycle() {
    clearInterval(insightTicker);
    updateInsight();
    insightTicker = setInterval(updateInsight, 20000);
  }

  function initWave() {
    var canvas = $id('flow-canvas');
    if (!canvas) return;

    var ctx = canvas.getContext('2d');
    wavePoints = [];
    for (var i = 0; i < 80; i++) {
      wavePoints.push(0.3 + Math.random() * 0.35);
    }

    function draw() {
      var width = canvas.offsetWidth || 600;
      var height = canvas.offsetHeight || 130;
      canvas.width = width;
      canvas.height = height;
      ctx.clearRect(0, 0, width, height);

      var now = Date.now();
      var base = isPaused
        ? 0.42
        : 0.35 + Math.random() * 0.28 + Math.sin(now / 900) * 0.07;

      wavePoints.push(base);
      if (wavePoints.length > 120) wavePoints.shift();

      var step = width / (wavePoints.length - 1);
      var fillGrad = ctx.createLinearGradient(0, 0, 0, height);
      fillGrad.addColorStop(0, 'rgba(126,200,249,0.09)');
      fillGrad.addColorStop(1, 'rgba(126,200,249,0)');

      ctx.beginPath();
      wavePoints.forEach(function (v, idx) {
        var x = idx * step;
        var y = height * (1 - v);
        idx === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fillStyle = fillGrad;
      ctx.fill();

      var lineGrad = ctx.createLinearGradient(0, 0, width, 0);
      lineGrad.addColorStop(0, 'rgba(126,200,249,0)');
      lineGrad.addColorStop(0.25, 'rgba(126,200,249,0.35)');
      lineGrad.addColorStop(1, 'rgba(126,200,249,0.9)');

      ctx.beginPath();
      wavePoints.forEach(function (v, idx) {
        var x = idx * step;
        var y = height * (1 - v);
        idx === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });
      ctx.strokeStyle = lineGrad;
      ctx.lineWidth = 1.5;
      ctx.shadowColor = 'rgba(126,200,249,0.5)';
      ctx.shadowBlur = 8;
      ctx.stroke();
      ctx.shadowBlur = 0;

      var lx = (wavePoints.length - 1) * step;
      var ly = height * (1 - wavePoints[wavePoints.length - 1]);
      ctx.beginPath();
      ctx.arc(lx, ly, 3.5, 0, Math.PI * 2);
      ctx.fillStyle = '#7ec8f9';
      ctx.shadowColor = 'rgba(126,200,249,0.8)';
      ctx.shadowBlur = 12;
      ctx.fill();
      ctx.shadowBlur = 0;

      rafId = requestAnimationFrame(draw);
    }

    cancelAnimationFrame(rafId);
    draw();
  }

  function restorePersistedSession() {
    var serverPayload = parsedResumeState();
    var localPayload = localResumeState();
    var payload = serverPayload;

    if (localPayload && localPayload.status) {
      var localSyncedAt = localPayload.last_synced_at ? new Date(localPayload.last_synced_at).getTime() : 0;
      var serverSyncedAt = serverPayload && serverPayload.last_synced_at ? new Date(serverPayload.last_synced_at).getTime() : 0;

      if (!serverPayload.status || localSyncedAt > serverSyncedAt) {
        payload = localPayload;
      }
    }

    if (!payload || !payload.state || !payload.status) return;

    var state = payload.state || {};
    totalMs = Number(state.total_ms || 0);
    remainingMs = Number(state.remaining_ms || 0);
    focusMs = Number(state.focus_ms || 0);
    absenceLog = state.absence_log || [];
    sessionStart = payload.started_at ? new Date(payload.started_at) : new Date();
    isPaused = payload.status === 'paused';
    sessionLive = payload.status === 'active' || payload.status === 'paused';

    if (!sessionLive || totalMs <= 0) return;

    if (!isPaused && payload.last_synced_at) {
      var driftMs = Date.now() - new Date(payload.last_synced_at).getTime();
      var elapsedSinceSync = Math.max(0, Math.min(driftMs, remainingMs));
      remainingMs = Math.max(0, remainingMs - elapsedSinceSync);
      focusMs += elapsedSinceSync;
    }

    var minutesInput = $id('minutes-input');
    if (minutesInput && totalMs > 0) {
      minutesInput.value = Math.max(1, Math.round(totalMs / 60000));
    }

    var startField = $id('form-start-time');
    if (startField && sessionStart) startField.value = sessionStart.toISOString();

    var durationField = $id('form-duration');
    if (durationField && totalMs > 0) durationField.value = Math.max(1, Math.round(totalMs / 60000));

    showActiveView();
    initWave();
    startInsightCycle();
    startTicker();
    persistLocalState(payload.status);
    syncSession(null, { silent: true });

    if (remainingMs <= 0) {
      window.ncFinishSession();
    } else {
      showSyncStatus('Resumed saved session', false);
    }
  }

  function bindActionButtons() {
    var finishBtn = $id('finish-btn');
    if (finishBtn && !finishBtn.dataset.bound) {
      finishBtn.addEventListener('click', window.ncFinishSession);
      finishBtn.dataset.bound = 'true';
    }
  }

  window.ncStartSession = function () {
    var inp = $id('minutes-input');
    var mins = Math.max(1, parseInt(inp ? inp.value : '25', 10) || 25);

    totalMs = mins * 60 * 1000;
    remainingMs = totalMs;
    focusMs = 0;
    isPaused = false;
    sessionLive = true;
    sessionStart = new Date();
    absenceLog = [];

    var startField = $id('form-start-time');
    if (startField) startField.value = sessionStart.toISOString();

    var durationField = $id('form-duration');
    if (durationField) durationField.value = mins;

    var focusField = $id('form-focus-ms');
    if (focusField) focusField.value = 0;

    var sessionDataField = $id('form-session-data');
    if (sessionDataField) sessionDataField.value = JSON.stringify({ absenceLog: [] });

    showActiveView();
    initWave();
    startInsightCycle();
    startTicker();
    persistLocalState('active');
    activateSession();
  };

  window.ncTogglePause = function () {
    if (!sessionLive) return;

    isPaused = !isPaused;
    updatePauseButton();
    renderTimer();
    persistLocalState(isPaused ? 'paused' : 'active');
    syncSession(isPaused ? 'paused' : 'active');
  };

  window.ncResetSession = function () {
    if (!confirm('Reset the current session?')) return;

    resetSessionState().finally(resetUiOnly);
  };

  window.ncFinishSession = function () {
    if (!sessionLive) return;

    clearInterval(ticker);
    clearInterval(syncTicker);
    clearInterval(insightTicker);
    cancelAnimationFrame(rafId);

    sessionLive = false;
    isPaused = false;
    clearLocalState();

    var endTime = new Date();
    var durationMinutes = Math.max(1, Math.round((totalMs - remainingMs) / 60000));

    var fields = {
      'form-end-time': endTime.toISOString(),
      'form-duration': durationMinutes,
      'form-focus-ms': focusMs,
      'form-session-data': JSON.stringify({ absenceLog: absenceLog })
    };

    Object.keys(fields).forEach(function (key) {
      var el = $id(key);
      if (el) el.value = fields[key];
    });

    showSyncStatus('Saving completed session...', false);
    submitSessionForm();
  };

  window.ncHandleAbsence = function (type) {
    var productive = type !== 'break';

    if (!productive) {
      focusMs = Math.max(0, focusMs - _awayMs);
    }

    absenceLog.push({
      start: new Date(_awayStart || Date.now()).toISOString(),
      end: new Date(_awayEnd || Date.now()).toISOString(),
      durationMs: _awayMs,
      type: type,
      productive: productive
    });

    var backdrop = $id('nc-backdrop');
    if (backdrop) backdrop.classList.remove('open');

    modalOpen = false;
    _awayStart = null;
    _awayEnd = null;
    _awayMs = 0;

    persistLocalState();
    syncSession(null, { silent: true });
  };

  function initPage() {
    var card = timerCard();
    if (!card || card.dataset.initialized === 'true') return;

    card.dataset.initialized = 'true';
    bindActionButtons();
    restorePersistedSession();
  }

  document.addEventListener('visibilitychange', function () {
    if (!sessionLive) return;

    if (document.hidden) {
      if (!isPaused) awayAt = Date.now();
      syncSession(null, { silent: true });
      return;
    }

    if (awayAt !== null && !isPaused && !modalOpen) {
      _awayStart = awayAt;
      _awayEnd = Date.now();
      _awayMs = _awayEnd - _awayStart;

      var sec = Math.round(_awayMs / 1000);
      var label = sec < 60
        ? sec + ' second' + (sec !== 1 ? 's' : '')
        : Math.round(sec / 60) + ' minute' + (Math.round(sec / 60) !== 1 ? 's' : '');

      setText('away-time', label);

      var backdrop = $id('nc-backdrop');
      if (backdrop) backdrop.classList.add('open');

      modalOpen = true;
    }

    awayAt = null;
  });

  window.addEventListener('beforeunload', function () {
    if (!sessionLive) return;
    syncSession(null, { silent: true });
  });

  document.addEventListener('DOMContentLoaded', initPage);
  document.addEventListener('turbo:load', initPage);
})();
