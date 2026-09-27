/* ============================================================
   TCD Store — prototype application logic
   Written so that every screen maps 1:1 onto an NSViewController
   in the Objective-C port.
   ============================================================ */

const $  = s => document.querySelector(s);
const $$ = s => Array.prototype.slice.call(document.querySelectorAll(s));
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const byId = id => PKGS.filter(p => p.id === id)[0];

const SVG_PX = { 14:10, 28:18, 44:28, 64:40, 96:60, 128:80 };

function icon(p, size){
  size = size || 44;
  return `<div class="aicon sz-${size}" style="background:linear-gradient(160deg,${p._accent[0]},${p._accent[1]});color:#fff">
    <svg viewBox="0 0 24 24" width="${SVG_PX[size]}" height="${SVG_PX[size]}" aria-hidden="true">${p._glyph}</svg></div>`;
}
function stars(n){
  let s = '';
  for (let i = 1; i <= 5; i++) s += `<svg viewBox="0 0 24 24" width="12" height="12" class="${i<=n?'':'off'}"><path fill="currentColor" d="M12 2.2l3 6.3 6.9.9-5 4.8 1.3 6.8L12 17.8 5.8 21l1.3-6.8-5-4.8 6.9-.9z"/></svg>`;
  return s;
}
function bytes(n){
  if (n >= 1048576) return (n/1048576).toFixed(1) + ' MB';
  if (n >= 1024)    return Math.round(n/1024) + ' KB';
  return n + ' B';
}
function typeLabel(t){ return { app:'Application', pkg:'System Package', kext:'Kernel Extension', prefpane:'Preference Pane' }[t] || t; }
function typeTag(t){
  const c = { app:'inst', pkg:'new', kext:'dep', prefpane:'new' }[t] || 'new';
  return `<span class="tag tag-${c}">${typeLabel(t)}</span>`;
}
function srcName(id){
  const s = SOURCES.filter(x => x.id === id)[0];
  return s ? s.name : id;
}

/* ============================================================
   Downloads
   Not a mock: the install engine pushes into TRANSFERS as it runs and
   files into HISTORY when it lands, so this screen is a readout of
   real state rather than a decoration.
   ============================================================ */
const TRANSFERS = [];   // { key, name, version, verb, step, fraction, pkgs, logs }
const HISTORY   = [];   // { name, version, verb, when }
const STEP_LOG  = [];   // every distinct step the engine announces, in order
let transferSeq = 0;
function relTime(d){
  const s = Math.max(0, Math.round((Date.now() - d.getTime()) / 1000));
  if (s < 45)   return 'just now';
  if (s < 3600) return Math.round(s / 60) + ' min ago';
  if (s < 86400) return Math.round(s / 3600) + ' h ago';
  return Math.round(s / 86400) + ' d ago';
}

/* ---------------- state ---------------- */
const state = {
  view: 'store',          // store | downloads — the top-level pill
  route: 'featured',     // featured | category | updates | installed | search | sources | settings | pkg
  section: null,
  pkgId: null,
  tab: 'description',    // description | shots | changelog | deps
  query: '',
  tabState: {},          // per-package tab memory
  back: []
};

/* ============================================================
   SIGNING POLICY  (the thing we said we'd advise on)
   ============================================================ */
const SIGN_POLICIES = {
  optin: {
    key:'optin', title:'User opt-in (recommended)',
    desc:'Never touch the signature of an installed payload. The store ships a self-signed certificate and an spctl profile, and walks the user through enabling it on first launch.',
    pro:'No privileged helper needed. Works on a stock 10.7+ Mac. Nothing we do can break a working signature.',
    con:'Some payloads still prompt on first open. Support burden stays with the user.'
  },
  adhoc: {
    key:'adhoc', title:'Ad-hoc re-sign installed payloads',
    desc:'After an install, re-sign every bundle on the receipt payload path with the TCD Store identity so the payload launches clean without any prompt.',
    pro:'Everything you install just works. Kexts load without System Integrity fuss.',
    con:'Requires a persistent privileged helper. Re-signing a payload Apple has its own trust relationship with can invalidate an existing licence check.'
  }
};
let policy = 'optin';

/* ============================================================
   dependency resolution  → the install plan
   ============================================================ */
function resolvePlan(pkg){
  const plan = [], seen = {};
  (function add(p){
    if (!p || seen[p.id]) return;
    seen[p.id] = true;
    p.depends.forEach(function(d){ const dp = byId(d); if (dp) add(dp); });
    plan.push(p);
  })(pkg);
  return plan;
}
function planConflicts(plan){
  const out = [];
  plan.forEach(function(p){
    p.conflicts.forEach(function(c){
      const other = byId(c);
      if (other && other.installed) out.push({ pkg:p, other:other });
    });
  });
  return out;
}
function dependentsOf(p){
  return PKGS.filter(x => x.depends.indexOf(p.id) !== -1 && x.installed);
}
/* Packages that were pulled in only as dependencies AND that live inside the
   dependency closure of the package being removed. This is Cydia's "orphaned
   autoremove". A package with no dependents is NOT enough on its own — an
   installed app's dependency has no dependents either, and taking it would
   break the app. */
function orphansAfterRemoving(pkg){
  const going = {};
  going[pkg.id] = true;
  const orphans = [];
  let changed = true;
  while (changed){
    changed = false;
    PKGS.forEach(function(x){
      if (!x.installed || !x.autoInstalled || going[x.id]) return;
      // x only goes if something already in the removal set depends on x
      const needed = PKGS.some(function(y){
        return going[y.id] && y.depends.indexOf(x.id) !== -1;
      });
      if (needed){
        going[x.id] = true;
        orphans.push(x.id);
        changed = true;
      }
    });
  }
  return orphans.map(byId);
}

/* ============================================================
   SIDEBAR
   ============================================================ */
function renderSidebar(){
  $('#split').classList.toggle('no-sidebar', state.view === 'downloads');
  const nUpd = PKGS.filter(p => p.hasUpdate).length;
  const nIns = PKGS.filter(p => p.installed).length;
  const s = [];

  s.push(`<div class="side-head">Store</div>`);
  s.push(card('featured',  'star',     'Featured',  null));
  s.push(card('updates',   'download', 'Updates',   nUpd ? String(nUpd) : null));
  s.push(card('installed', 'archive',  'Installed', String(nIns)));
  s.push(card('sources',   'server',   'Sources',   String(SOURCES.length)));
  s.push(card('settings',  'gear',     'Settings',  null));

  s.push(`<div class="side-head">Categories</div>`);
  CATEGORIES.forEach(function(c){
    const n = PKGS.filter(p => p.section === c.key).length;
    if (!n) return;
    const g = ICON_DEFS[c.icon[0]], gl = GLYPHS[c.icon[1]] || GLYPHS.cube;
    const active = state.route === 'categorylist' && state.section === c.key;
    s.push(`<div class="nav-card${active ? ' active' : ''}" data-nav="categorylist" data-sec="${c.key}">
      <span class="card-ico">${navGlyph(c.icon[1])}</span>
      <span class="card-label">${c.key}</span>
      <span class="card-sub">${n}</span>
    </div>`);
  });

  $('#sidebar').innerHTML = s.join('');
}
function card(route, glyph, label, count){
  return `<div class="nav-card${state.route === route ? ' active' : ''}" data-nav="${route}">
    <span class="card-ico">${navGlyph(glyph)}</span>
    <span class="card-label">${label}</span>
    ${count ? `<span class="card-sub">${count}</span>` : ''}</div>`;
}

