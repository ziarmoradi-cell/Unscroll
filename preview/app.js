'use strict';
const U = window.Unscroll;
let introPage = 0, introDraft = null;
let state = U.load(localStorage), screen = 'home', workout = null, toastTimer;
const $ = selector => document.querySelector(selector);
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const exercises = { pushups: {title:'Liegestütze',icon:'↗',unit:'Wiederholungen'}, squats: {title:'Squats',icon:'↓↑',unit:'Wiederholungen'}, plank: {title:'Plank',icon:'━',unit:'Sekunden'}, situps: {title:'Sit-ups',icon:'↶',unit:'Wiederholungen'} };
const navigation = [['home','◉','Heute'],['move','↗','Bewegen'],['report','▥','Rückblick'],['friends','♧','Gemeinsam'],['profile','◎','Profil']];
const content = $('#content'), dialog = $('#dialog');
function persist() { try { U.save(localStorage,state); } catch { toast('Dein Browser konnte den Fortschritt nicht speichern.'); } }
function toast(text) { $('#toast').textContent = text; $('#toast').classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(() => $('#toast').classList.remove('show'),3500); }
function heading(eye,title,sub,aside='') { return `<div class="heading"><div><div class="eyebrow">${eye}</div><h1>${title}</h1><p class="subtitle">${sub}</p></div>${aside}</div>`; }
function todayReps() { return state.workouts.filter(w => U.day(w.date) === U.day(new Date()) && w.exercise !== 'plank').reduce((n,w)=>n+w.amount,0); }
function exerciseCards() { return `<div class="exercises">${Object.entries(exercises).map(([id,e])=>`<button class="exercise" data-action="exercise" data-id="${id}"><div class="exercise-icon">${e.icon}</div><div class="exercise-title">${e.title}<span>↗</span></div><p>${id==='plank'?`30 Sekunden → ${state.profile.ratio} Min.`:`1 Wiederholung → ${state.profile.ratio} Min.`}</p></button>`).join('')}</div>`; }
function assistant() {
  if (new Date().getHours() >= Number(state.profile.evening.split(':')[0])) return ['Ein guter Abend beginnt offline.','Lege dein Handy außer Reichweite. Deine verdiente Zeit wartet – du musst sie heute nicht mehr nutzen.'];
  if (todayReps()>=state.profile.goal) return ['Dein Tagesziel ist geschafft.','Du hast heute schon etwas für dich getan. Jetzt ist auch eine Pause ohne Bildschirm ein guter nächster Schritt.'];
  return ['Kurz bewegen. Bewusst entscheiden.',`Noch ${Math.max(0,state.profile.goal-todayReps())} Wiederholungen bis zu deinem Tagesziel. Wähle eine Bewegung, die sich heute für dich gut anfühlt.`];
}
function home() {
  const session=U.current(state), goal=todayReps(), tip=assistant();
  return heading('DEINE ZEIT. DEINE ENTSCHEIDUNG.',`Hallo${state.profile.name?', '+esc(state.profile.name):''}.<br>Beweg etwas.`,'Kleine Bewegung. Bewusste Bildschirmzeit. Mehr für dich.',`<span class="pill">♨ &nbsp; ${U.streak(state)} Tage Streak</span>`)+
  `<div class="home-grid"><section class="card wallet"><div class="card-top"><span>◷ &nbsp; Dein gemeinsames Zeitkonto</span><span class="badge">${session?'Freigabe aktiv':'Bereit für Bewegung'}</span></div><div class="wallet-value">${state.bank}<span>Minuten bereit</span></div><p class="quiet">Für ${state.apps.length?esc(state.apps.join(', ')):'deine ausgewählten Apps'} – ein gemeinsames Konto.</p><div class="wallet-bottom"><button class="primary" data-action="${session?'usage':'start'}">${session?`${session.total-session.used} Min. testen ↗`:'Zeit nutzen ↗'}</button><span class="quiet">${session?`${session.used} von ${session.total} Minuten simuliert`:'Erst bewegen. Dann bewusst scrollen.'}</span></div></section>
  <section class="card"><div class="card-top"><span>⚑ &nbsp; Dein Tagesziel</span><button class="text-button" data-action="profile">Anpassen ↗</button></div><div class="goal-main"><div class="ring" style="--progress:${Math.min(360,goal/state.profile.goal*360)}deg"><div><strong>${goal}<small>von ${state.profile.goal} Wdh.</small></strong></div></div><div class="goal-copy"><strong>${goal>=state.profile.goal?'Geschafft!':'Ein guter Anfang.'}</strong><p>${goal?'Jede Wiederholung bringt dich weiter.':'Deine erste Bewegung macht den Unterschied.'}</p></div></div><div class="progress-caption">${Math.max(0,state.profile.goal-goal)} Wiederholungen bis zu deinem Ziel. Planks zählen separat.</div></section></div>
  ${stepsCard()}<div class="section-head"><h2>Verdiene dir eine Pause.</h2><button class="text-button" data-action="move">Alle Übungen ↗</button></div>${exerciseCards()}
  <div class="bottom-grid"><section class="card assistant"><span class="assistant-icon">✦</span> <span class="quiet">DEIN PERSÖNLICHER ASSISTENT</span><h3>${tip[0]}</h3><p>${tip[1]}</p><small>Auf deine Ziele und deinen Tagesverlauf abgestimmt.</small></section><section class="card"><div class="card-top"><span>▣ &nbsp; Deine Apps</span><button class="text-button" data-action="apps">Bearbeiten</button></div>${state.apps.length?state.apps.map(a=>`<div class="app-row"><span class="app-name"><span class="app-icon">${esc(a[0])}</span>${esc(a)}</span><span class="app-status">${session?'○ Freigegeben':'▣ Gesperrt'} · Demo</span></div>`).join(''):'<p class="empty">Wähle die Apps aus, die du bewusster nutzen möchtest.</p>'}<button class="text-button danger" data-action="emergency" ${session?'disabled':''}>Emergency · 5 Minuten Ausnahme</button></section></div>`;
}
function move() { return heading('BEWEGUNG STATT ENDLOSSCROLLEN.','Dein nächster<br>kleiner Schritt.','Du bestimmst die Übung. Dein Körper bestimmt das Tempo.')+`<p class="training-note">Die iPhone-Version nutzt die Kamera zur Bewegungserkennung. In dieser Vorschau kannst du erkannte Wiederholungen simulieren und den kompletten Ablauf ausprobieren.</p>${exerciseCards()}${stepsCard()}<div class="bottom-grid"><section class="card"><h3>So funktioniert’s</h3><div class="rows"><div class="row"><span>01 &nbsp; Übung auswählen</span><span>↗</span></div><div class="row"><span>02 &nbsp; Wiederholungen simulieren</span><span>↗</span></div><div class="row"><span>03 &nbsp; Zeit auf dein Konto buchen</span><span>✓</span></div></div></section><section class="card assistant"><h3>Deine Umrechnung</h3><p>${state.profile.ratio} Minute(n) pro Wiederholung.<br>${state.profile.ratio} Minuten pro 30 Sekunden Plank.</p><button class="text-button" data-action="profile">Im Profil anpassen ↗</button></section></div>`; }
function report() {
  const week=U.week(state), days=Array.from({length:7},(_,i)=>{const d=new Date(week.start);d.setDate(d.getDate()+i);return {label:['Mo','Di','Mi','Do','Fr','Sa','So'][i],minutes:week.workouts.filter(w=>U.day(w.date)===U.day(d)).reduce((a,w)=>a+w.minutes,0)}}), max=Math.max(10,...days.map(d=>d.minutes));
  return heading('DEIN FORTSCHRITT ZÄHLT.','Mehr bewegt.<br>Bewusster gescrollt.','Dein Rückblick auf diese Kalenderwoche. Alle Werte stammen aus deinen Aktionen in der Vorschau.')+`<div class="stats"><div class="stat"><strong>${week.earned}<small> Min.</small></strong><span>durch Bewegung verdient</span></div><div class="stat"><strong>${week.used}<small> Min.</small></strong><span>Nutzung simuliert</span></div><div class="stat"><strong>${week.emergency}</strong><span>Emergency-Ausnahmen</span></div></div><section class="card"><div class="card-top"><h2>Deine bewegte Woche</h2><span>Verdiente Minuten</span></div><div class="chart" aria-label="Verdiente Minuten nach Wochentag">${days.map(d=>`<div class="bar-column"><span>${d.minutes}</span><div class="bar" style="height:${d.minutes/max*145}px"></div><small>${d.label}</small></div>`).join('')}</div></section><div class="bottom-grid"><section class="card"><h2>Deine Übungen</h2><div class="rows">${Object.entries(exercises).map(([id,e])=>`<div class="row"><span>${e.title}</span><strong>${week.workouts.filter(w=>w.exercise===id).reduce((a,w)=>a+w.amount,0)} ${id==='plank'?'Sek.':'Wdh.'}</strong></div>`).join('')}</div></section><section class="card"><h2>Letzte Einheiten</h2>${week.workouts.length?`<div class="rows">${week.workouts.slice(-5).reverse().map(w=>`<div class="row"><span>${w.amount} ${exercises[w.exercise]?.title || 'Schritte'}</span><strong>+${w.minutes} Min.</strong></div>`).join('')}</div>`:'<p class="empty">Hier beginnt deine Geschichte – mit deiner ersten Bewegungseinheit.</p>'}</section></div>`;
}
function friends() {
  const myScore=state.workouts.filter(w=>w.exercise==='pushups').reduce((a,w)=>a+w.amount,0);
  const people=[{name:state.profile.name||'Du',score:myScore,you:true},...state.friends].sort((a,b)=>b.score-a.score);
  const challengeDays=state.challenge?new Set(state.workouts.filter(w=>new Date(w.date)>=new Date(state.challenge)&&new Date(w.date)<new Date(new Date(state.challenge).getTime()+7*86400000)).map(w=>U.day(w.date))).size:0;
  return heading('GEMEINSAM DRANBLEIBEN.','Ein bisschen<br>gegenseitiger Antrieb.','Hier probierst du Freunde und Vergleiche mit klar gekennzeichneten Demodaten aus.')+`<div class="profile-grid"><section class="card"><div class="card-top"><h2>Dein Freundeskreis</h2><span class="badge">Simulation</span></div><p class="hint">Keine echten Konten verbunden. Die iPhone-Version verwendet Game Center.</p>${people.map((p,i)=>`<div class="friend"><small>${i+1}</small><div class="avatar">${esc(p.name[0])}</div><div><strong>${esc(p.name)}${p.you?' · Du':''}</strong><small>${p.you?'Deine Vorschau-Werte':'Demo-Freund · Beispielwert'}</small></div><div class="score">${p.score}<small>Liegestütze</small></div></div>`).join('')}<button class="secondary full" style="margin-top:20px" data-action="friend">Demo-Freund hinzufügen +</button></section><section class="card assistant"><div class="eyebrow">DEINE 7-TAGE-CHALLENGE</div><h2>Eine Woche.<br>Jeden Tag ein kleiner Schritt.</h2><p class="hint">An sieben Tagen eine Einheit absolvieren. Dein Tempo zählt. Diese Challenge bleibt lokal.</p><div class="steps">${Array.from({length:7},(_,i)=>`<div class="step ${i<challengeDays?'done':''}">${i<challengeDays?'✓':i+1}</div>`).join('')}</div><button class="primary" data-action="challenge">${state.challenge?'Challenge läuft':'Challenge starten ↗'}</button><p class="hint">${state.challenge?`${challengeDays} von 7 Tagen geschafft.`:'Noch nicht gestartet.'}</p></section></div>`;
}
function profile() {
  const p=state.profile;
  return heading('PASSEND ZU DEINEM ALLTAG.','Dein Leben.<br>Deine Regeln.','Diese Angaben bleiben in deinem Browser. Du kannst sie jederzeit zurücksetzen.')+`<form id="profile-form"><div class="profile-grid"><section class="card"><h2>Das bist du</h2><label class="field">Vorname<input name="name" autocomplete="given-name" maxlength="40" value="${esc(p.name)}" placeholder="Wie heißt du?"></label><label class="field">Geburtsdatum<input name="birthday" type="date" max="${new Date().toISOString().slice(0,10)}" value="${esc(p.birthday)}"></label><p class="hint">In dieser Vorschau freiwillig. Dein Geburtstag wird nicht an Freunde weitergegeben.</p><h3 style="margin-top:24px">Dein Tagesziel</h3><label class="field">Wiederholungen pro Tag<input name="goal" type="number" min="1" max="200" required value="${p.goal}"></label><label class="field">Dein Modus<select name="mode">${[['beginner','Beginner · dreifach'],['normal','Normal · doppelt'],['hard','Schwierig · einfach']].map(([id,label])=>`<option value="${id}" ${p.mode===id?'selected':''}>${label}</option>`).join('')}</select></label><p class="hint">1 Wiederholung / 30 Sek. Plank / 1.000 Schritte → ${p.ratio} Min. Ein Wechsel gilt für neue Gutschriften. Vorhandenes Guthaben bleibt erhalten.</p><button class="primary" type="submit">Profil speichern ✓</button></section><div><section class="card"><h2>Ein ruhiger Abend</h2><label class="field">Zeit zum Abschalten<input name="evening" type="time" value="${esc(p.evening)}" required></label><p class="hint">Dein Assistent berücksichtigt diese Uhrzeit. Browser-Vorschau ohne Hintergrundbenachrichtigungen.</p><div class="inline-note">True Tone: iPhone-Einstellungen → Anzeige & Helligkeit → True Tone. Die App schaltet es nicht automatisch ein.</div></section><section class="card" style="margin-top:20px"><div class="card-top"><h2>Sanft in den Tag</h2><span class="badge">Tonvorschau</span></div><label class="field">Deine Aufwachzeit<input name="wake" type="time" value="${esc(p.wake)}" required></label><button class="secondary" type="button" data-action="sound">▷ Weckton anhören</button><p class="hint">Hier wird kein zuverlässiger Wecker gestellt. Der echte iPhone-Wecker verwendet AlarmKit ab iOS 26.</p></section></div></div></form><section class="card" style="margin-top:20px"><div class="card-top"><h2>Deine App-Auswahl</h2><button class="secondary" data-action="apps">Apps bearbeiten</button></div><p class="hint">${esc(state.apps.join(' · '))||'Keine Apps ausgewählt'} · gemeinsames Zeitkonto</p></section>`;
}
function render() {
  screen=location.hash.slice(1)||'home'; if(!navigation.some(n=>n[0]===screen))screen='home';
  $('#nav').innerHTML=navigation.map(([id,icon,label])=>`<a href="#${id}" class="${screen===id?'active':''}" ${screen===id?'aria-current="page"':''}><span class="nav-icon" aria-hidden="true">${icon}</span>${label}</a>`).join('');
  $('#date').textContent=new Date().toLocaleDateString('de-DE',{weekday:'long',day:'numeric',month:'long'});
  $('#avatar').textContent=(state.profile.name||'U')[0].toUpperCase();
  document.body.classList.toggle('onboarding', !state.profile.configured);
  content.innerHTML=state.profile.configured ? ({home,move,report,friends,profile}[screen])() : intro();
}
function openDialog(title,body) { dialog.innerHTML=`<div class="dialog-head"><h2 id="dialog-title">${title}</h2><button class="close" data-action="close" aria-label="Schließen">×</button></div>${body}`;if(!dialog.open)dialog.showModal(); }
function workoutDialog() {
  const e=exercises[workout.exercise], seconds=workout.exercise==='plank';
  openDialog(e.title,`<p class="hint">Simulierte Kameraerkennung. Hier wird keine Kamera eingeschaltet.</p><div class="camera-sim"><svg viewBox="0 0 150 110" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round" aria-hidden="true"><circle cx="77" cy="17" r="11"/><path d="M77 32L77 64M77 43L48 55L28 43M77 43L106 55L123 41M77 64L52 86L45 103M77 64L101 86L108 103"/></svg><small>GANZER KÖRPER IM BILD · VORSCHAU</small></div><div class="counter">${workout.amount}</div><p class="counter-label">${e.unit} · ${workout.amount?U.reward(state,workout.exercise,workout.amount):0} Minuten verdient</p><div class="actions"><button class="secondary" data-action="rep">${seconds?'+10 Sekunden halten':'+1 erkannt simulieren'}</button><button class="primary" data-action="finish" ${workout.amount?'':'disabled'}>Zeit gutschreiben ✓</button></div>`);
}
function usageDialog() {
  const s=U.current(state); if(!s){dialog.close();render();toast('Zeit aufgebraucht. Alle ausgewählten Apps sind wieder gesperrt – in der Simulation.');return;}
  openDialog('Deine gemeinsame Freigabe',`<p class="hint">Nutzung simulieren, ohne andere Apps zu öffnen.</p><div class="counter" style="margin-top:20px">${s.total-s.used}</div><p class="counter-label">von ${s.total} Minuten übrig</p>${state.apps.map(a=>`<div class="app-row"><span>${esc(a)}</span><button class="secondary" data-action="consume" data-minutes="1" aria-label="1 Minute ${esc(a)} simulieren">1 Min. nutzen</button></div>`).join('')}<div class="actions"><button class="primary" data-action="consume" data-minutes="5">5 Minuten nutzen</button><button class="secondary" data-action="stop">Freigabe beenden</button></div><p class="hint">Beim vorzeitigen Beenden verfallen freigegebene Restminuten. Gespartes Guthaben bleibt erhalten.</p>`);
}
function sound() {
  const Context=window.AudioContext||window.webkitAudioContext;
  if(!Context){toast('Tonwiedergabe ist in diesem Browser nicht verfügbar.');return;}
  const audio=new Context(),gain=audio.createGain();gain.connect(audio.destination);gain.gain.setValueAtTime(0,audio.currentTime);gain.gain.linearRampToValueAtTime(.14,audio.currentTime+2);gain.gain.linearRampToValueAtTime(0,audio.currentTime+4);
  [523.25,659.25].forEach(f=>{const o=audio.createOscillator();o.frequency.value=f;o.connect(gain);o.start();o.stop(audio.currentTime+4)});setTimeout(()=>audio.close(),4500);toast('Sanfte Tonvorschau · kein Wecker gestellt');
}
document.addEventListener('click',event=>{
  const button=event.target.closest('[data-action]');if(!button)return;
  const action=button.dataset.action;
  try {
    if(navigation.some(n=>n[0]===action)){location.hash=action;return;}
    switch(action){
      case 'intro-back': captureIntro(); introPage=Math.max(0,introPage-1); render(); break;
      case 'intro-mode': captureIntro(); introDraft.mode=button.dataset.mode; render(); break;
      case 'steps-add': U.updateSteps(state,U.stepDay(state).steps+500);persist();render();break;
      case 'steps-claim': { const minutes=U.claimSteps(state);persist();render();toast(`+${minutes} Minuten fürs Gehen.`);break; }
      case 'close':dialog.close();workout=null;break;
      case 'exercise':workout={id:crypto.randomUUID(),exercise:button.dataset.id,amount:0};workoutDialog();break;
      case 'rep':workout.amount+=workout.exercise==='plank'?10:1;workoutDialog();break;
      case 'finish':{const minutes=U.earn(state,workout.exercise,workout.amount,workout.id);workout=null;persist();dialog.close();render();toast(`Geschafft! +${minutes} Minuten auf deinem Zeitkonto.`);break;}
      case 'start':U.start(state);persist();render();usageDialog();break;
      case 'usage':usageDialog();break;
      case 'consume':U.consume(state,Number(button.dataset.minutes));persist();render();usageDialog();break;
      case 'stop':U.stop(state);persist();dialog.close();render();toast('Freigabe beendet. Die Demo-Apps sind wieder gesperrt.');break;
      case 'emergency':openDialog('Du brauchst gerade eine Ausnahme?',`<p class="hint">Du bekommst 5 Minuten ohne Übung. Diese Ausnahme wird in deinem Wochenrückblick gezählt.</p><div class="actions"><button class="secondary" data-action="close">Zurück</button><button class="primary" data-action="confirm-emergency">5 Minuten freigeben</button></div>`);break;
      case 'confirm-emergency':U.start(state,true);persist();render();usageDialog();break;
      case 'apps':if(U.current(state))throw Error('Beende zuerst die laufende Freigabe.');openDialog('Deine Apps auswählen',`<form id="apps-form"><p class="hint">Alle ausgewählten Apps teilen sich dasselbe Guthaben.</p>${['Instagram','TikTok','YouTube','Snapchat','Reddit','X'].map(a=>`<label class="check"><input type="checkbox" name="apps" value="${a}" ${state.apps.includes(a)?'checked':''}>${a}</label>`).join('')}<button class="primary full" type="submit" style="margin-top:17px">Auswahl speichern</button></form>`);break;
      case 'friend':openDialog('Demo-Freund hinzufügen',`<form id="friend-form"><p class="hint">Diese Person ist nur ein lokales Beispiel. Es wird keine Einladung versendet.</p><label class="field">Demo-Name<input name="friend" maxlength="30" required placeholder="Zum Beispiel Alex"></label><label class="field">Beispiel-Liegestütze<input name="score" type="number" min="0" max="1000" value="12" required></label><button class="primary full" type="submit">Demo-Freund hinzufügen</button></form>`);break;
      case 'challenge':if(!state.challenge){state.challenge=new Date().toISOString();persist();render();toast('Deine Sieben-Tage-Challenge beginnt jetzt.');}else toast('Deine Challenge läuft. Eine Einheit pro Tag zählt.');break;
      case 'sound':sound();break;
      case 'confirm-reset':introPage=0;introDraft=null;state=U.fresh();persist();dialog.close();render();toast('Die Vorschau beginnt wieder bei null.');break;
    }
  }catch(error){toast(error.message);}
});
document.addEventListener('submit',event=>{
  if(event.target.id==='intro-form'){event.preventDefault(); advanceIntro();return;}
  if(!['profile-form','apps-form','friend-form'].includes(event.target.id))return;event.preventDefault();const data=new FormData(event.target);
  if(event.target.id==='profile-form'){
    const goal=Number(data.get('goal')),ratio=({beginner:3,normal:2,hard:1})[data.get('mode')],plankRatio=30;
    if(!Number.isInteger(goal)||goal<1||goal>200)return toast('Bitte ein Ziel zwischen 1 und 200 wählen.');
    state.profile={...state.profile,name:String(data.get('name')).trim().slice(0,40),birthday:String(data.get('birthday')),goal,ratio,plankRatio,mode:String(data.get('mode')),evening:String(data.get('evening')),wake:String(data.get('wake'))};persist();render();toast('Dein Profil ist gespeichert.');
  }else if(event.target.id==='apps-form'){state.apps=data.getAll('apps');persist();dialog.close();render();toast('App-Auswahl gespeichert.');}
  else {const name=String(data.get('friend')).trim(),score=Number(data.get('score'));if(!name)return toast('Bitte einen Demo-Namen eingeben.');state.friends.push({name,score});persist();dialog.close();render();toast('Demo-Freund hinzugefügt. Keine Einladung versendet.');}
});
$('#avatar').addEventListener('click',()=>location.hash='profile');
$('#reset').addEventListener('click',()=>openDialog('Vorschau zurücksetzen?',`<p class="hint">Deine lokalen Demo-Übungen, Minuten und Profilangaben werden gelöscht.</p><div class="actions"><button class="secondary" data-action="close">Behalten</button><button class="primary" data-action="confirm-reset">Zurücksetzen</button></div>`));
function stepsCard() {
  const d=U.stepDay(state), ready=(Math.floor(d.steps/1000)-d.claimedBlocks)*state.profile.ratio;
  return `<section class="card steps-card"><div><div class="eyebrow">JEDER WEG ZÄHLT</div><h2>Dein Alltag bringt dich weiter.</h2><p class="hint">1.000 Schritte → ${state.profile.ratio} Minuten · ${modeTitle(state.profile.mode)}</p></div><div class="step-total"><strong>${d.steps.toLocaleString('de-DE')}</strong><span>Schritte heute · Simulation</span></div><div class="step-track"><span style="width:${d.steps%1000/10}%"></span></div><p class="hint">Noch ${1000-d.steps%1000} Schritte bis zum nächsten Tausender. Heute ${d.minutes} Min. gutgeschrieben.</p><div class="actions"><button class="secondary" data-action="steps-add">+500 Schritte simulieren</button><button class="primary" data-action="steps-claim" ${ready?'':'disabled'}>${ready} Minuten gutschreiben</button></div><p class="hint">Auf dem iPhone liest Unscroll nach deiner Erlaubnis echte Schritte. Jeder volle Tausender zählt einmal; Restschritte gelten bis Tagesende.</p></section>`;
}
function modeTitle(mode) {return {beginner:'Beginner',normal:'Normal',hard:'Schwierig'}[mode]||'Normal';}
function captureIntro() {
  if(!introDraft)introDraft={...state.profile};
  const form=$('#intro-form');if(!form)return;
  const data=new FormData(form);
  for(const key of ['name','birthday','goal'])if(data.has(key))introDraft[key]=key==='goal'?Number(data.get(key)):String(data.get(key)).trim();
}
function advanceIntro() {
  captureIntro();
  if(introPage===1&&!introDraft.name)return toast('Trage deinen Vornamen ein.');
  if(introPage===2&&(!introDraft.birthday||introDraft.birthday>new Date().toISOString().slice(0,10)))return toast('Bitte ein gültiges Geburtsdatum eingeben.');
  if(introPage<4){introPage++;render();window.scrollTo(0,0);return;}
  if(!Number.isInteger(introDraft.goal)||introDraft.goal<1||introDraft.goal>200)return toast('Bitte ein Ziel zwischen 1 und 200 wählen.');
  state.profile={...state.profile,...introDraft,configured:true,ratio:{beginner:3,normal:2,hard:1}[introDraft.mode],plankRatio:30};persist();location.hash='home';render();window.scrollTo(0,0);
}
function intro() {
  if(!introDraft)introDraft={...state.profile}; const p=introDraft;
  const titles=['Weniger scrollen.<br>Mehr du.','Schön, dich<br>kennenzulernen.','Ein bisschen<br>persönlicher.','Dein Tempo.<br>Deine Entscheidung.','Klein anfangen.<br>Dranbleiben.'];
  const bodies=[
    `<p class="intro-lead">Verwandle Bewegung in bewusste Bildschirmzeit. Ein paar Wiederholungen. Ein Spaziergang. Ein guter Anfang.</p><div class="intro-orbit"><span>↗</span><small>BEWEGUNG WIRD FREIZEIT</small></div><div class="intro-benefits"><span>↗ Übungen</span><span>◷ Planks</span><span>⌁ Schritte</span></div>`,
    `<p class="intro-lead">Wie darf dein persönlicher Assistent dich nennen?</p><label class="field">Dein Vorname<input name="name" required maxlength="40" autocomplete="given-name" placeholder="Zum Beispiel Sam" value="${esc(p.name)}" autofocus></label>`,
    `<p class="intro-lead">Dein Geburtstag hilft uns, Hinweise passend zu dir zu formulieren.</p><label class="field">Geburtsdatum<input name="birthday" type="date" required max="${new Date().toISOString().slice(0,10)}" value="${esc(p.birthday)}"></label><p class="hint">Bleibt auf deinem Gerät. Wird nicht mit Freunden geteilt.</p>`,
    `<p class="intro-lead">Wähle, wie viel Zeit deine Bewegung wert ist. Das Tempo beim Training bestimmst immer du.</p><div class="mode-options">${[['beginner',3,'Sanft einsteigen'],['normal',2,'Deine goldene Mitte'],['hard',1,'Bewusst herausfordern']].map(([id,n,sub])=>`<button type="button" class="mode-option ${p.mode===id?'selected':''}" data-action="intro-mode" data-mode="${id}" aria-pressed="${p.mode===id}"><span><strong>${modeTitle(id)}</strong><small>${sub}</small></span><b>×${n}</b></button>`).join('')}</div><p class="inline-note">1 Wiederholung, 30 Sekunden Plank oder 1.000 Schritte ergeben <strong>${{beginner:3,normal:2,hard:1}[p.mode]} Minuten</strong>. Du kannst den Modus später ändern.</p>`,
    `<p class="intro-lead">Setze dir ein machbares Tagesziel. Du kannst es jederzeit anpassen.</p><label class="field">Wiederholungen pro Tag<input name="goal" type="number" min="1" max="200" required value="${p.goal}"></label><p class="hint">Planks und Schritte zählen separat. Kein Druck, wenn du einen Tag pausierst.</p><div class="inline-note"><strong>Dein Start: ${modeTitle(p.mode)}</strong><br>Bildschirmzeit, Kamera und Schritte aktivierst du auf dem iPhone erst, wenn du sie brauchst. Hier probierst du alles als Simulation aus.</div>`
  ];
  return `<div class="intro-shell"><div class="eyebrow">DEIN NEUER ANFANG</div><div class="intro-progress" aria-label="Schritt ${introPage+1} von 5">${Array.from({length:5},(_,i)=>`<span class="${i<=introPage?'filled':''}"></span>`).join('')}</div><p class="hint">${String(introPage+1).padStart(2,'0')} / 05</p><h1>${titles[introPage]}</h1><form id="intro-form">${bodies[introPage]}<div class="intro-actions">${introPage?'<button type="button" class="text-button" data-action="intro-back">← Zurück</button>':'<span class="hint">In etwa einer Minute eingerichtet.</span>'}<button class="primary" type="submit">${introPage===4?'Los geht’s ↗':'Weiter ↗'}</button></div></form></div>`;
}
window.addEventListener('hashchange' ,()=>{render();window.scrollTo(0,0)});
render();
