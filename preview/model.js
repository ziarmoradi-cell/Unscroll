(function (root) {
  'use strict';
  const key = 'unscroll.preview.v2';
  const fresh = () => ({ version: 2, profile: { name: '', birthday: '', configured: false, mode: 'normal', goal: 20, ratio: 2, plankRatio: 30, evening: '21:00', wake: '07:00' }, apps: ['Instagram', 'TikTok', 'YouTube'], stepDays: {}, bank: 0, session: null, workouts: [], usage: [], emergency: 0, friends: [], challenge: null, alarm: false });
  const integer = (n, min = 0, max = 1000000) => Number.isInteger(n) && n >= min && n <= max;
  function valid(s) { return s && s.version === 2 && integer(s.bank) && integer(s.emergency) && Array.isArray(s.apps) && s.apps.every(a => typeof a === 'string') && Array.isArray(s.workouts) && Array.isArray(s.usage) && Array.isArray(s.friends) && s.profile && integer(s.profile.ratio, 1, 5) && integer(s.profile.plankRatio, 5, 60) && integer(s.profile.goal, 1, 200) && (!s.session || (integer(s.session.total, 1, 30) && integer(s.session.used) && s.session.used <= s.session.total)); }
  function load(storage) { try { const s = JSON.parse(storage.getItem(key)); return valid(s) ? s : fresh(); } catch { return fresh(); } }
  function save(storage, state) { storage.setItem(key, JSON.stringify(state)); }
  function reward(state, exercise, amount) { if (!integer(amount, 1, 10000)) throw Error('Bitte eine gültige Übungsmenge wählen.'); return exercise === 'plank' ? Math.floor(amount / 30) * state.profile.ratio : amount * state.profile.ratio; }
  function earn(state, exercise, amount, id = crypto.randomUUID(), date = new Date().toISOString()) {
    if (!['pushups', 'squats', 'plank', 'situps'].includes(exercise)) throw Error('Unbekannte Übung.');
    if (state.workouts.some(w => w.id === id)) return 0;
    const minutes = reward(state, exercise, amount);
    state.workouts.push({ id, date, exercise, amount, minutes }); state.bank += minutes; return minutes;
  }
  function migrate(s) {
    s.profile.mode ||= ({1:'hard',2:'normal',3:'beginner'})[s.profile.ratio] || 'normal';
    s.profile.ratio = {beginner:3,normal:2,hard:1}[s.profile.mode] || 2;
    s.profile.plankRatio = 30;
    s.profile.configured ??= Boolean(s.profile.name);
    s.stepDays ||= {};
    return s;
  }
  function stepDay(state, date = new Date()) { return state.stepDays?.[day(date)] || {steps:0,claimedBlocks:0,minutes:0,date:new Date(date).toISOString()}; }
  function updateSteps(state, total, date = new Date()) {
    if (!integer(total,0,200000)) throw Error('Ungültige Schrittzahl.');
    state.stepDays ||= {}; const record = stepDay(state,date);
    record.steps = Math.max(record.steps,total); state.stepDays[day(date)] = record;
  }
  function claimSteps(state, date = new Date()) {
    const record = stepDay(state,date), blocks = Math.max(0,Math.floor(record.steps/1000)-record.claimedBlocks);
    const minutes = blocks * state.profile.ratio;
    record.claimedBlocks += blocks; record.minutes += minutes; state.bank += minutes;
    state.stepDays ||= {}; state.stepDays[day(date)] = record; return minutes;
  }
  function start(state, emergency = false) {
    if (state.session) throw Error('Du hast bereits eine laufende Freigabe.');
    if (!state.apps.length) throw Error('Wähle zuerst mindestens eine App aus.');
    const total = emergency ? 5 : Math.min(30, state.bank);
    if (!total) throw Error('Verdiene zuerst ein paar Minuten mit Bewegung.');
    const session = { id: crypto.randomUUID(), start: new Date().toISOString(), total, used: 0, emergency, end: null };
    if (!emergency) state.bank -= total; else state.emergency++;
    state.usage.push(session); state.session = session.id;
    // Store a stable id, never duplicate a mutable session object in persisted JSON.
    return session;
  }
  function current(state) { return state.usage.find(u => u.id === state.session) || null; }
  function consume(state, amount) {
    const session = current(state);
    if (!session) throw Error('Die Apps sind gesperrt. Verdiene zuerst Zeit.');
    if (!integer(amount, 1, 30)) throw Error('Ungültige Nutzungsdauer.');
    const used = Math.min(amount, session.total - session.used); session.used += used;
    if (session.used >= session.total) stop(state);
    return used;
  }
  function stop(state) { const session = current(state); if (session) session.end = new Date().toISOString(); state.session = null; }
  function day(date) { const d = new Date(date); return [d.getFullYear(), d.getMonth(), d.getDate()].join('-'); }
  function streak(state, now = new Date()) {
    const days = new Set(state.workouts.map(w => day(w.date)));
    let d = new Date(now), total = 0;
    if (!days.has(day(d))) d.setDate(d.getDate() - 1);
    while (days.has(day(d))) { total++; d.setDate(d.getDate() - 1); }
    return total;
  }
  function week(state, now = new Date()) {
    const start = new Date(now); start.setHours(0, 0, 0, 0); start.setDate(start.getDate() - (start.getDay() + 6) % 7);
    const end = new Date(start); end.setDate(end.getDate() + 7);
    const inside = d => new Date(d) >= start && new Date(d) < end;
    const workouts = [...state.workouts, ...Object.values(state.stepDays || {}).map(s=>({exercise:'steps',amount:s.steps,minutes:s.minutes,date:s.date}))].filter(w => inside(w.date)); const usage = state.usage.filter(u => inside(u.start));
    return { start, workouts, earned: workouts.reduce((a, w) => a + w.minutes, 0), used: usage.reduce((a, u) => a + u.used, 0), emergency: usage.filter(u => u.emergency).length };
  }
  // Additional checks for the stable session-id representation.
  const validate = s => { if (!s || (s.session !== null && typeof s.session !== 'string')) return false; return valid({ ...s, session: null }) && (!s.session || s.usage.some(u => u.id === s.session && integer(u.total, 1, 30) && integer(u.used) && u.used <= u.total)); };
  const api = { key, fresh, load: storage => { try { const s = JSON.parse(storage.getItem(key)); return validate(s) ? migrate(s) : fresh(); } catch { return fresh(); } }, save, reward, earn, stepDay, updateSteps, claimSteps, start, current, consume, stop, day, streak, week, valid: validate };
  if (typeof module !== 'undefined') module.exports = api; else root.Unscroll = api;
})(globalThis);