const NAV_G = {
  star:`<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" stroke="none"><path d="M12 2.2l3 6.3 6.9.9-5 4.8 1.3 6.8L12 17.8 5.8 21l1.3-6.8-5-4.8 6.9-.9z"/></svg>`,
  layers:`<svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 2.4l9.5 4.9L12 12.2 2.5 7.3z" fill="currentColor" opacity=".4"/><path d="M2.5 12.2L12 17l9.5-4.8-9.5-4.8zM2.5 16.6L12 21.4l9.5-4.8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>`,
  download:`<svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3v11m0 0 4.2-4.2M12 14l-4.2-4.2M4 19.5h16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  search:`<svg viewBox="0 0 24 24" width="15" height="15"><circle cx="10.5" cy="10.5" r="6.4" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M15.2 15.2L20 20" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>`,
  archive:`<svg viewBox="0 0 24 24" width="15" height="15"><rect x="2.6" y="3.6" width="18.8" height="4.8" rx="1.6" fill="currentColor"/><path d="M4.6 8.6h14.8v9.6a2 2 0 0 1-2 2H6.6a2 2 0 0 1-2-2z" fill="currentColor" opacity=".42"/><path d="M4.6 8.6h14.8v9.6a2 2 0 0 1-2 2H6.6a2 2 0 0 1-2-2z" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M10 12.4h4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>`,
  server:`<svg viewBox="0 0 24 24" width="15" height="15"><rect x="2.6" y="3.2" width="18.8" height="7" rx="1.8" fill="currentColor" opacity=".35"/><rect x="2.6" y="3.2" width="18.8" height="7" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/><rect x="2.6" y="13.8" width="18.8" height="7" rx="1.8" fill="currentColor" opacity=".35"/><rect x="2.6" y="13.8" width="18.8" height="7" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/><g fill="currentColor"><circle cx="6" cy="6.7" r="1.15"/><circle cx="6" cy="17.3" r="1.15"/></g><g stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M10.4 6.7h7M10.4 17.3h7"/></g></svg>`,
  gear:`<svg viewBox="0 0 24 24" width="15" height="15"><path d="M19.6 13.4a7.9 7.9 0 0 0 0-2.8l2-1.5-2-3.4-2.4 1a7.7 7.7 0 0 0-2.4-1.4l-.4-2.6h-4l-.4 2.6c-.9.3-1.7.8-2.4 1.4l-2.4-1-2 3.4 2 1.5a7.9 7.9 0 0 0 0 2.8l-2 1.5 2 3.4 2.4-1c.7.6 1.5 1.1 2.4 1.4l.4 2.6h4l.4-2.6c.9-.3 1.7-.8 2.4-1.4l2.4 1 2-3.4z" fill="currentColor" opacity=".35"/><path d="M19.6 13.4a7.9 7.9 0 0 0 0-2.8l2-1.5-2-3.4-2.4 1a7.7 7.7 0 0 0-2.4-1.4l-.4-2.6h-4l-.4 2.6c-.9.3-1.7.8-2.4 1.4l-2.4-1-2 3.4 2 1.5a7.9 7.9 0 0 0 0 2.8l-2 1.5 2 3.4 2.4-1c.7.6 1.5 1.1 2.4 1.4l.4 2.6h4l.4-2.6c.9-.3 1.7-.8 2.4-1.4l2.4 1 2-3.4z" fill="none" stroke="currentColor" stroke-width="1.35"/><circle cx="12" cy="12" r="2.9" fill="currentColor"/></svg>`
};
/* Nav icons are the dark cards' own set; anything else falls back to the
   package glyph set so a category can reuse its own icon. */
function navGlyph(k){
  if (NAV_G[k]) return NAV_G[k];
  return GLYPHS[k] ? `<svg viewBox="0 0 24 24" width="15" height="15">${GLYPHS[k]}</svg>` : '';
}

/* ============================================================
   CONTENT ROUTER
   ============================================================ */
/* Store | Downloads. Switching to Downloads leaves the Store's last route
   intact underneath, so coming back lands where you were. */
function setView(view, force){
  // `force` matters: a run that starts while the user already sits on Downloads
  // still has to land its row on screen, and the early return would swallow it.
  if (state.view === view && !force) return;
  state.view = view;
  if (view === 'downloads'){ state.route = 'downloads'; state.back = []; }
  else { state.route = 'featured'; }
  $$('.aero-pill').forEach(function(b){
    const on = b.dataset.view === view;
    b.classList.toggle('active', on);
    b.setAttribute('aria-selected', on ? 'true' : 'false');
  });
  const active = TRANSFERS.length;
  const dl = $('.aero-pill[data-view="downloads"]');
  if (active && !dl.querySelector('.pill-badge')){
    const b = document.createElement('span');
    b.className = 'pill-badge';
    b.textContent = String(active);
    dl.appendChild(b);
  } else if (!active && dl.querySelector('.pill-badge')){
    dl.querySelector('.pill-badge').remove();
  }
  $('#content').scrollTop = 0;
  render();
}

function go(route, opts){
  opts = opts || {};
  if (state.route === 'pkg' && route !== 'pkg' && !opts.replace){
    state.back.push({ route:state.route, section:state.section, pkgId:state.pkgId, query:state.query });
  }
  if (opts.replace) state.back = [];
  state.route = route;
  if ('section' in opts) state.section = opts.section;
  if ('query'   in opts) state.query   = opts.query;
  if (opts.pkgId){
    state.pkgId = opts.pkgId;
    if (!opts.keepTab) state.tab = (state.tabState[opts.pkgId] || 'description');
  }
  if (opts.tab){
    state.tab = opts.tab;
    if (state.pkgId) state.tabState[state.pkgId] = opts.tab;
  }
  const c = $('#content');
  c.scrollTop = 0;
  render();
}
function goBack(){
  const p = state.back.pop();
  if (!p){ go('featured', { replace:true }); return; }
  state.route = p.route; state.section = p.section; state.pkgId = p.pkgId;
  state.query = p.query || '';
  $('#searchInput').value = state.query;
  $('#searchClear').hidden = !state.query;
  render();
}

function render(){
  renderSidebar();
  const c = $('#content');
  c.innerHTML = ({
    featured:  viewFeatured,
    category:  viewCategory,
    categorylist: viewCategoryList,
    updates:   viewUpdates,
    installed: viewInstalled,
    search:    viewSearch,
    sources:   viewSources,
    source:    viewSource,
    settings:  viewSettings,
    downloads: viewDownloads,
    pkg:       viewPackage
  }[state.route] || viewFeatured)();
  renderStatus();
  renderToolbar();
}

function renderToolbar(){
  const upd = PKGS.filter(p => p.hasUpdate);
  $('#btnBack').disabled = !state.back.length && state.route !== 'pkg';
  $('#btnUpdateAll').hidden = !(upd.length && (state.route === 'updates'));
  // The sidebar belongs to Store. Downloads is a full-width screen.
  const showSearch = state.route !== 'settings' && state.view === 'store';
  $('#searchWrap').style.visibility = showSearch ? 'visible' : 'hidden';
  const titles = {
    downloads:'Downloads',
    featured:'Featured', category:'Categories', categorylist: state.section || 'Category',
    updates:'Updates', installed:'Installed',
    search:'Search', sources:'Sources', source: srcName(state.section), settings:'Settings',
    pkg: (byId(state.pkgId) || {}).name || ''
  };
  $('#winTitle').textContent = titles[state.route] || 'TCD Store';
  $('#mbAppName').textContent = titles[state.route] || 'TCD Store';
}

function renderStatus(){
  const errs = SOURCES.filter(s => s.status === 'err').length;
  const warn = SOURCES.filter(s => s.status === 'warn').length;
  const upd  = PKGS.filter(p => p.hasUpdate).length;
  const ins  = PKGS.filter(p => p.installed).length;
  const dot  = errs ? 'err' : (warn ? 'warn' : 'ok');
  $('#statusbar').innerHTML =
    `<span><span class="status-dot ${dot}"></span>${errs ? errs+' source unreachable' : (warn ? warn+' source degraded' : 'All sources up to date')}</span>
     <span class="grow"></span>
     <span>${ins} installed</span>
     <span>·</span>
     <span>${upd ? upd+' update' + (upd>1?'s':'') + ' available' : 'No updates'}</span>
     <span>·</span>
     <span class="status-pill">Identity: TCD Store 2013</span>`;
}

/* ---------------- views ---------------- */
function viewFeatured(){
  const feat = ['bettertouchtool','mesa','handbrake','fakesmc','sublimetext','iterm2','cyberduck','onyx'];
  const picks = feat.map(byId).filter(Boolean);
  const recent = PKGS.filter(p => !p.installed).slice(0, 6);
  return `<div class="pad">
    <h1 class="sec-title">Featured</h1>
    <p class="sec-sub">Curated packages that still work on Lion, Mountain Lion and Mavericks.</p>
    <div class="grid">${picks.map(p => cell(p)).join('')}</div>
    <div class="group-title">Also worth a look</div>
    <div class="grid">${recent.map(p => cell(p)).join('')}</div>
  </div>`;
}
/* One tile in the large icon grid. The blue triangle in the corner is the
   version disclosure — it unfolds a menu offering every version the source
   carries, so you can install, update or roll back. */
function cell(p){
  const sub = p.hasUpdate ? 'v' + p.pkgVersion + ' → v' + p.version
            : p.installed ? 'v' + p.pkgVersion
            : 'v' + p.version;
  const subCls = p.hasUpdate ? ' upd' : (p.installed ? ' inst' : '');
  return `<div class="cell${p.hasUpdate ? ' has-update' : ''}" data-pkg="${p.id}">
    <button class="ver-caret" data-act="versions" data-pkg="${p.id}"
            title="Other versions of ${esc(p.name)}" aria-label="Other versions">
      <svg viewBox="0 0 16 16" width="11" height="11"><path d="M3.5 6L8 10.5 12.5 6z" fill="currentColor"/></svg>
    </button>
    ${icon(p,128)}
    <div class="name">${esc(p.name)}</div>
    <div class="sub${subCls}">${sub}</div>
  </div>`;
}

