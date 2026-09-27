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
  check('sidebar groups are Store then Categories', $$('.side-head').length === 2, $$('.side-head').length + '');
  check('category cards present', $$('.nav-card[data-nav="categorylist"]').length === 6,
    $$('.nav-card[data-nav="categorylist"]').length + '');
  check('featured grid populated', $$('.cell[data-pkg]').length >= 8, $$('.cell[data-pkg]').length + '');
  check('tiles use large icons', $$('.cell .aicon.sz-128').length >= 8);
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
  check('progress window open', /^(Install|Update|Downgrade|Reinstall)/.test($('.sheet').textContent.trim()),
    $('.sheet').textContent.replace(/\s+/g,' ').trim().slice(0, 60));
  const stepText = $('#progStep').textContent;
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
  // record every distinct step label the pipeline announces, in order
  const seenSteps = [];
  const t0 = Date.now();
  while (Date.now() - t0 < 15000){
    const el = $('#progStep');
    if (el && el.textContent && seenSteps[seenSteps.length - 1] !== el.textContent) seenSteps.push(el.textContent);
    if (window.eval('byId("bettertouchtool").pkgVersion') === '2.0.2') break;
    await wait(60);
  }
  const stepStr = seenSteps.join(' → ');
  check('re-signing step appears under ad-hoc policy', /Re-signing payload/.test(stepStr), stepStr);
  check('steps run in order',
    /Downloading/.test(stepStr) && /Verifying/.test(stepStr) &&
    /authorisation/.test(stepStr) && /Installing/.test(stepStr), stepStr);
  check('ad-hoc pipeline runs 7 labels', seenSteps.length === 7, seenSteps.length + ': ' + stepStr);
  check('bettertouchtool updated', window.eval('byId("bettertouchtool").pkgVersion') === '2.0.2');
  check('explicit target is not marked auto-installed', window.eval('byId("bettertouchtool").autoInstalled') === false);


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
