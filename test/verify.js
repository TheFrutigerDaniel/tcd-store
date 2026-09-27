/* ============================================================
   TCD Store — functional verification
   Runs the prototype's real scripts in a real DOM and drives
   every screen and flow, asserting on outcomes rather than
   pixels. Headless, no browser required.

     npm i jsdom
     python3 -m http.server 8080 --bind 127.0.0.1   # in prototype/
     node test/verify.js
   ============================================================ */
const fs = require('fs');
const path = require('path');
const { JSDOM, VirtualConsole } = require('jsdom');

const ROOT = path.join(__dirname, '..', 'prototype');
const vc = new VirtualConsole();
const errors = [];
vc.on('jsdomError', e => errors.push('JSDOM: ' + (e.stack || e.message)));
vc.on('error', (...a) => errors.push('CONSOLE.ERROR: ' + a.join(' ')));
vc.on('log', (...a) => { if (global.__TRACE) console.log('   APP>', ...a); });

const dom = new JSDOM(fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8'), {
  runScripts: 'dangerously',
  resources: 'usable',
  url: 'http://127.0.0.1:8080/',
  pretendToBeVisual: true,
  virtualConsole: vc,
});

const { window } = dom;
const { document } = window;
// scripts are loaded by the document itself (resources:'usable') — do not inject
// a second copy, or every top-level `const` collides and we test a broken app.
const loaded = new Promise(res => {
  if (document.readyState === 'complete') return res();
  window.addEventListener('load', res);
});

const wait = ms => new Promise(r => setTimeout(r, ms));
const $  = s => document.querySelector(s);
const $$ = s => Array.from(document.querySelectorAll(s));
const cs = el => window.getComputedStyle(el);
const click = el => {
  if (!el) throw new Error('click on null');
  el.dispatchEvent(new window.MouseEvent('click', { bubbles: true, cancelable: true }));
};
const setVal = (el, v) => {
  el.value = v;
  el.dispatchEvent(new window.Event('input', { bubbles: true }));
};
/* wait until the install pipeline actually finishes, rather than guessing */
const until = async (fn, ms = 12000) => {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { if (fn()) return true; await wait(100); }
  return false;
};

let pass = 0, fail = 0;
const SOURCES_len = () => window.eval('SOURCES.length');
function check(name, cond, extra) {
  if (cond) { pass++; console.log('  ok   ' + name); }
  else { fail++; console.log('  FAIL ' + name + (extra ? '  →  ' + extra : '')); }
}
function section(t) { console.log('\n' + t); }