function viewCategory(){
  return `<div class="pad">
    <h1 class="sec-title">Categories</h1>
    <p class="sec-sub">${PKGS.length} packages across ${CATEGORIES.length} categories.</p>
    <div class="grid">${CATEGORIES.map(function(c){
      const n = PKGS.filter(p => p.section === c.key).length;
      const g = ICON_DEFS[c.icon[0]], gl = GLYPHS[c.icon[1]] || GLYPHS.cube;
      return `<div class="cell" data-cat="${c.key}">
        <div class="aicon sz-128" style="background:linear-gradient(160deg,${g[0]},${g[1]});color:#fff">
          <svg viewBox="0 0 24 24" width="64" height="64">${gl}</svg></div>
        <div class="name">${c.key}</div><div class="sub">${n} package${n===1?'':'s'}</div></div>`;
    }).join('')}</div>
  </div>`;
}

function viewCategoryList(sec){
  sec = sec || state.section;
  const meta = CATEGORIES.filter(c => c.key === sec)[0];
  const list = PKGS.filter(p => p.section === sec);
  return `<div class="pad">
    <h1 class="sec-title">${esc(sec)}</h1>
    <p class="sec-sub">${meta ? esc(meta.blurb) + ' ' : ''}${list.length} package${list.length===1?'':'s'}.</p>
    <div class="grid">${list.map(p => cell(p)).join('')}</div>
  </div>`;
}

function row(p, right){
  const tags = [];
  if (p.hasUpdate)  tags.push(`<span class="tag tag-upd">Update ${esc(p.pkgVersion)} → ${esc(p.version)}</span>`);
  else if (p.installed) tags.push(`<span class="tag tag-inst">Installed</span>`);
  else if (p.type === 'kext') tags.push(`<span class="tag tag-dep">Kext</span>`);
  return `<div class="row" data-pkg="${p.id}">${icon(p,44)}
    <div class="row-main">
      <div class="row-name">${esc(p.name)} ${tags.join(' ')}</div>
      <div class="row-sub">${esc(p.summary)}</div>
    </div>
    <div class="row-right">
      <span style="font-size:12px;color:var(--ink-3)">${bytes(p.size)}</span>
      ${p.hasUpdate ? `<button class="pill primary" data-act="install" data-pkg="${p.id}">Update</button>`
        : p.installed ? `<button class="pill" data-act="remove" data-pkg="${p.id}">Remove</button>`
        : `<button class="pill primary" data-act="install" data-pkg="${p.id}">Get</button>`}
    </div></div>`;
}

function viewUpdates(){
  const list = PKGS.filter(p => p.hasUpdate);
  if (!list.length) return `<div class="pad">${emptyState('No updates available','Every installed package is at the newest version in its source.')}</div>`;
  return `<div class="pad">
    <h1 class="sec-title">Updates</h1>
    <p class="sec-sub">${list.length} package${list.length===1?'':'s'} can be updated. Installing a .pkg may prompt for your password.</p>
    ${list.some(p => p.type !== 'app') ? `<div class="notice"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3.2l9.2 16H2.8z" fill="currentColor" opacity=".3"/><path d="M12 3.2l9.2 16H2.8z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 9.5v5M12 17.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
      <div class="grow"><b>System-level updates included.</b> ${list.filter(p=>p.type!=='app').map(p=>p.name).join(', ')} install outside /Applications. Read the package detail before updating.</div></div>` : ''}
    <div class="rows">${list.map(p => row(p)).join('')}</div>
  </div>`;
}

function viewInstalled(){
  const list = PKGS.filter(p => p.installed).sort((a,b) => a.name.localeCompare(b.name));
  if (!list.length) return `<div class="pad">${emptyState('Nothing installed yet','Packages you install will be listed here with their version and source.')}</div>`;
  return `<div class="pad">
    <h1 class="sec-title">Installed</h1>
    <p class="sec-sub">${list.length} package${list.length===1?'':'s'} installed on this Mac.</p>
    <div class="rows">${list.map(p => row(p)).join('')}</div>
  </div>`;
}

function viewSearch(){
  const q = state.query.trim().toLowerCase();
  if (!q) return `<div class="pad">${emptyState('Search TCD Store','Type a name, a developer, or a category.')}</div>`;
  const res = PKGS.filter(p =>
    p.name.toLowerCase().indexOf(q) !== -1 ||
    p.summary.toLowerCase().indexOf(q) !== -1 ||
    p.developer.toLowerCase().indexOf(q) !== -1 ||
    p.section.toLowerCase().indexOf(q) !== -1);
  if (!res.length) return `<div class="pad">${emptyState('No results', `Nothing in any source matches “${esc(state.query)}”.`)}</div>`;
  return `<div class="pad">
    <h1 class="sec-title">Search</h1>
    <p class="sec-sub">${res.length} result${res.length===1?'':'s'} for “${esc(state.query)}”</p>
    <div class="rows">${res.map(p => row(p)).join('')}</div>
  </div>`;
}

function viewSources(){
  return `<div class="pad">
    <h1 class="sec-title">Sources</h1>
    <p class="sec-sub">A source is an HTTP index of packages. Add one with the + button below.</p>
    ${SOURCES.filter(s=>s.status==='err').length ? `<div class="notice err"><svg viewBox="0 0 24 24" width="15" height="15"><circle cx="12" cy="12" r="9.3" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M12 7v6.4M12 16.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
      <div class="grow"><b>A source could not be reached.</b> ${SOURCES.filter(s=>s.status==='err').map(s=>s.name).join(', ')} failed on the last refresh. Packages already downloaded are unaffected.</div>
      <button class="pill" data-act="retry-src">Retry</button></div>` : ''}
    <div class="rows">${SOURCES.map(function(s){
      const n = PKGS.filter(p => p.source === s.id).length;
      const st = { ok:['<span class="status-dot ok"></span>','ok'], warn:['<span class="status-dot warn"></span>','degraded'], err:['<span class="status-dot err"></span>','unreachable'] }[s.status];
      return `<div class="row" data-nav="source" data-sec="${s.id}">
        <div class="aicon sz-28" style="background:linear-gradient(160deg,#9aa3b2,#5c6675);color:#fff"><svg viewBox="0 0 24 24" width="16" height="16"><path d="M4 6.5h16M4 12h16M4 17.5h16" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><circle cx="8" cy="6.5" r="1.7" fill="currentColor"/><circle cx="14" cy="12" r="1.7" fill="currentColor"/><circle cx="10" cy="17.5" r="1.7" fill="currentColor"/></svg></div>
        <div class="row-main"><div class="row-name">${esc(s.name)} ${s.kind==='official'?'<span class="tag tag-inst">Official</span>':''}</div>
        <div class="row-sub">${esc(s.url)}</div></div>
        <div class="row-right">${st[0]} <span style="font-size:12px;color:${s.status==='ok'?'var(--ink-3)':s.status==='err'?'var(--danger)':'var(--warn)'}">${st[1]}</span> <span style="font-size:12px;color:var(--ink-3)">· ${n} pkg</span>
        <button class="pill${s.status==='err' ? ' danger' : ''}" data-act="remove-source" data-src="${s.id}">${s.status==='ok'?'Remove':'Edit'}</button></div></div>`;
    }).join('')}</div>
    <div style="margin-top:18px"><button class="btn" data-act="add-source">+ Add Source</button></div>
  </div>`;
}

function viewSource(){
  const s = SOURCES.filter(x => x.id === state.section)[0] || SOURCES[0];
  const list = PKGS.filter(p => p.source === s.id);
  return `<div class="pad">
    <h1 class="sec-title">${esc(s.name)}</h1>
    <p class="sec-sub">${esc(s.url)}</p>
    ${s.status !== 'ok' ? `<div class="notice err"><svg viewBox="0 0 24 24" width="15" height="15"><circle cx="12" cy="12" r="9.3" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M12 7v6.4M12 16.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
      <div class="grow"><b>Last refresh failed.</b> Showing the index cached from the previous successful sync.</div></div>` : ''}
    ${list.length ? `<div class="rows">${list.map(p => row(p)).join('')}</div>`
                 : `<div class="pad">${emptyState('No packages from this source','The index is empty, or none of its packages target 10.7–10.10.')}</div>`}
  </div>`;
}

function viewSettings(){
  const p = SIGN_POLICIES[policy];
  return `<div class="pad" style="max-width:720px">
    <h1 class="sec-title">Settings</h1>
    <p class="sec-sub">Everything here maps to a key in the Objective-C TCDDefaults class.</p>

    <div class="group-title">Code signing &amp; Gatekeeper</div>
    <div class="notice info"><svg viewBox="0 0 24 24" width="15" height="15"><circle cx="12" cy="12" r="9.3" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M12 11v6M12 7.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
      <div class="grow"><b>Why this matters.</b> Gatekeeper arrived in 10.7 Lion and blocks anything that is not signed by a developer Apple trusts. A store for these systems has to answer: when it installs something, does the result run without a prompt, and what did it do to make that happen? There is no way to be a recognised third party here — Apple retired third-party Mac App Store distribution — so both options below are compromises.</div></div>
    <div class="plist" style="margin-bottom:14px">
      ${Object.keys(SIGN_POLICIES).map(function(k){
        const o = SIGN_POLICIES[k];
        return `<div class="pitem" style="align-items:flex-start" data-policy="${k}">
          <span class="radio ${policy===k?'on':''}" style="margin-top:3px"></span>
          <div style="flex:1">
            <div class="opt-title">${o.title}</div>
            <div class="opt-desc">${o.desc}</div>
            <div class="opt-desc" style="margin-top:6px;color:#1d7a35">✓ ${o.pro}</div>
            <div class="opt-desc" style="color:#9a3a32">✗ ${o.con}</div>
          </div>
          ${o.key==='optin'?'<span class="tag tag-new">Recommended</span>':''}</div>`;
      }).join('')}
    </div>
    <div class="prose" style="font-size:12.5px;color:var(--ink-2)">
      <p>With <b>${esc(p.title)}</b> the install pipeline runs ${policy==='optin' ? '<b>5</b> steps: download → verify → authorise → install → enable.' : '<b>7</b> steps: download → verify → authorise → install → <b>re-sign</b> → enable → commit.'}
      The step list in the install window changes accordingly — try installing a package after switching.</p>
    </div>

    <div class="group-title">Installation</div>
    <div class="spec" style="margin-bottom:18px">
      <dt>Install location</dt><dd>/Applications for apps, receipt payload for packages</dd>
      <dt>Privileged helper</dt><dd>${policy==='adhoc' ? 'Required — SMJobBless, LaunchDaemon':'Not required — per-action authorisation'}</dd>
      <dt>Restart behaviour</dt><dd>Ask before rebooting for kext installs</dd>
      <dt>Network</dt><dd>HTTP and HTTPS, no source pinning</dd>
    </div>

    <div class="group-title">Compatibility floor</div>
    <div class="spec">
      <dt>Minimum system</dt><dd>10.7 Lion (build 11A494a)</dd>
      <dt>Highest tested</dt><dd>10.10 Yosemite, build 14A389</dd>
      <dt>Architectures</dt><dd>i386, x86_64</dd>
    </div>
  </div>`;
}


function viewDownloads(){
  const active = TRANSFERS.slice();
  const head = [];
  head.push(`<div class="dl-head">
    <h2>Active</h2>
    <span class="count">${active.length}</span>
    <span class="spacer"></span>
  </div>`);
  head.push(active.length
    ? active.map(t => `<div class="transfer" data-transfer="${esc(t.key)}">
        <span class="spinner"></span>
        ${icon(byId(t.pkg), 44)}
        <div class="t-main">
          <div class="t-name"><span class="t-verb">${esc(t.verb)}</span> ${esc(t.name)}${t.version ? ' <span class="t-ver">v' + esc(t.version) + '</span>' : ''}</div>
          <div class="t-step">${esc(t.step)}</div>
          <div class="bar t-bar"><i style="width:${Math.round(t.fraction * 100)}%"></i></div>
          ${t.logs.length ? `<div class="t-log">${t.logs.map(l => `<div>${l}</div>`).join('')}</div>` : ''}
        </div>
        <div class="t-right">
          <div class="t-pct">${Math.round(t.fraction * 100)}%</div>
          <div class="t-meta">${t.size ? bytes(t.size) + ' · ' : ''}${t.pkgs} pkg</div>
          <button class="btn t-cancel" data-act="cancel-transfer" data-key="${esc(t.key)}">Cancel</button>
        </div>
      </div>`).join('')
    : `<div class="dl-empty">
        <div class="glyph">${navGlyph('download')}</div>
        <h3 style="margin:0 0 4px;color:var(--ink-2);font-size:14px">Nothing in flight</h3>
        <div>Install something from the Store and it will show up here while it runs.</div>
      </div>`);

  const hist = HISTORY.slice().reverse();
  head.push(`<div class="group-title" style="display:flex;align-items:center;gap:10px">
      History
      <span style="flex:1"></span>
    </div>`);
  head.push(`<div class="dl-head" style="margin-bottom:8px">
      <span class="count" style="background:var(--ink-3)">${hist.length}</span>
      <span class="spacer"></span>
      ${hist.length ? `<button class="btn" data-act="clear-history">Clear History</button>` : ''}
    </div>`);
  head.push(hist.length
    ? `<div>${hist.map(h => `<div class="hist-row">
        <span class="hist-verb ${h.verb.toLowerCase()}">${esc(h.verb)}</span>
        <span class="hist-name">${esc(h.name)}</span>
        <span class="hist-ver">v${esc(h.version)}</span>
        <span class="hist-when">${esc(relTime(h.when))}</span>
      </div>`).join('')}</div>`
    : `<div class="dl-empty" style="padding:34px 20px">
        <div>Nothing installed or removed yet.</div></div>`);

  return `<div class="pad">${head.join('')}</div>`;
}