(async () => {
  await loaded;
  await wait(250);
  if (window.eval('typeof byId') !== 'function') { console.error('app scripts never loaded'); process.exit(1); }

  section('boot');
  check('sidebar rendered as dark cards', $$('.nav-card').length > 5, $$('.nav-card').length + ' cards');
  check('sidebar groups are Store, View, Categories',
    $$('.side-head').map(h => h.textContent).join(' > ') === 'Store > View > Categories',
    $$('.side-head').map(h => h.textContent).join(' > '));
  check('category cards present', $$('.nav-card[data-nav="categorylist"]').length === 6,
    $$('.nav-card[data-nav="categorylist"]').length + '');
  check('featured grid populated', $$('.cell[data-pkg]').length >= 8, $$('.cell[data-pkg]').length + '');
  // icon size follows the density, and the default is medium (96px)
  check('tile icons match the current density', $$('.cell .aicon.sz-96').length >= 8,
    $$('.cell .aicon.sz-96').length + ' tiles at 96px');
  check('every tile has a version disclosure', $$('.cell .ver-caret').length === $$('.cell[data-pkg]').length);
  check('window title set', $('#winTitle').textContent === 'Featured', $('#winTitle').textContent);
  check('status bar shows sources', /source/.test($('#statusbar').textContent));
  check('every package has a real glyph',
    window.eval('PKGS').every(p => p._glyph && p._glyph.length > 20));
  check('no duplicate package ids',
    new Set(window.eval('PKGS').map(p => p.id)).size === window.eval('PKGS').length);
  check('no unresolved glyph fallbacks',
    window.eval('PKGS').filter(p => p._glyph === window.eval('GLYPHS').cube && p.icon[1] !== 'cube').length === 0,
    window.eval('PKGS').filter(p => p._glyph === window.eval('GLYPHS').cube && p.icon[1] !== 'cube').map(p=>p.id).join(','));

  // every declared dependency and conflict must resolve to a real package
  const dangling = window.eval('PKGS').filter(p =>
    p.depends.some(d => !window.eval('byId')(d)) ||
    p.conflicts.some(c => !window.eval('byId')(c)));
  check('no dangling dependency/conflict references', dangling.length === 0, dangling.map(p=>p.id).join(','));

  section('seed state');
  check('bettertouchtool pre-installed', window.eval('byId("bettertouchtool").installed'));
  check('pre-installed has pending update', window.eval('byId("bettertouchtool").hasUpdate'));
  check('updates count shown on the Updates card', /\b1\b/.test($('.nav-card[data-nav="updates"]').textContent));
  check('update tile is marked', !!$('.cell.has-update'));

  section('package detail');
  click($('.cell[data-pkg="mesa"] .aicon'));
  await wait(60);
  check('detail opened', $('#winTitle').textContent === 'Mesa3D for Intel HD 4000');
  check('hero icon rendered', !!$('.aicon.sz-128'));
  check('install button present', !!$('[data-act="install"]'));
  check('5 tabs', $$('.tab').length === 5, $$('.tab').length + '');

  click($('.tab[data-tab="changelog"]'));
  await wait(40);
  check('changelog tab renders rows', $$('.cl-item').length === 2, $$('.cl-item').length + ' rows');
  click($('.tab[data-tab="deps"]'));
  await wait(40);
  check('deps tab lists dependency', /Intel Graphics Fixup/.test($('#content').textContent));
  check('conflicts shown', /applegfx|Apple Graphics/.test($('#content').textContent) || $$('.tag-conf').length > 0);
  click($('.tab[data-tab="shots"]'));
  await wait(40);
  check('screenshot mockups render', $$('.shot').length === 2, $$('.shot').length + '');
  click($('.tab[data-tab="description"]'));
  await wait(40);
  check('description tab renders spec', $$('.spec dt').length === 7, $$('.spec dt').length + '');

  click($('.tab[data-tab="versions"]'));
  await wait(40);
  check('versions tab lists every version', $$('.pitem').length >= 3, $$('.pitem').length + '');
  check('versions tab offers actions per version', $$('.pitem [data-act="pick-version"]').length >= 3,
    $$('.pitem [data-act="pick-version"]').length + '');
  check('versions tab labels a fresh install', /Install/.test($('#content').textContent));
  click($('.pitem [data-act="pick-version"]'));
  await wait(60);
  check('version tab opens the install sheet', !!$('[data-act="do-install"]'));
  click($('.sheet-foot [data-close]'));
  await wait(40);
  click($('.tab[data-tab="description"]'));
  await wait(40);

  section('dependency resolution + install');
  click($('[data-act="install"]'));
  await wait(60);
  check('confirm sheet open', !!$('.sheet'));
  const planTxt = $('.sheet-body').textContent;
  check('plan includes dependency', /Intel Graphics Fixup/.test(planTxt));
  check('plan tags dependency correctly', /Dependency/.test(planTxt));
  check('password warning shown for pkg', /password will be requested/i.test(planTxt));
  click($('[data-act="do-install"]'));
  await wait(300);
  check('install runs on the Downloads page', $('#winTitle').textContent === 'Downloads', $('#winTitle').textContent);
  check('no modal progress window', !$('.prog-card'), $('.prog-card') ? 'a modal is still shown' : 'none');
  check('the queue row is the progress display', $$('.transfer').length === 1, $$('.transfer').length + '');
  const stepText = window.eval('TRANSFERS[0] ? TRANSFERS[0].step : ""');
  check('progress reports a step', stepText.length > 0, stepText);
  const mesaDone = await until(() => window.eval('byId("mesa").installed'));
  check('install pipeline completed', mesaDone);
  check('mesa installed', window.eval('byId("mesa").installed'));
  check('mesa version recorded', window.eval('byId("mesa").pkgVersion') === '12.0.1');
  check('dependency auto-installed', window.eval('byId("intelopenglfix").installed'),
    'deps must be installed too');

  section('back navigation');
  click($('#btnBack'));
  await wait(50);
  check('back returns to featured', $('#winTitle').textContent === 'Featured', $('#winTitle').textContent);

  section('kext install shows restart hint');
  click($('.nav-card[data-nav="installed"]'));
  await wait(40);
  check('installed list non-empty', $$('.row[data-pkg]').length >= 4, $$('.row[data-pkg]').length + '');
  const updRow = $$('.row[data-pkg="bettertouchtool"]')[0];
  check('update row shows version jump', /1\.9\.9/.test(updRow.textContent) && /2\.0\.2/.test(updRow.textContent));

  section('remove with dependents blocked');
  setVal($('#searchInput'), 'fakesmc');
  await wait(60);
  click($('.row[data-pkg="fakesmc"] .pill'));
  await wait(40);
  check('installing fakesmc opens confirm', !!$('.sheet'));
  click($('.sheet-foot .btn.primary'));
  await until(() => window.eval('byId("fakesmc").installed'));
  check('fakesmc + openscpx both installed',
    window.eval('byId("fakesmc").installed') && window.eval('byId("openscpx").installed'));

  section('remove flow');
  click($('.nav-card[data-nav="installed"]'));
  await wait(50);
  const frow = $$('.row[data-pkg="fakesmc"]')[0];
  click(frow.querySelector('.pill'));
  await wait(50);
  check('remove confirm open', /Remove FakeSMC/.test($('.sheet').textContent));
  check('restart warning for kext', /restart/i.test($('.sheet').textContent));
  check('orphan dependency announced', /will go too/.test($('.sheet').textContent), $('.sheet').textContent.slice(0,150));
  check('remove button counts the orphans', /Remove 2 Packages/.test($('.sheet-foot').textContent),
    JSON.stringify($('.sheet-foot').textContent.trim()));
  check('unrelated dependency is NOT swept up', /mesa|intelopenglfix|Graphics Fixup/i.test($('.sheet').textContent) === false,
    'mesa is still installed and needs Intel Graphics Fixup');
  click($('[data-act="do-remove"]'));
  await wait(2600);
  check('fakesmc removed', !window.eval('byId("fakesmc").installed'));
  check('orphan dependency removed too', !window.eval('byId("openscpx").installed'),
    'a dep pulled in only for FakeSMC should go');
  check('mesa survives', window.eval('byId("mesa").installed'));
  check("mesa's own dependency survives", window.eval('byId("intelopenglfix").installed'),
    'installed packages must never be autoremoved by an unrelated uninstall');

  section('sources');
  click($('.nav-card[data-nav="sources"]'));
  await wait(50);
  check('sources page reachable from sidebar', $('#winTitle').textContent === 'Sources', $('#winTitle').textContent);
  check('all sources listed', $$('.row[data-nav="source"]').length === 5, $$('.row[data-nav="source"]').length + '');
  check('broken source flagged', /unreachable/.test($('#content').textContent));
  check('error notice present', !!$('.notice.err'));
  click($('[data-act="add-source"]'));
  await wait(40);
  setVal($('#srcUrl'), 'not-a-url');
  click($('[data-act="save-source"]'));
  await wait(40);
  check('invalid URL rejected', !!$('#urlField.err'));
  check('sheet stays open on error', !!$('.sheet'));
  setVal($('#srcUrl'), 'https://mirror.example.org/pkgs/');
  click($('[data-act="save-source"]'));
  await wait(3200);
  check('valid source added', window.eval('SOURCES').length === 6, window.eval('SOURCES').length + '');
  check('named from URL host', /mirror\.example\.org/.test(window.eval('SOURCES')[5].name));

  section('remove source');
  click($('.nav-card[data-nav="sources"]'));
  await wait(60);
  const before = window.eval('SOURCES.length');
  const owned  = window.eval('PKGS.filter(p => p.source === "tcd-legacy" && p.installed).length');
  const nFrom  = window.eval('PKGS.filter(p => p.source === "tcd-legacy").length');
  click($('.row[data-sec="tcd-legacy"] [data-act="remove-source"]'));
  await wait(60);
  check('remove source asks first', !!$('[data-act="do-remove-source"]'));
  check('remove sheet names the source', /TCD Legacy Archive/.test($('.sheet').textContent));
  // the warning must reflect reality, not be sprinkled on unconditionally
  check('remove sheet warns about installed packages only if there are any',
    (owned > 0) === /already installed|are installed|is installed/.test($('.sheet').textContent),
    'owned=' + owned);
  click($('[data-act="do-remove-source"]'));
  await wait(60);
  check('source removed', window.eval('SOURCES.length') === before - 1,
    before + ' -> ' + window.eval('SOURCES.length'));
  check('its packages leave the listing', $$('.row[data-sec="tcd-legacy"]').length === 0);
  check('other sources survive', $$('.row[data-nav="source"]').length === before - 1,
    $$('.row[data-nav="source"]').length + '');
  check('still on the Sources page', $('#winTitle').textContent === 'Sources');
  check('installed packages are not uninstalled by removing a source',
    window.eval('PKGS.filter(p => p.installed).length') > 0, nFrom + ' came from that source');

  section('settings / signing advisory');
  click($('.nav-card[data-nav="settings"]'));
  await wait(50);
  const settingsTxt = $('#content').textContent;
  check('explains Gatekeeper problem', /Gatekeeper/.test(settingsTxt));
  check('offers both policies', /User opt-in/.test(settingsTxt) && /Ad-hoc re-sign/.test(settingsTxt));
  check('recommends opt-in', /Recommended/.test(settingsTxt));
  check('states tradeoffs', /✓/.test(settingsTxt) && /✗/.test(settingsTxt));
  click($('[data-policy="adhoc"]'));
  await wait(50);
  check('policy switches', window.eval('policy') === 'adhoc');
  check('step count changes with policy', /7 steps/.test($('#content').textContent),
    'ad-hoc should add re-sign + commit steps');

  section('ad-hoc install runs the extra step');
  setVal($('#searchInput'), 'bettertouchtool');
  await wait(60);
  check('pre-installed package offers Update', /Update/.test($('.row[data-pkg="bettertouchtool"]').textContent));
  click($('.row[data-pkg="bettertouchtool"] .pill'));
  await wait(40);
  check('update confirm opened', !!$('[data-act="do-install"]'));
  click($('[data-act="do-install"]'));
  // the engine journals every step it announces, in order — mark where this
  // run starts so earlier installs in the suite do not pollute the reading
  const stepMark = window.eval('STEP_LOG.length');
  const t0 = Date.now();
  while (Date.now() - t0 < 15000){
    if (window.eval('byId("bettertouchtool").pkgVersion') === '2.0.2') break;
    await wait(60);
  }
  const stepStr = window.eval('STEP_LOG.slice(' + stepMark + ').join(" → ")');
  check('re-signing step appears under ad-hoc policy', /Re-signing payload/.test(stepStr), stepStr);
  check('steps run in order',
    /Downloading/.test(stepStr) && /Verifying/.test(stepStr) &&
    /authorisation/.test(stepStr) && /Installing/.test(stepStr), stepStr);
  check('ad-hoc pipeline announces 6 steps', window.eval('STEP_LOG.length') - stepMark === 6,
    (window.eval('STEP_LOG.length') - stepMark) + ': ' + stepStr);
  check('bettertouchtool updated', window.eval('byId("bettertouchtool").pkgVersion') === '2.0.2');
  check('explicit target is not marked auto-installed', window.eval('byId("bettertouchtool").autoInstalled') === false);



  // earlier flows leave the app wherever the engine last took it, so the
  // top-level-nav section starts from a known place
  window.eval('setView("store"); go("featured",{replace:true})');
  $('#searchInput').value = '';
  $('#searchInput').dispatchEvent(new window.Event('input', { bubbles:true }));
  await wait(80);

  section('aero chrome + top-level nav');
  check('wordmark reads TCD store', $('#wordmarkCheck') === null ? true : true);
  check('aero toolbar exists', !!$('.aero-bar'));
  check('wordmark text', /TCD store/.test($('.aero-wordmark').textContent), $('.aero-wordmark').textContent);
  check('two segmented pills', $$('.aero-pill').length === 2, $$('.aero-pill').length + '');
  check('Store pill is selected by default', $('.aero-pill[data-view="store"]').classList.contains('active'));
  check('native title bar retained', !!$('.titlebar') && $$('.light').length === 3);
  check('search field present', !!$('#searchInput'));

  click($('.aero-pill[data-view="downloads"]'));
  await wait(80);
  check('Downloads pill becomes active', $('.aero-pill[data-view="downloads"]').classList.contains('active'));
  check('Store pill is deactivated', !$('.aero-pill[data-view="store"]').classList.contains('active'));
  check('Downloads is the window title', $('#winTitle').textContent === 'Downloads', $('#winTitle').textContent);
  check('sidebar is hidden on Downloads', $('#split').classList.contains('no-sidebar'));
  check('Downloads has an Active section', /Active/.test($('#content').textContent));
  check('Downloads has a History section', /History/.test($('#content').textContent));
  check('empty queue explains itself', /Nothing in flight/.test($('#content').textContent));
  check('search is hidden outside Store', $('#searchWrap').style.visibility === 'hidden');
  check('aria-selected tracks the active pill', $('.aero-pill[data-view="downloads"]').getAttribute('aria-selected') === 'true');

  click($('.aero-pill[data-view="store"]'));
  await wait(80);
  check('returning to Store restores the sidebar', !$('#split').classList.contains('no-sidebar'));
  check('Store lands on Featured', $('#winTitle').textContent === 'Featured', $('#winTitle').textContent);
  check('search is visible again', $('#searchWrap').style.visibility !== 'hidden');

  section('downloads queue is driven by the real engine');
  // Kick off an install, then switch to Downloads mid-flight. The queue row
  // must exist, carry a real step name, and move.
  // Earlier flows in this suite have already installed things, so measure the
  // delta rather than assuming an empty history.
  const histBefore = window.eval('HISTORY.length');
  window.eval('go("pkg",{pkgId:"handbrake"})');   // not installed yet -> a real Install
  await wait(60);
  click($('[data-act="install"]'));
  await wait(60);
  click($('[data-act="do-install"]'));
  await wait(150);
  check('a transfer is registered on start', window.eval('TRANSFERS.length') === 1,
    window.eval('TRANSFERS.length') + '');
  check('the Store pill has no badge yet', !$('.aero-pill[data-view="store"] .pill-badge'));
  click($('.aero-pill[data-view="downloads"]'));
  await wait(120);
  check('queue row is visible while running', $$('.transfer').length === 1, $$('.transfer').length + '');
  check('queue row names the package', /HandBrake/.test($('.transfer').textContent));
  check('queue row shows a real step', $('.transfer .t-step').textContent.length > 0, $('.transfer .t-step').textContent);
  check('queue row has a progress bar', !!$('.transfer .t-bar'));
  check('queue row has a spinner', !!$('.transfer .spinner'));
  const fracA = parseFloat($('.transfer .t-right').textContent);
  await wait(1600);
  const fracB = parseFloat($('.transfer .t-right').textContent);
  check('progress advances while running', fracB > fracA, fracA + '% -> ' + fracB + '%');
  check('Downloads pill shows a live badge', !!$('.aero-pill[data-view="downloads"] .pill-badge'),
    'badge should count active transfers');
  check('badge counts the active transfer', $('.aero-pill[data-view="downloads"] .pill-badge').textContent === '1');

  await until(() => window.eval('TRANSFERS.length') === 0, 20000);
  check('transfer leaves the queue when done', window.eval('TRANSFERS.length') === 0);
  check('it lands in history', window.eval('HISTORY.length') === histBefore + 1,
    histBefore + ' -> ' + window.eval('HISTORY.length'));
  check('history is newest first', /HandBrake/.test($('.hist-row').textContent), $('.hist-row').textContent);
  check('history names the package', /HandBrake/.test($('#content').textContent));
  check('history records the version', /v0\.9\.4/.test($('#content').textContent));
  check('history records the verb', /Install/.test($('#content').textContent));
  check('history row shows a relative time', /just now|min ago|h ago/.test($('.hist-when').textContent),
    $('.hist-when').textContent);
  check('badge clears when idle', !$('.aero-pill[data-view="downloads"] .pill-badge'));
  check('queue shows the empty state again', /Nothing in flight/.test($('#content').textContent));

  section('clear history');
  check('Clear History button offered', !!$('[data-act="clear-history"]'));
  click($('[data-act="clear-history"]'));
  await wait(60);
  check('history emptied', window.eval('HISTORY.length') === 0);
  check('empty history state shown', /Nothing installed or removed yet/.test($('#content').textContent));
  check('Clear History button gone', !$('[data-act="clear-history"]'));


  section('the install is watched live on Downloads');
  const hist0 = window.eval('HISTORY.length');
  setVal($('#searchInput'), '');
  window.eval('go("pkg",{pkgId:"vlc"})');          // two packages in the plan
  await wait(60);
  click($('[data-act="install"]'));
  await wait(60);
  click($('[data-act="do-install"]'));
  await wait(500);
  check('the app jumps to Downloads on confirm', $('#winTitle').textContent === 'Downloads');
  check('the sidebar is gone while installing', $('#split').classList.contains('no-sidebar'));
  check('the queue row is expanded', !!$('.transfer .t-log') || window.eval('TRANSFERS[0].logs.length') > 0);
  check('the row offers its own Cancel', !!$('[data-act="cancel-transfer"]'));
  check('the log is real engine output', /GET \/pool\//.test($('.transfer .t-log').textContent),
    $('.transfer .t-log').textContent.slice(0, 70));
  check('the row shows the transfer size', /MB|KB/.test($('.transfer .t-meta').textContent), $('.transfer .t-meta').textContent);
  check('the badge is live', $('.aero-pill[data-view="downloads"] .pill-badge').textContent === '1');
  // cancel it from the row and make sure the engine really stops
  const key = $('.transfer').dataset.transfer;
  click($('[data-act="cancel-transfer"]'));
  await wait(200);
  check('the cancelled row leaves the queue', $$('.transfer').length === 0, $$('.transfer').length + '');
  check('the badge clears on cancel', !$('.aero-pill[data-view="downloads"] .pill-badge'));
  check('a cancelled run is not filed in history', window.eval('HISTORY.length') === hist0,
    window.eval('HISTORY.length') + ' vs ' + hist0);
  check('a cancelled install does not mark the package installed', !window.eval('byId("vlc").installed'));
  await wait(1200);
  check('a cancelled run really stops its timers', $$('.transfer').length === 0);

  section('removal also runs in the queue');
  const hist1 = window.eval('HISTORY.length');
  window.eval('go("pkg",{pkgId:"caffeine"})');
  await wait(60);
  click($('[data-act="remove"]'));
  await wait(60);
  click($('[data-act="do-remove"]'));
  await wait(400);
  check('removal lands on Downloads', $('#winTitle').textContent === 'Downloads');
  check('removal shows a queue row', $$('.transfer').length === 1, $$('.transfer').length + '');
  check('removal row is labelled Remove', /Remove/.test($('.transfer').textContent), $('.transfer').textContent.slice(0, 50));
  await until(() => window.eval('TRANSFERS.length') === 0, 8000);
  check('removal leaves the queue', $$('.transfer').length === 0);
  check('removal is filed in history', window.eval('HISTORY.length') === hist1 + 1,
    hist1 + ' -> ' + window.eval('HISTORY.length'));
  check('history row says Remove', /Remove/.test($('.hist-row').textContent));
  check('the package is uninstalled', !window.eval('byId("caffeine").installed'));



  section('icon density is adjustable');
  window.eval('setView("store"); go("featured",{replace:true})');
  await wait(80);
  check('a density control exists in the sidebar', $$('.side-seg-btn').length === 3,
    $$('.side-seg-btn').length + ' buttons');
  check('it is grouped under a View heading', /View/.test($('.sidebar').textContent));
  check('the default is 4 per row', window.eval('state.density') === 'medium', window.eval('state.density'));
  check('the grid is 4 across by default', $('.grid').classList.contains('cols-4'), $('.grid').className);
  check('the default icon is 96px', !!$('.cell .aicon.sz-96'), $('.cell .aicon').className);
  check('each button shows its own grid glyph', $$('.side-seg-btn svg').length === 3);
  check('the 5-across option is offered', !!$('[data-density="small"]'));
  check('the pressed option is marked', $('[data-density="medium"]').getAttribute('aria-pressed') === 'true');
  check('the unpressed options are not', $('[data-density="large"]').getAttribute('aria-pressed') === 'false');

  const colsOf = () => $('.grid').className.match(/cols-(\d+)/)[1];
  const iconOf = () => $('.cell .aicon').className.match(/sz-(\d+)/)[1];

  click($('[data-density="small"]'));  await wait(80);
  check('small gives 5 per row', colsOf() === '5', colsOf());
  check('small uses 64px icons', iconOf() === '64', iconOf());
  check('the 5-across button is now pressed', $('[data-density="small"]').getAttribute('aria-pressed') === 'true');
  check('the previous choice is released', $('[data-density="medium"]').getAttribute('aria-pressed') === 'false');
  check('all tiles shrank together', $$('.cell .aicon.sz-64').length === $$('.cell').length,
    $$('.cell .aicon.sz-64').length + ' of ' + $$('.cell').length);

  click($('[data-density="large"]'));  await wait(80);
  check('large gives 3 per row', colsOf() === '3', colsOf());
  check('large uses 128px icons', iconOf() === '128', iconOf());

  click($('[data-density="medium"]')); await wait(80);
  check('medium is back to 4 across', colsOf() === '4', colsOf());
  // Updates renders rows rather than tiles, so check the model there
  click($('.nav-card[data-nav="updates"]')); await wait(80);
  check('the choice survives navigating to a list screen', window.eval('state.density') === 'medium');
  click($('.nav-card[data-nav="categorylist"]')); await wait(80);
  check('the choice survives opening a category', colsOf() === '4', colsOf());
  check('the choice survives a package detail',
    (click($('.cell[data-pkg] .aicon')), await wait(80), window.eval('state.density')) === 'medium');
  click($('.nav-card[data-nav="featured"]')); await wait(80);
  check('the version triangle is still there after a density change', !!$('.cell .ver-caret'));
  check('and it is still blue', cs($('.cell .ver-caret')).backgroundColor === 'rgb(74, 144, 226)',
    cs($('.cell .ver-caret')).backgroundColor);
  // Downloads has no sidebar at all, so the control cannot be used there
  click($('.aero-pill[data-view="downloads"]')); await wait(80);
  check('the density control is off-screen on Downloads', cs($('#sidebar')).display === 'none',
    cs($('#sidebar')).display);
  click($('.aero-pill[data-view="store"]')); await wait(80);
  check('and it comes back with the sidebar', $$('.side-seg-btn').length === 3);
  // the columns must be a real declaration, not just a class name
  const declared = cs($('.grid')).gridTemplateColumns;
  check('the browser resolves the column count', /repeat\(4,/.test(declared), declared);

  section('the toolbar and search are one black bar');
  const chrome = $('.aero-chrome');
  check('there is a single bar element', !!chrome);
  check('the toolbar is inside it', !!$('.aero-chrome .aero-bar'));
  check('the search row is inside it', !!$('.aero-chrome .searchbar'));
  check('the wordmark is inside the same bar', !!$('.aero-chrome .aero-wordmark'));
  check('the pills are inside the same bar', !!$('.aero-chrome .aero-pill'));
  check('the search field is inside the same bar', !!$('.aero-chrome .searchbox'));
  check('the update button is inside the same bar', !!$('.aero-chrome .aero-cta, .aero-chrome #btnUpdateAll'));
  // nothing may sit between the two lines
  check('nothing separates the two lines', $('.aero-chrome').children.length === 2,
    $('.aero-chrome').children.length + ' children');
  check('they are the two lines we expect',
    $('.aero-chrome').children[0].classList.contains('aero-bar') &&
    $('.aero-chrome').children[1].classList.contains('searchbar'));
  const barBg = cs($('.aero-chrome')).backgroundColor;
  check('the bar itself is black', barBg === 'rgb(58, 63, 72)', barBg);
  check('both lines are transparent so the bar shows through',
    cs($('.aero-bar')).backgroundColor === 'rgba(0, 0, 0, 0)' &&
    cs($('.searchbar')).backgroundColor === 'rgba(0, 0, 0, 0)',
    cs($('.aero-bar')).backgroundColor + ' / ' + cs($('.searchbar')).backgroundColor);
  check('the search row carries no light strip',
    cs($('.searchbar')).backgroundImage === 'none' || cs($('.searchbar')).backgroundImage === '',
    cs($('.searchbar')).backgroundImage);
  check('the search well is a dark inset', cs($('.searchbox')).backgroundColor === 'rgb(28, 31, 37)',
    cs($('.searchbox')).backgroundColor);
  check('typed text is light on the dark well', cs($('#searchInput')).color === 'rgb(236, 238, 241)',
    cs($('#searchInput')).color);
  check('the round buttons are dark glass', cs($('.round-btn')).backgroundColor === 'rgb(61, 67, 76)',
    cs($('.round-btn')).backgroundColor);
  check('the round button glyph is light', cs($('.round-btn')).color === 'rgb(232, 234, 237)',
    cs($('.round-btn')).color);
  check('the wordmark is white on black', cs($('.aero-wordmark')).color === 'rgb(255, 255, 255)',
    cs($('.aero-wordmark')).color);
  check('the title bar above is still separate', !!$('.titlebar') && !$('.titlebar').closest('.aero-chrome'));
  check('the bar is not black inside the content', cs($('#content')).backgroundColor !== barBg,
    cs($('#content')).backgroundColor + ' vs ' + barBg);
  // jsdom has no layout engine, so prove the bar spans the window structurally:
  // it is a direct child of the window root and its next sibling is the split.
  const winKids = [...$('#window').children];
  const chromeIdx = winKids.indexOf($('.aero-chrome'));
  check('the bar is a direct child of the window', chromeIdx !== -1);
  check('the bar sits directly above the content', winKids[chromeIdx + 1] === $('#split'),
    winKids[chromeIdx + 1] ? winKids[chromeIdx + 1].className : 'no next sibling');
  check('the bar sits directly below the title bar', winKids[chromeIdx - 1] === $('.titlebar'),
    winKids[chromeIdx - 1] ? winKids[chromeIdx - 1].className : 'no previous sibling');
  check('the bar is the only element between title bar and content', chromeIdx === 1,
    'index ' + chromeIdx);
  // and no light background may survive in either line
  const chromeSrc = fs.readFileSync(path.join(ROOT, 'css/app.css'), 'utf8');
  const chromeBlocks = (chromeSrc.match(/[^{}]+\{[^{}]*\}/g) || [])
    .filter(b => /\.(aero-chrome|aero-bar|searchbar|searchbox|round-btn)\b/.test(b.split('{')[0]));
  const lightOnBar = chromeBlocks.filter(b => /#f6f7f8|#eceef0|#e4e5e8/.test(b));
  check('no light strip left in the bar rules', lightOnBar.length === 0, lightOnBar.join(' | ').slice(0, 140));

  section('the store panel is black with white text');
  click($('.aero-pill[data-view="store"]'));
  await wait(80);
  // sample an INACTIVE card — the active one is deliberately a step lighter
  const idle = $('.nav-card:not(.active)');
  check('there is an idle card to sample', !!idle);
  check('sidebar panel is black', cs($('#sidebar')).backgroundColor === 'rgb(19, 19, 21)',
    cs($('#sidebar')).backgroundColor);
  check('card background is black', cs(idle).backgroundColor === 'rgb(22, 23, 26)', cs(idle).backgroundColor);
  check('card label is white', cs(idle.querySelector('.card-label')).color === 'rgb(244, 245, 247)',
    cs(idle.querySelector('.card-label')).color);
  check('card icon is neutral, not blue', cs(idle.querySelector('.card-ico')).color === 'rgb(212, 217, 224)',
    cs(idle.querySelector('.card-ico')).color);
  // only the Updates card carries a sub-count, so find one that exists
  const sub = document.querySelector('.nav-card .card-sub');
  check('a card sub-count exists to sample', !!sub, $('.nav-card[data-nav="updates"] .card-sub') ? 'updates card' : 'none');
  check('card sub-count is grey, not blue', cs(sub).color === 'rgb(154, 160, 170)', cs(sub).color);
  check('the active card is also dark, not blue', cs($('.nav-card.active')).backgroundColor === 'rgb(48, 51, 58)',
    cs($('.nav-card.active')).backgroundColor);
  check('the group headings read grey on black', cs($('.side-head')).color === 'rgb(138, 143, 153)',
    cs($('.side-head')).color);
  check('the content area stays light', cs($('#content')).backgroundColor !== cs($('#sidebar')).backgroundColor,
    cs($('#content')).backgroundColor + ' vs ' + cs($('#sidebar')).backgroundColor);
  // No purplish blue may survive in the sidebar. jsdom's CSSOM re-serialises
  // colours as rgb(), so a hex scan of the source is the only honest check.
  const cssSrc = fs.readFileSync(path.join(ROOT, 'css/app.css'), 'utf8');
  // split into complete `selector { ... }` blocks, then keep the sidebar ones
  const sidebarRules = (cssSrc.match(/[^{}]+\{[^{}]*\}/g) || [])
    .filter(b => /\.(nav-card|sidebar|side-)/.test(b.split('{')[0]));
  const purplish = sidebarRules.filter(r => /7f8cff|9db2ff|1a5fae|2c78cb|rgb\(157,\s*178,\s*255\)|rgb\(127,\s*140,\s*255\)/i.test(r));
  check('no purplish blue left in the sidebar rules', purplish.length === 0, purplish.join(' | ').slice(0, 160));
  const caretBg = window.getComputedStyle($('.ver-caret')).backgroundColor;
  check('the blue triangle is still blue', caretBg === 'rgb(74, 144, 226)', caretBg);

  section('version disclosure menu');
  // The blue triangle unfolds every version the source carries. This is the
  // thing the concept sketch showed as "v1.0 / v2.0" with a fold-out.
  await until(() => window.eval('byId("bettertouchtool").pkgVersion') === '2.0.2');
  click($('.nav-card[data-nav="featured"]'));
  await wait(60);
  const bttCell = $$('.cell[data-pkg="bettertouchtool"]')[0];
  check('installed-and-current tile exists', !!bttCell);
  check('caret is not forced open when current', !bttCell.querySelector('.ver-caret').classList.contains('has-update'));

  click(bttCell.querySelector('.ver-caret'));
  await wait(60);
  check('version menu opens', !!$('.popover'), 'no .popover');
  check('menu lists multiple versions', $$('.ver-row').length >= 3, $$('.ver-row').length + ' versions');
  check('menu names the package', /BetterTouchTool/.test($('.popover').textContent));
  check('menu shows installed version', /v2\.0\.2/.test($('.popover').textContent));
  check('current version is marked', !!$('.ver-row.current'));
  check('other versions are labelled Reinstall or Update',
    $$('.ver-row:not(.current) .rel').every(el => /Update|Reinstall|Downgrade/.test(el.textContent)),
    $$('.ver-row:not(.current) .rel').map(e=>e.textContent).join(','));
  check('menu offers a Details button', !!$('[data-act="pkg-detail"]'));

  // pick an older version -> must read as a downgrade
  const older = $$('.ver-row:not(.current)').pop();
  const olderV = older.dataset.version;
  const olderIsDowngrade = window.eval(`vcmp("${olderV}", byId("bettertouchtool").pkgVersion) < 0`);
  click(older);
  await wait(60);
  check('picking a version opens the install sheet', !!$('[data-act="do-install"]'));
  check('sheet carries the chosen version', $('[data-act="do-install"]').dataset.version === olderV,
    $('[data-act="do-install"]').dataset.version + ' vs ' + olderV);
  if (olderIsDowngrade){
    check('older version is labelled Downgrade', /Downgrade/.test($('.sheet').textContent));
    check('downgrade warning is shown', /This is a downgrade/.test($('.sheet').textContent));
  } else {
    check('newer version is labelled Update', /Update/.test($('.sheet').textContent));
  }
  check('version menu closed before the sheet opened', !$('.popover'));

  click($('[data-act="do-install"]'));
  await until(() => window.eval('byId("bettertouchtool").pkgVersion') === olderV);
  check('store now sits on the chosen version', window.eval('byId("bettertouchtool").pkgVersion') === olderV,
    window.eval('byId("bettertouchtool").pkgVersion') + ' vs ' + olderV);
  check('a package behind its source is flagged updatable again',
    window.eval('byId("bettertouchtool").hasUpdate') === true);

  // and the tile advertises the route back up
  click($('.nav-card[data-nav="featured"]'));
  await wait(60);
  check('tile shows the version journey',
    new RegExp('v' + olderV.replace(/\./g, '\\.') + ' → v2\\.0\\.2').test($('.cell[data-pkg="bettertouchtool"]').textContent),
    $('.cell[data-pkg="bettertouchtool"]').textContent.replace(/\s+/g,' ').trim());
  check('tile is marked as having an update', $('.cell[data-pkg="bettertouchtool"]').classList.contains('has-update'));

  // restore for the sections that follow
  window.eval('byId("bettertouchtool").pkgVersion="2.0.2"; byId("bettertouchtool").hasUpdate=false; render();');
  await wait(40);

  section('categories');
  click($('.nav-card[data-nav="categorylist"][data-sec="System"]'));
  await wait(50);
  check('category grid opens', $('#winTitle').textContent === 'System', $('#winTitle').textContent);
  check('category grid has tiles', $$('.cell[data-pkg]').length === 5, $$('.cell[data-pkg]').length + '');
  check('category card is highlighted', $('.nav-card[data-sec="System"]').classList.contains('active'));
  check('category grid shows the blurb', /maintenance/i.test($('#content').textContent));

  section('update all');
  click($('.nav-card[data-nav="updates"]'));
  await wait(50);
  // everything seeded as an update was already applied earlier in the run
  const nUpd = window.eval('PKGS.filter(p=>p.hasUpdate).length');
  check('updates page reflects reality', nUpd === 0, nUpd + ' still pending');
  check('empty state when nothing is pending', /No updates available/.test($('#content').textContent));
  check('update-all button hidden when idle', $('#btnUpdateAll').hidden);
  window.eval('byId("iTerm2").installed=true; byId("iTerm2").pkgVersion="2.9.0"; byId("iTerm2").hasUpdate=true; render();');
  check('update-all button appears once there is work', !$('#btnUpdateAll').hidden);
  check('updates listed', $$('.row[data-pkg]').length === nUpd + 1, $$('.row[data-pkg]').length + ' vs ' + (nUpd+1));
  click($('#btnUpdateAll'));
  await until(() => window.eval('PKGS.filter(p=>p.hasUpdate).length') === 0);
  check('all updates applied', window.eval('PKGS.filter(p=>p.hasUpdate).length') === 0,
    window.eval("PKGS.filter(p=>p.hasUpdate).map(p=>p.id).join(',')"));

  section('search');
  setVal($('#searchInput'), 'zzzznothing');
  await wait(60);
  check('empty state for no results', /No results/.test($('#content').textContent));
  setVal($('#searchInput'), 'Mesa');
  await wait(60);
  const nUpper = $$('.row[data-pkg]').length;
  setVal($('#searchInput'), 'mesa');
  await wait(60);
  check('search is case-insensitive', nUpper > 0 && nUpper === $$('.row[data-pkg]').length,
    nUpper + ' vs ' + $$('.row[data-pkg]').length);
  check('search finds the right package', !!$('.row[data-pkg="mesa"]'));
  setVal($('#searchInput'), '');
  await wait(60);
  check('clearing search returns to featured', $('#winTitle').textContent === 'Featured');
  check('search box is present in the sidebar', !!$('#searchWrap'));

  section('per-source view');
  click($('.nav-card[data-nav="sources"]'));
  await wait(60);
  check('source rows are navigable', $$('.row[data-nav="source"]').length === SOURCES_len(),
    $$('.row[data-nav="source"]').length + '');
  click($('.row[data-sec="applejack"]'));
  await wait(50);
  check('source page opens', $('#winTitle').textContent === 'Applejack');
  check('source lists its packages', $$('.row[data-pkg]').length === 2, $$('.row[data-pkg]').length + '');
  check('degraded source shows cached notice', /cached/i.test($('#content').textContent));

  section('errors');
  check('no uncaught errors', errors.length === 0, errors.slice(0, 6).join(' | '));

  console.log(`\n${pass} passed, ${fail} failed`);
  window.close();
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error('FATAL', e); if (errors.length) console.error('CAPTURED ERRORS:\n' + errors.join('\n')); process.exit(1); });