/* ---------------- package detail ---------------- */
function viewPackage(){
  const p = byId(state.pkgId);
  if (!p) return `<div class="pad">${emptyState('Package not found','It may have been removed from its source.')}</div>`;
  const tab = state.tab;
  const plan = resolvePlan(p);
  const extra = plan.length - 1;
  const conflicts = planConflicts(plan);

  let actionBtn;
  if (p.hasUpdate)      actionBtn = `<button class="btn primary" data-act="install" data-pkg="${p.id}">Update</button>`;
  else if (p.installed) actionBtn = `<button class="btn destructive" data-act="remove" data-pkg="${p.id}">Remove</button>`;
  else                  actionBtn = `<button class="btn primary" data-act="install" data-pkg="${p.id}">${p.cPrice ? '$'+p.cPrice : 'Install'}</button>`;

  let body;
  if (tab === 'description'){
    body = `<div class="prose">
        <p>${esc(p.description)}</p>
        ${p.notes.length ? `<ul style="margin:0 0 12px;padding-left:20px">${p.notes.map(n=>`<li>${esc(n)}</li>`).join('')}</ul>` : ''}
      </div>
      <div class="group-title">Details</div>
      <dl class="spec">
        <dt>Version</dt><dd>${esc(p.version)}${p.pkgVersion ? ` <span style="color:var(--ink-3)">(installed: ${esc(p.pkgVersion)})</span>` : ''}</dd>
        <dt>Size</dt><dd>${bytes(p.size)}</dd>
        <dt>Kind</dt><dd>${typeLabel(p.type)}</dd>
        <dt>Developer</dt><dd>${esc(p.developer)}</dd>
        <dt>Source</dt><dd>${esc(srcName(p.source))}</dd>
        <dt>Requires</dt><dd>Mac OS X ${esc(p.minOs)} or later</dd>
        <dt>Licence</dt><dd>Freeware</dd>
      </dl>`;
  } else if (tab === 'shots'){
    body = `<div class="shots">${Array.from({length:p.shots}).map((_,i)=>shotMock(i, p)).join('')}</div>`;
  } else if (tab === 'changelog'){
    body = p.changelog.length ? p.changelog.map(function(c){
      return `<div class="cl-item"><div class="cl-ver">${esc(c[0])}</div><div class="cl-date">${esc(c[1])}</div><div class="cl-txt">${esc(c[2])}</div></div>`;
    }).join('') : `<div class="prose" style="color:var(--ink-3)">The developer has not published a changelog for this package.</div>`;
  } else if (tab === 'versions'){
    body = `<div class="prose" style="margin-bottom:14px">This source carries ${p.versions.length} version${p.versions.length===1?'':'s'}. Installing an older one rolls the package back; your own files are not touched.</div>
      <div class="plist">${newestFirst(p.versions).map(function(v){
        const k = relationToInstalled(p, v);
        const isCurrent = p.installed && v === p.pkgVersion;
        const label = { new:'Install', update:'Update', downgrade:'Downgrade', reinstall:'Reinstall' }[k];
        const cls = { new:'rel-new', update:'rel-update', downgrade:'rel-downgrade', reinstall:'rel-reinstall' }[k];
        return `<div class="pitem">${icon(p,28)}
          <div><div class="nm">v${esc(v)}</div><div class="vr">${isCurrent ? 'Currently installed' : esc(typeLabel(p.type)) + ' · ' + esc(p.developer)}</div></div>
          ${isCurrent ? '<span class="tag tag-inst">Current</span>'
            : `<button class="pill" data-act="pick-version" data-pkg="${p.id}" data-version="${esc(v)}">${label}</button>`}</div>`;
      }).join('')}</div>`;
  } else {
    const deps = p.depends.map(byId).filter(Boolean);
    const conf = p.conflicts.map(byId).filter(Boolean);
    const dep  = dependentsOf(p);
    body = `
      <div class="group-title">Depends on</div>
      ${deps.length ? `<div class="plist">${deps.map(d=>`<div class="pitem">${icon(d,28)}<div><div class="nm">${esc(d.name)}</div><div class="vr">${esc(d.version)} · required</div></div></div>`).join('')}</div>`
                    : `<div class="prose" style="color:var(--ink-3)">Nothing. This package is self-contained.</div>`}
      <div class="group-title">Conflicts with</div>
      ${conf.length ? `<div class="plist">${conf.map(d=>`<div class="pitem">${icon(d,28)}<div><div class="nm">${esc(d.name)}</div><div class="vr">${esc(d.summary)}</div></div><span class="tag tag-conf">Conflict</span></div>`).join('')}</div>`
                    : `<div class="prose" style="color:var(--ink-3)">Nothing.</div>`}
      ${dep.length ? `<div class="group-title">Required by</div><div class="plist">${dep.map(d=>`<div class="pitem">${icon(d,28)}<div class="nm">${esc(d.name)}</div><span class="tag tag-dep">Installed</span></div>`).join('')}</div>` : ''}`;
  }

  return `<div class="pad">
    <div class="detail-hero">
      ${icon(p,128)}
      <div class="detail-meta">
        <div class="detail-name">${esc(p.name)}</div>
        <div class="detail-dev">${esc(p.developer)}</div>
        <div class="stars">${stars(p.stars)}<span class="rating-n">${p.rating ? p.rating.toLocaleString()+' ratings' : 'No ratings yet'}</span></div>
        <div class="btn-row">${actionBtn}
          <span style="font-size:12px;color:var(--ink-3)">${bytes(p.size)} · ${typeLabel(p.type)}</span></div>
        ${p.installed ? `<div style="font-size:12px;color:var(--ink-2);margin-top:8px">Installed — version <b>${esc(p.pkgVersion)}</b> from ${esc(srcName(p.source))}</div>` : ''}
      </div>
    </div>
    <div class="tabs">
      <div class="tab ${tab==='description'?'active':''}" data-tab="description">Description</div>
      ${p.shots ? `<div class="tab ${tab==='shots'?'active':''}" data-tab="shots">Screenshots</div>` : ''}
      <div class="tab ${tab==='changelog'?'active':''}" data-tab="changelog">Changelog</div>
      <div class="tab ${tab==='versions'?'active':''}" data-tab="versions">Versions (${p.versions.length})</div>
      <div class="tab ${tab==='deps'?'active':''}" data-tab="deps">Dependencies${p.depends.length?` (${p.depends.length})`:''}</div>
    </div>
    ${body}
  </div>`;
}
function shotMock(i, p){
  const tints = ['#eef2f7,#dbe3ec','#f3eef7,#e3d9ec','#eef7f2,#d8ebe1'];
  return `<div class="shot" style="background:linear-gradient(160deg,${tints[i%3]})">
    <div style="width:78%;background:#fff;border-radius:4px;box-shadow:0 3px 12px rgba(0,0,0,.14);overflow:hidden">
      <div style="height:16px;background:linear-gradient(#fbfbfc,#eceef0);border-bottom:1px solid rgba(0,0,0,.1);display:flex;align-items:center;gap:4px;padding:0 6px">
        <i style="width:6px;height:6px;border-radius:50%;background:#ff5f57;display:block"></i>
        <i style="width:6px;height:6px;border-radius:50%;background:#febc2e;display:block"></i>
        <i style="width:6px;height:6px;border-radius:50%;background:#28c840;display:block"></i>
        <span style="font-size:8px;color:#8a8a8e;margin-left:5px">${esc(p.name)}</span></div>
      <div style="height:82px;display:flex">
        <div style="flex:0 0 30%;background:#f6f6f8;border-right:1px solid rgba(0,0,0,.07)"></div>
        <div style="flex:1;padding:8px 9px">
          <div style="height:7px;width:56%;background:#dcdfe4;border-radius:2px;margin-bottom:6px"></div>
          <div style="height:5px;width:88%;background:#e8eaee;border-radius:2px;margin-bottom:4px"></div>
          <div style="height:5px;width:72%;background:#e8eaee;border-radius:2px"></div>
        </div></div>
    </div></div>`;
}

function emptyState(title, sub){
  return `<div class="empty"><h3>${title}</h3><div>${sub}</div></div>`;
}

/* ============================================================
   OVERLAYS: sheets, dialogs, progress, toasts
   ============================================================ */
/* There is exactly one overlay slot, but several flows can be in flight at
   once (a source refresh outlives a sheet; a remove can still be settling when
   an install starts). Whoever owns the slot is responsible for taking it down:
   a finishing flow passes its token and is ignored if it has since been
   replaced. Without this, a late timer from an old flow tears down the UI of
   whatever the user is looking at now. */
let overlayOwner = null;
let ownerSeq = 0;
function newOwner(tag){ return (ownerSeq++) + ':' + tag; }
function ownsOverlay(owner){ return owner === undefined || owner === overlayOwner; }
function ownerOf(el){
  const host = el && el.closest && el.closest('[data-owner]');
  return host ? host.dataset.owner : undefined;
}
function overlay(html, owner){
  overlayOwner = owner === undefined ? null : owner;
  $('#overlays').innerHTML = html;
  $('#overlays').style.pointerEvents = 'auto';
}
function closeOverlay(owner){
  if (!ownsOverlay(owner)) return;
  overlayOwner = null;
  $('#overlays').innerHTML = '';
  $('#overlays').style.pointerEvents = 'none';
}
let toastTimer = null;
function toast(msg, kind){
  const box = $('#overlays');
  let t = box.querySelector('.toasts');
  if (!t){ t = document.createElement('div'); t.className = 'toasts'; box.appendChild(t); }
  const el = document.createElement('div');
  el.className = 'toast' + (kind ? ' '+kind : '');
  el.textContent = msg;
  t.appendChild(el);
  setTimeout(() => { el.style.transition = 'opacity .3s, transform .3s'; el.style.opacity = 0; el.style.transform = 'translateY(6px)'; setTimeout(() => el.remove(), 320); }, 3200);
}

/* ---------- remove source sheet ---------- */
function openRemoveSource(id){
  const src = SOURCES.filter(x => x.id === id)[0];
  if (!src) return;
  const n = PKGS.filter(p => p.source === id).length;
  const owned = PKGS.filter(p => p.source === id && p.installed).length;
  overlay(`
    <div class="scrim" data-close></div>
    <div class="sheet" style="top:24%">
      <div class="sheet-head"><div class="sheet-title">Remove ${esc(src.name)}?</div>
        <div class="sheet-sub">${esc(src.url)}</div></div>
      <div class="sheet-body">
        <div class="prose" style="font-size:12.5px">${n} package${n===1?'':'s'} will disappear from the store. Nothing already downloaded or installed is touched.</div>
        ${owned ? `<div class="notice" style="margin-top:12px"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3.2l9.2 16H2.8z" fill="currentColor" opacity=".3"/><path d="M12 3.2l9.2 16H2.8z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 9.5v5M12 17.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
          <div class="grow"><b>${owned} of them ${owned===1?'is':'are'} installed.</b> You can still remove the source — the installed copies stay, but the store will no longer know where updates come from.</div></div>` : ''}
      </div>
      <div class="sheet-foot">
        <button class="btn" data-close>Cancel</button>
        <button class="btn destructive" data-act="do-remove-source" data-src="${id}">Remove Source</button>
      </div>
    </div>`);
}
function removeSource(id){
  const i = SOURCES.findIndex(x => x.id === id);
  if (i === -1) return;
  const name = SOURCES[i].name;
  SOURCES.splice(i, 1);
  closeOverlay();
  go('sources', { replace:true });
  toast(`Removed ${name}`, 'ok');
}

/* ---------- add source sheet ---------- */
function openAddSource(){
  const owner = newOwner('add-source');
  overlay(`
    <div class="scrim" data-close data-owner="${owner}"></div>
    <div class="sheet" style="top:12%" data-owner="${owner}">
      <div class="sheet-head"><div class="sheet-title">Add Source</div>
        <div class="sheet-sub">A source is an HTTP index that lists packages.</div></div>
      <div class="sheet-body">
        <div class="field" id="urlField">
          <label for="srcUrl">URL</label>
          <input type="text" id="srcUrl" placeholder="https://example.com/legacy/" spellcheck="false">
          <div class="hint">The URL must end in a slash and point at a directory containing a <code>Packages</code> index.</div>
        </div>
      </div>
      <div class="sheet-foot">
        <button class="btn" data-close>Cancel</button>
        <button class="btn primary" data-act="save-source">Add</button>
      </div>
    </div>`, owner);
  const inp = $('#srcUrl');
  inp.focus();
  inp.addEventListener('input', () => $('#urlField').classList.remove('err'));
  inp.addEventListener('keydown', e => { if (e.key === 'Enter') saveSource(); });
}
function saveSource(owner){
  const field = $('#urlField');
  if (!field || !ownsOverlay(owner)) return;   // a later sheet replaced this one
  const v = $('#srcUrl').value.trim();
  const bad = !/^https?:\/\/.+\/$/.test(v);
  if (bad){
    const f = $('#urlField');
    f.classList.add('err');
    f.querySelector('.hint').outerHTML = '<div class="err-msg">Enter a full http:// or https:// URL ending in a slash.</div>';
    return;
  }
  const name = v.replace(/^https?:\/\//,'').replace(/\/$/,'') || 'Untitled Source';
  SOURCES.push({ id:'src'+SOURCES.length, name:name, url:v, status:'ok', kind:'third-party' });
  closeOverlay(owner);
  toast('Source added — refreshing index', 'ok');
  runRefresh(() => { go('sources', { replace:true }); });
}

/* ---------- confirm install ---------- */
function openInstall(pkgId, targetVersion){
  const p = byId(pkgId);
  const plan = resolvePlan(p);
  const conflicts = planConflicts(plan);
  const needsPriv = plan.some(x => x.type === 'pkg' || x.type === 'kext');
  const version = targetVersion || p.version;
  const action = relationToInstalled(p, version);
  const isDowngrade = action === 'downgrade';
  const verb = { new:'Install', update:'Update', downgrade:'Downgrade', reinstall:'Reinstall' }[action];

  const owner = newOwner('install-confirm:' + p.id);
  overlay(`
    <div class="scrim" data-close data-owner="${owner}"></div>
    <div class="sheet" style="top:11%" data-owner="${owner}">
      <div class="sheet-head">
        <div class="sheet-title">${verb} ${esc(plan.length > 1 ? plan.length + ' Packages' : p.name)}</div>
        <div class="sheet-sub">${esc(p.name)} v${esc(version)}${p.installed && action !== 'reinstall' ? ' · currently v' + esc(p.pkgVersion) : ''} · ${bytes(p.size)}</div>
      </div>
      <div class="sheet-body">
        ${conflicts.length ? `<div class="notice err"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3.2l9.2 16H2.8z" fill="currentColor" opacity=".3"/><path d="M12 3.2l9.2 16H2.8z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 9.5v5M12 17.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
          <div class="grow"><b>Conflict.</b> ${esc(p.name)} conflicts with ${conflicts.map(c=>c.other.name).join(', ')}, which ${conflicts.length>1?'are':'is'} installed. It must be removed first.</div></div>` : ''}
        ${isDowngrade ? `<div class="notice"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3.2l9.2 16H2.8z" fill="currentColor" opacity=".3"/><path d="M12 3.2l9.2 16H2.8z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 9.5v5M12 17.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
          <div class="grow"><b>This is a downgrade.</b> You are on v${esc(p.pkgVersion)} and v${esc(version)} is older. Files added by the newer version may be left behind, and the package may not work.</div></div>` : ''}
        <div class="plist">${plan.map(function(x){
          const isTarget = x.id === p.id;
          const tag = !isTarget ? '<span class="tag tag-dep">Dependency</span>'
            : action === 'update' ? '<span class="tag tag-upd">Update</span>'
            : action === 'downgrade' ? '<span class="tag tag-dep">Downgrade</span>'
            : action === 'reinstall' ? '<span class="tag tag-inst">Reinstall</span>'
            : '<span class="tag tag-new">Install</span>';
          return `<div class="pitem">${icon(x,28)}
            <div><div class="nm">${esc(x.name)}</div><div class="vr">v${esc(isTarget ? version : x.version)} · ${esc(typeLabel(x.type))} · ${bytes(x.size)}</div></div>
            ${tag}</div>`;
        }).join('')}</div>
        ${needsPriv ? `<div class="notice" style="margin:14px 0 0"><svg viewBox="0 0 24 24" width="15" height="15"><rect x="4.4" y="10.2" width="15.2" height="11.4" rx="2.4" fill="currentColor" opacity=".3"/><rect x="4.4" y="10.2" width="15.2" height="11.4" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M8 10.2V7.6a4 4 0 0 1 8 0v2.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
          <div class="grow"><b>Your password will be requested.</b> This plan includes a ${plan.filter(x=>x.type!=='app').map(x=>esc(x.name)).join(', ')}, which installs outside /Applications.</div></div>` : ''}
      </div>
      <div class="sheet-foot">
        <button class="btn" data-close>Cancel</button>
        <button class="btn primary" data-act="do-install" data-plan="${plan.map(x=>x.id).join(',')}" data-primary="${p.id}" data-version="${esc(version)}" ${conflicts.length?'disabled':''}>
          ${verb}</button>
      </div>
    </div>`, owner);
}

function openRemove(pkgId){
  const p = byId(pkgId);
  const deps = dependentsOf(p);
  const orphans = deps.length ? [] : orphansAfterRemoving(p);
  const owner = newOwner('remove-confirm:' + p.id);
  overlay(`
    <div class="scrim" data-close data-owner="${owner}"></div>
    <div class="sheet" style="top:20%" data-owner="${owner}">
      <div class="sheet-head"><div class="sheet-title">Remove ${esc(p.name)}?</div>
        <div class="sheet-sub">Version ${esc(p.pkgVersion)} from ${esc(srcName(p.source))}</div></div>
      <div class="sheet-body">
        ${deps.length ? `<div class="notice err"><svg viewBox="0 0 24 24" width="15" height="15"><circle cx="12" cy="12" r="9.3" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M12 7v6.4M12 16.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
          <div class="grow"><b>Still required.</b> ${deps.map(d=>esc(d.name)).join(', ')} ${deps.length>1?'depend':'depends'} on this package.</div></div>`
        : `<div class="prose" style="font-size:12.5px">${p.type==='app' ? 'The application is moved to the Trash.' : 'The receipt payload is removed using its own uninstall script, and the package is dropped from the database.'} Any files you created yourself are left alone.</div>`}
        ${orphans.length ? `<div class="notice info" style="margin-top:12px"><svg viewBox="0 0 24 24" width="15" height="15"><circle cx="12" cy="12" r="9.3" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M12 11v6M12 7.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
          <div class="grow"><b>${orphans.length} package${orphans.length>1?'s':''} will go too.</b> ${orphans.map(d=>esc(d.name)).join(', ')} ${orphans.length>1?'were':'was'} installed automatically as a dependency, and nothing else needs ${orphans.length>1?'them':'it'}.</div></div>` : ''}
        ${p.type !== 'app' ? `<div class="notice" style="margin-top:12px"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3.2l9.2 16H2.8z" fill="currentColor" opacity=".3"/><path d="M12 3.2l9.2 16H2.8z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 9.5v5M12 17.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
          <div class="grow">A ${esc(typeLabel(p.type).toLowerCase())} may need a restart to finish unloading.</div></div>` : ''}
      </div>
      <div class="sheet-foot">
        <button class="btn" data-close>Cancel</button>
        <button class="btn destructive" data-act="do-remove" data-pkg="${p.id}" ${deps.length?'disabled':''}>
          Remove${orphans.length ? ` ${orphans.length + 1} Packages` : ''}</button>
      </div>
    </div>`, owner);
}


/* ============================================================
   version disclosure
   The blue triangle on each tile unfolds a menu of every version the
   source carries, Cydia-style. Pick one and the install sheet opens
   for that exact version — which may be an update, a fresh install,
   a reinstall, or a downgrade.
   ============================================================ */
function openVersionMenu(pkgId, caret){
  const p = byId(pkgId);
  if (!p) return;
  const owner = newOwner('versions:' + p.id);
  const versions = newestFirst(p.versions);
  const rel = { new:'New', update:'Update', downgrade:'Downgrade', reinstall:'Reinstall' };
  const relCls = { new:'rel-new', update:'rel-update', downgrade:'rel-downgrade', reinstall:'rel-reinstall' };

  // Anchor to the tile, flipping to the other side if it would overflow.
  const win = $('#window').getBoundingClientRect();
  const r = caret.getBoundingClientRect();
  const W = 238, PAD = 10;
  let left = (r.right - win.left) - W + 8;
  if (left < PAD) left = r.left - win.left + 8;
  let top = (r.bottom - win.top) + 6;
  const estimated = 64 + versions.length * 30 + 54;
  if (top + estimated > win.height - PAD) top = Math.max(PAD, (r.top - win.top) - estimated - 6);

  overlay(`
    <div class="scrim" data-close data-owner="${owner}"></div>
    <div class="popover" data-owner="${owner}" style="left:${Math.round(left)}px; top:${Math.round(top)}px">
      <div class="popover-head">
        <div style="width:22px;height:22px;flex:0 0 22px">${icon(p, 28).replace('class="aicon sz-28"', 'class="aicon sz-28" style="width:22px;height:22px;border-radius:5px"')}</div>
        <div class="nm">${esc(p.name)}</div>
        <div class="st">${p.installed ? 'v' + esc(p.pkgVersion) : 'not installed'}</div>
      </div>
      <div class="popover-sec">In ${esc(srcName(p.source))}</div>
      ${versions.map(function(v){
        const k = relationToInstalled(p, v);
        const isCurrent = p.installed && v === p.pkgVersion;
        return `<button class="ver-row${isCurrent ? ' current' : ''}"
                  data-act="pick-version" data-pkg="${p.id}" data-version="${esc(v)}">
          <span class="vr">v${esc(v)}</span>
          <span class="rel ${isCurrent ? 'rel-current' : relCls[k]}">${isCurrent ? 'Current' : rel[k]}</span>
        </button>`;
      }).join('')}
      <div class="popover-foot">
        <button class="btn" data-close>Cancel</button>
        <button class="btn" data-act="pkg-detail" data-pkg="${p.id}">Details</button>
      </div>
    </div>`, owner);

  const btn = document.querySelector('.ver-caret[data-pkg="' + p.id + '"]');
  if (btn) btn.classList.add('open');
}

/* ---------- install progress ---------- */
let installRun = null;   // { cancelled:bool } — one per in-flight run

function runInstall(ids, primaryIds, versionOverrides){
  const plan = ids.map(byId).filter(Boolean);
  const primary = (primaryIds || ids);
  const overrides = versionOverrides || {};
  const target = overrides[plan[0].id];
  const isUpdate = plan[0].hasUpdate;
  const action = target ? relationToInstalled(plan[0], target) : (isUpdate ? 'update' : 'new');
  const verb = { new:'Install', update:'Update', downgrade:'Downgrade', reinstall:'Reinstall' }[action];
  const steps = [
    { label:'Downloading…', w:[18,46,78,100], logs:[
      'GET /pool/'+plan[0].id.toLowerCase()+'/'+(target || plan[0].version)+'.pkg',
      'HTTP/1.1 200 OK · ' + bytes(plan[0].size) + ' of ' + bytes(plan[0].size)] },
    { label:'Verifying checksum…', w:[0,34,100], logs:['sha256 ' + fakeHash(plan[0]), '<b>Checksum matches Packages index</b>'] },
    { label:'Requesting authorisation…', w:[0,60,100], logs:['SMJobBless — TCD Store Helper', 'AuthorizationCreate … user granted'] },
    { label:'Installing…', w:[8,45,80,100], logs: plan.map(x => '/usr/sbin/installer -pkg '+x.id.toLowerCase()+'.pkg -target /') }
  ];
  if (policy === 'adhoc'){
    steps.push({ label:'Re-signing payload…', w:[0,35,70,100], logs:[
      'codesign -f -s "TCD Store" ' + plan[0].id + '.app',
      '<b>Signed ' + bytes(plan[0].size) + ' · payload trusted</b>'] });
  }
  steps.push({ label: isUpdate ? 'Finalising update…' : 'Finishing…', w:[0,50,100], logs:['Writing package records…', '<b>Done</b>'] });

  /* Every run gets its own token. The callbacks must close over THIS object,
     not the module-level `installRun`: a later run replaces that variable, and
     a zombie run that keeps reading it would never see its own cancellation. */
  // A plan that is not installable must never appear in the queue at all.
  if (planConflicts(plan).length || missingDeps(plan).length){
    toast('That plan cannot be installed', 'err');
    return;
  }

  const run = { cancelled:false, owner:newOwner('install') };
  installRun = run;

  /* The install is watched in the Downloads queue, not behind a modal, so the
     user is taken there and the run drives the row directly. */
  const transfer = {
    key: 't' + (transferSeq++),
    pkg: plan[0].id,
    name: plan[0].name,
    version: target || null,
    verb: verb,
    step: 'Starting…',
    fraction: 0,
    pkgs: plan.length,
    size: plan.reduce((a,b) => a + b.size, 0),
    logs: [],
    run: run
  };
  TRANSFERS.push(transfer);
  setView('downloads', true);

  let si = 0, logQueue = [];

  function pumpLog(){
    if (!logQueue.length) return;
    transfer.logs.push(logQueue.shift());
    if (transfer.logs.length > 4) transfer.logs.shift();
    render();
  }

  function dropTransfer(){
    const ti = TRANSFERS.indexOf(transfer);
    if (ti !== -1) TRANSFERS.splice(ti, 1);
    updateDownloadBadge();
    render();
  }

  function nextStep(){
    if (run.cancelled){ dropTransfer(); return; }
    if (si >= steps.length){
      setTimeout(() => {
        if (run.cancelled){ dropTransfer(); return; }
        plan.forEach(function(x){
          const landed = overrides[x.id] || x.version;
          x.installed = true;
          x.pkgVersion = landed;
          // a package sitting on something other than the newest version in
          // its source is still "updatable" — that is the whole point of the
          // version menu
          x.hasUpdate = (landed !== x.version);
          // anything pulled in only to satisfy a dependency is removable later
          x.autoInstalled = primary.indexOf(x.id) === -1;
        });
        if (installRun === run) installRun = null;
        dropTransfer();
        HISTORY.push({ name: plan[0].name,
                       version: overrides[plan[0].id] || plan[0].version,
                       verb: verb, when: new Date() });
        render();
        toast(`${verb} ${plan[0].name}` + (target ? ` to v${target}` : ''), 'ok');
        if (plan[0].type === 'kext') toast('Restart required to load the kernel extension');
      }, 320);
      return;
    }
    const st = steps[si];
    transfer.step = st.label;
    transfer.fraction = si / steps.length;
    STEP_LOG.push(st.label);
    render();
    logQueue = st.logs.slice();
    pumpLog();
    let i = 0;
    const iv = setInterval(() => {
      if (run.cancelled){ clearInterval(iv); return; }
      if (i >= st.w.length){
        clearInterval(iv);
        setTimeout(function(){ si++; nextStep(); }, 150);
        return;
      }
      transfer.fraction = (si + st.w[i] / 100) / steps.length;
      render();
      if (i > 0) pumpLog();
      i++;
    }, 210 + Math.random() * 110);
  }
  setTimeout(nextStep, 300);
}
/* Names in the plan that no source carries. */
function missingDeps(plan){
  const known = {};
  PKGS.forEach(p => { known[p.id] = true; });
  const out = [];
  plan.forEach(function(p){
    p.depends.forEach(function(d){ if (!known[d] && out.indexOf(d) === -1) out.push(d); });
  });
  return out;
}

function landedVersion(pkg, overrides){
  return (overrides && overrides[pkg.id]) || pkg.version;
}
function updateDownloadBadge(){
  const dl = $('.aero-pill[data-view="downloads"]');
  if (!dl) return;
  const n = TRANSFERS.length;
  const b = dl.querySelector('.pill-badge');
  if (n && b) b.textContent = String(n);
  else if (!n && b) b.remove();
}

function fakeHash(p){
  let s = '';
  for (let i = 0; i < 64; i++) s += '0123456789abcdef'[(p.version.charCodeAt(i % p.version.length) + i * 7) % 16];
  return s;
}

/* ---------- refresh all sources ---------- */
function runRefresh(done){
  const owner = newOwner('refresh');
  overlay(`
    <div class="scrim"></div>
    <div class="sheet prog-card" style="top:28%">
      <div class="sheet-head" style="padding-bottom:12px"><div class="sheet-title">Refreshing Sources</div></div>
      <div class="sheet-body">
        <div class="prog-step" id="rStep" style="margin-bottom:9px">Contacting ${SOURCES.length} sources…</div>
        <div class="bar"><i id="rBar"></i></div>
        <div class="prog-log" id="rLog"></div>
      </div>
    </div>`, owner);
  const bar = $('#rBar'), log = $('#rLog'), step = $('#rStep');
  let i = 0;
  const iv = setInterval(() => {
    if (i >= SOURCES.length){
      clearInterval(iv);
      bar.style.width = '100%';
      setTimeout(() => {
        if (!ownsOverlay(owner)) return;
        closeOverlay(owner);
        if (done) done(); else { render(); toast('Sources up to date', 'ok'); }
      }, 320);
      return;
    }
    const s = SOURCES[i];
    const d = document.createElement('div');
    const okMark = s.status === 'ok' ? '<b>ok</b>' : s.status === 'warn' ? '<i>degraded</i>' : '<b style="color:#f4796b">failed</b>';
    d.innerHTML = `${esc(s.url)} → ${okMark}`;
    log.appendChild(d); log.scrollTop = log.scrollHeight;
    if (log.children.length > 5) log.removeChild(log.firstChild);
    step.textContent = `Fetching ${s.name}… (${i+1}/${SOURCES.length})`;
    bar.style.width = Math.round((i+1)/SOURCES.length*100) + '%';
    i++;
  }, 460);
}

/* ============================================================
   EVENTS
   ============================================================ */
document.addEventListener('click', function(e){
  const closeEl = e.target.closest('[data-close]');
  if (closeEl){ closeOverlay(ownerOf(closeEl)); return; }

  /* Cancel belongs to the run that owns the row, not to a global — several
     transfers can be in flight at once. */
  const cancelEl = e.target.closest('[data-act="cancel-transfer"]');
  if (cancelEl){
    const key = cancelEl.dataset.key;
    const ti = TRANSFERS.map(t => t.key).indexOf(key);
    if (ti !== -1){
      const t = TRANSFERS[ti];
      t.run.cancelled = true;
      if (installRun === t.run) installRun = null;
      TRANSFERS.splice(ti, 1);
      updateDownloadBadge();
      render();
      toast(`${t.verb} ${t.name} cancelled`);
    }
    return;
  }

  // An explicit control beats the container it sits in. A Remove button
  // inside a navigable source row must remove the source, not navigate to it.
  const act = e.target.closest('[data-act]');
  if (act){
    const a = act.dataset.act;
    if (a === 'versions')        openVersionMenu(act.dataset.pkg, act);
    else if (a === 'pkg-detail'){ closeOverlay(ownerOf(act)); go('pkg', { pkgId:act.dataset.pkg }); }
    else if (a === 'pick-version'){
      const v = act.dataset.version;
      closeOverlay(ownerOf(act));
      openInstall(act.dataset.pkg, v);
    }
    else if (a === 'install')    openInstall(act.dataset.pkg);
    else if (a === 'remove')     openRemove(act.dataset.pkg);
    else if (a === 'do-install'){
      const ids = act.dataset.plan.split(',');
      const overrides = {};
      if (act.dataset.version) overrides[act.dataset.primary] = act.dataset.version;
      closeOverlay(ownerOf(act));
      runInstall(ids, [act.dataset.primary], overrides);
    }
    else if (a === 'do-remove'){ const p = byId(act.dataset.pkg); closeOverlay(ownerOf(act)); runRemove(p); }
    else if (a === 'add-source')openAddSource();
    else if (a === 'remove-source'){ const id = act.dataset.src; closeOverlay(ownerOf(act)); openRemoveSource(id); }
    else if (a === 'do-remove-source'){ removeSource(act.dataset.src); }
    else if (a === 'save-source')saveSource(ownerOf(act));
    else if (a === 'retry-src')  runRefresh();
    else if (a === 'refresh-all')runRefresh();
    else if (a === 'update-all') runUpdateAll();
    else if (a === 'clear-history'){
      HISTORY.length = 0;
      render();
      toast('History cleared');
    }
    return;
  }

  const viewBtn = e.target.closest('[data-view]');
  if (viewBtn){ setView(viewBtn.dataset.view); return; }

  const nav = e.target.closest('[data-nav]');
  if (nav){
    const r = nav.dataset.nav, sec = nav.dataset.sec;
    if (r === 'featured')  go('featured', { replace:true });
    else if (r === 'category') go('category', { replace:true });
    else if (r === 'source' || r === 'categorylist') go(r, { section:sec, replace:true });
    else go(r, { replace:true });
    return;
  }
  const cat = e.target.closest('[data-cat]');
  if (cat){ go('categorylist', { section:cat.dataset.cat, replace:true }); return; }

  const pkgEl = e.target.closest('[data-pkg]');
  if (pkgEl){ go('pkg', { pkgId:pkgEl.dataset.pkg }); return; }

  const tab = e.target.closest('[data-tab]');
  if (tab){ go('pkg', { pkgId:state.pkgId, tab:tab.dataset.tab, keepTab:true }); return; }
});

function runRemove(p){
  const orphans = orphansAfterRemoving(p);
  const total = [p].concat(orphans);
  const run = { cancelled:false, owner:newOwner('remove:' + p.id) };

  const transfer = {
    key: 't' + (transferSeq++),
    pkg: p.id, name: p.name, version: p.pkgVersion || null, verb: 'Remove',
    step: 'Running uninstall script…', fraction: 0,
    pkgs: total.length, size: p.size, logs: [], run: run
  };
  TRANSFERS.push(transfer);
  setView('downloads', true);

  function dropTransfer(){
    const ti = TRANSFERS.indexOf(transfer);
    if (ti !== -1) TRANSFERS.splice(ti, 1);
    updateDownloadBadge();
    render();
  }

  let w = 0;
  const iv = setInterval(() => {
    if (run.cancelled){ clearInterval(iv); dropTransfer(); return; }
    w += 22 + Math.random()*20;
    transfer.fraction = Math.min(1, w / 100);
    render();
    if (w >= 100){
      clearInterval(iv);
      transfer.step = p.type === 'app' ? 'Moved to the Trash' : 'Payload removed · database updated';
      transfer.fraction = 1;
      STEP_LOG.push(transfer.step);
      transfer.logs.push('database updated');
      render();
      setTimeout(() => {
        if (run.cancelled) return;
        total.forEach(function(x){ x.installed = false; x.pkgVersion = null; x.hasUpdate = false; x.autoInstalled = false; });
        dropTransfer();
        HISTORY.push({ name: p.name, version: p.pkgVersion || p.version, verb: 'Remove', when: new Date() });
        render();
        toast(total.length > 1
          ? `Removed ${p.name} and ${orphans.length} orphaned dependenc${orphans.length>1?'ies':'y'}`
          : `Removed ${p.name}`, 'ok');
      }, 420);
    }
  }, 380);
}

function runUpdateAll(){
  const list = PKGS.filter(p => p.hasUpdate);
  if (!list.length) return;
  runInstall(list.map(p => p.id), list.map(p => p.id));
}

/* policy radio */
document.addEventListener('click', function(e){
  const pr = e.target.closest('[data-policy]');
  if (!pr) return;
  policy = pr.dataset.policy;
  render();
  toast(policy === 'adhoc'
    ? 'Re-signing enabled — installs now run the privileged helper'
    : 'User opt-in enabled — no privileged helper required');
});

/* search */
$('#searchInput').addEventListener('input', function(){
  const v = this.value;
  $('#searchClear').hidden = !v;
  if (v.trim()){ go('search', { query:v, replace:true }); }
  else if (state.route === 'search'){ go('featured', { replace:true }); }
});
$('#searchClear').addEventListener('click', function(){
  $('#searchInput').value = ''; this.hidden = true;
  go('featured', { replace:true });
});
$('#searchInput').addEventListener('keydown', function(e){
  if (e.key === 'Escape'){ $('#searchInput').value=''; $('#searchClear').hidden=true; go('featured',{replace:true}); }
});
$('#btnBack').addEventListener('click', goBack);
$('#btnReload').addEventListener('click', () => runRefresh());
$('#btnUpdateAll').addEventListener('click', runUpdateAll);

/* clock */
(function tick(){
  const d = new Date();
  const h = d.getHours(), m = String(d.getMinutes()).padStart(2,'0');
  const ap = h < 12 ? 'AM' : 'PM';
  const hh = h % 12 || 12;
  const days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  $('#mbClock').textContent = `${days[d.getDay()]} ${hh}:${m} ${ap}`;
  setTimeout(tick, 20000);
})();

render();
