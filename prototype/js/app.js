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

/* ---------------- state ---------------- */
const state = {
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
  const nUpd = PKGS.filter(p => p.hasUpdate).length;
  const nIns = PKGS.filter(p => p.installed).length;
  const s = [];

  s.push(`<div class="side-head">Store</div>`);
  s.push(sideItem('featured','star','Featured'));
  s.push(sideItem('category','layers','Categories'));
  s.push(sideItem('updates','download', 'Updates', nUpd ? `<span class="side-badge">${nUpd}</span>` : ''));
  s.push(sideItem('search','search','Search'));

  s.push(`<div class="side-head">Library</div>`);
  s.push(sideItem('installed','archive','Installed', `<span class="side-count">${nIns}</span>`));

  s.push(`<div class="side-head">Sources</div>`);
  s.push(sideItem('sources','server','All Sources'));
  SOURCES.forEach(function(src){
    const active = state.route === 'source' && state.section === src.id;
    s.push(`<div class="side-item src${active?' active':''}" data-nav="source" data-sec="${src.id}">
      <span class="side-ico"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M4 6.5h16M4 12h16M4 17.5h16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" opacity=".9"/><circle cx="8" cy="6.5" r="1.7" fill="currentColor"/><circle cx="14" cy="12" r="1.7" fill="currentColor"/><circle cx="10" cy="17.5" r="1.7" fill="currentColor"/></svg></span>
      <span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(src.name)}</span>
      <span class="dot ${src.status}" title="${src.status}"></span>
    </div>`);
  });

  s.push(`<div class="side-head">Store</div>`);
  s.push(sideItem('settings','gear','Settings'));

  $('#sidebar').innerHTML = s.join('');
}
function sideItem(route, glyph, label, right){
  return `<div class="side-item${state.route===route?' active':''}" data-nav="${route}">
    <span class="side-ico">${navGlyph(glyph)}</span>
    <span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${label}</span>
    ${right || ''}</div>`;
}
const NAV_G = {
  star:`<svg viewBox="0 0 24 24" width="15" height="15"><path fill="currentColor" d="M12 2.2l3 6.3 6.9.9-5 4.8 1.3 6.8L12 17.8 5.8 21l1.3-6.8-5-4.8 6.9-.9z"/></svg>`,
  layers:`<svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 2.4l9.5 4.9L12 12.2 2.5 7.3z" fill="currentColor" opacity=".4"/><path d="M2.5 12.2L12 17l9.5-4.8-9.5-4.8zM2.5 16.6L12 21.4l9.5-4.8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>`,
  download:`<svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3v11m0 0 4.2-4.2M12 14l-4.2-4.2M4 19.5h16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  search:`<svg viewBox="0 0 24 24" width="15" height="15"><circle cx="10.5" cy="10.5" r="6.4" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M15.2 15.2L20 20" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>`,
  archive:`<svg viewBox="0 0 24 24" width="15" height="15"><rect x="2.6" y="3.6" width="18.8" height="4.8" rx="1.6" fill="currentColor"/><path d="M4.6 8.6h14.8v9.6a2 2 0 0 1-2 2H6.6a2 2 0 0 1-2-2z" fill="currentColor" opacity=".42"/><path d="M4.6 8.6h14.8v9.6a2 2 0 0 1-2 2H6.6a2 2 0 0 1-2-2z" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M10 12.4h4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>`,
  server:`<svg viewBox="0 0 24 24" width="15" height="15"><rect x="2.6" y="3.2" width="18.8" height="7" rx="1.8" fill="currentColor" opacity=".35"/><rect x="2.6" y="3.2" width="18.8" height="7" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/><rect x="2.6" y="13.8" width="18.8" height="7" rx="1.8" fill="currentColor" opacity=".35"/><rect x="2.6" y="13.8" width="18.8" height="7" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/><g fill="currentColor"><circle cx="6" cy="6.7" r="1.15"/><circle cx="6" cy="17.3" r="1.15"/></g><g stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M10.4 6.7h7M10.4 17.3h7"/></g></svg>`,
  gear:`<svg viewBox="0 0 24 24" width="15" height="15"><path d="M19.6 13.4a7.9 7.9 0 0 0 0-2.8l2-1.5-2-3.4-2.4 1a7.7 7.7 0 0 0-2.4-1.4l-.4-2.6h-4l-.4 2.6c-.9.3-1.7.8-2.4 1.4l-2.4-1-2 3.4 2 1.5a7.9 7.9 0 0 0 0 2.8l-2 1.5 2 3.4 2.4-1c.7.6 1.5 1.1 2.4 1.4l.4 2.6h4l.4-2.6c.9-.3 1.7-.8 2.4-1.4l2.4 1 2-3.4z" fill="currentColor" opacity=".35"/><path d="M19.6 13.4a7.9 7.9 0 0 0 0-2.8l2-1.5-2-3.4-2.4 1a7.7 7.7 0 0 0-2.4-1.4l-.4-2.6h-4l-.4 2.6c-.9.3-1.7.8-2.4 1.4l-2.4-1-2 3.4 2 1.5a7.9 7.9 0 0 0 0 2.8l-2 1.5 2 3.4 2.4-1c.7.6 1.5 1.1 2.4 1.4l.4 2.6h4l.4-2.6c.9-.3 1.7-.8 2.4-1.4l2.4 1 2-3.4z" fill="none" stroke="currentColor" stroke-width="1.35"/><circle cx="12" cy="12" r="2.9" fill="currentColor"/></svg>`
};
function navGlyph(k){ return NAV_G[k] || ''; }

/* ============================================================
   CONTENT ROUTER
   ============================================================ */
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
    pkg:       viewPackage
  }[state.route] || viewFeatured)();
  renderStatus();
  renderToolbar();
}

function renderToolbar(){
  const upd = PKGS.filter(p => p.hasUpdate);
  $('#btnBack').disabled = !state.back.length && state.route !== 'pkg';
  $('#btnUpdateAll').hidden = !(upd.length && (state.route === 'updates'));
  const showSearch = state.route !== 'settings';
  $('#searchWrap').style.visibility = showSearch ? 'visible' : 'hidden';
  const titles = {
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
    <div class="grid">${picks.map(p => cell(p, true)).join('')}</div>
    <div class="group-title">Also worth a look</div>
    <div class="grid">${recent.map(p => cell(p)).join('')}</div>
  </div>`;
}
function cell(p, badge){
  return `<div class="cell" data-pkg="${p.id}">${icon(p,64)}
    <div class="name">${esc(p.name)}</div>
    <div class="sub">${badge ? '★ '.repeat(p.stars) : esc(typeLabel(p.type))}</div>
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
        <div class="aicon sz-64" style="background:linear-gradient(160deg,${g[0]},${g[1]});color:#fff">
          <svg viewBox="0 0 24 24" width="34" height="34">${gl}</svg></div>
        <div class="name">${c.key}</div><div class="sub">${n} package${n===1?'':'s'}</div></div>`;
    }).join('')}</div>
  </div>`;
}

function viewCategoryList(sec){
  sec = sec || state.section;
  const list = PKGS.filter(p => p.section === sec);
  return `<div class="pad">
    <h1 class="sec-title">${esc(sec)}</h1>
    <p class="sec-sub">${list.length} package${list.length===1?'':'s'}.</p>
    <div class="rows">${list.map(p => row(p)).join('')}</div>
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
      return `<div class="row" data-src="${s.id}">
        <div class="aicon sz-28" style="background:linear-gradient(160deg,#9aa3b2,#5c6675);color:#fff"><svg viewBox="0 0 24 24" width="16" height="16"><path d="M4 6.5h16M4 12h16M4 17.5h16" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><circle cx="8" cy="6.5" r="1.7" fill="currentColor"/><circle cx="14" cy="12" r="1.7" fill="currentColor"/><circle cx="10" cy="17.5" r="1.7" fill="currentColor"/></svg></div>
        <div class="row-main"><div class="row-name">${esc(s.name)} ${s.kind==='official'?'<span class="tag tag-inst">Official</span>':''}</div>
        <div class="row-sub">${esc(s.url)}</div></div>
        <div class="row-right">${st[0]} <span style="font-size:12px;color:${s.status==='ok'?'var(--ink-3)':s.status==='err'?'var(--danger)':'var(--warn)'}">${st[1]}</span> <span style="font-size:12px;color:var(--ink-3)">· ${n} pkg</span>
        <span class="pill ${s.status==='err'?'danger':''}">${s.status==='ok'?'Remove':'Edit'}</span></div></div>`;
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
function openInstall(pkgId){
  const p = byId(pkgId);
  const plan = resolvePlan(p);
  const conflicts = planConflicts(plan);
  const needsPriv = plan.some(x => x.type === 'pkg' || x.type === 'kext');
  const isUpdate = !!p.hasUpdate;

  const owner = newOwner('install-confirm:' + p.id);
  overlay(`
    <div class="scrim" data-close data-owner="${owner}"></div>
    <div class="sheet" style="top:11%" data-owner="${owner}">
      <div class="sheet-head">
        <div class="sheet-title">${isUpdate ? 'Update' : 'Install'} ${esc(plan.length > 1 ? plan.length + ' Packages' : p.name)}</div>
        <div class="sheet-sub">${plan.length} package${plan.length===1?'':'s'} · ${bytes(plan.reduce((a,b)=>a+b.size,0))} total</div>
      </div>
      <div class="sheet-body">
        ${conflicts.length ? `<div class="notice err"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 3.2l9.2 16H2.8z" fill="currentColor" opacity=".3"/><path d="M12 3.2l9.2 16H2.8z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 9.5v5M12 17.2v.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
          <div class="grow"><b>Conflict.</b> ${esc(p.name)} conflicts with ${conflicts.map(c=>c.other.name).join(', ')}, which ${conflicts.length>1?'are':'is'} installed. It must be removed first.</div></div>` : ''}
        <div class="plist">${plan.map(function(x){
          const tag = x.id === p.id
            ? (isUpdate ? '<span class="tag tag-upd">Update</span>' : '<span class="tag tag-new">Install</span>')
            : '<span class="tag tag-dep">Dependency</span>';
          return `<div class="pitem">${icon(x,28)}
            <div><div class="nm">${esc(x.name)}</div><div class="vr">${esc(x.version)} · ${esc(typeLabel(x.type))} · ${bytes(x.size)}</div></div>
            ${tag}</div>`;
        }).join('')}</div>
        ${needsPriv ? `<div class="notice" style="margin:14px 0 0"><svg viewBox="0 0 24 24" width="15" height="15"><rect x="4.4" y="10.2" width="15.2" height="11.4" rx="2.4" fill="currentColor" opacity=".3"/><rect x="4.4" y="10.2" width="15.2" height="11.4" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M8 10.2V7.6a4 4 0 0 1 8 0v2.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
          <div class="grow"><b>Your password will be requested.</b> This plan includes a ${plan.filter(x=>x.type!=='app').map(x=>esc(x.name)).join(', ')}, which installs outside /Applications.</div></div>` : ''}
      </div>
      <div class="sheet-foot">
        <button class="btn" data-close>Cancel</button>
        <button class="btn primary" data-act="do-install" data-plan="${plan.map(x=>x.id).join(',')}" data-primary="${p.id}" ${conflicts.length?'disabled':''}>
          ${isUpdate ? 'Update' : 'Install'}</button>
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

/* ---------- install progress ---------- */
let installRun = null;   // { cancelled:bool } — one per in-flight run

function runInstall(ids, primaryIds){
  const plan = ids.map(byId).filter(Boolean);
  const primary = (primaryIds || ids);
  const isUpdate = plan[0].hasUpdate;
  const steps = [
    { label:'Downloading…', w:[18,46,78,100], logs:[
      'GET /pool/'+plan[0].id.toLowerCase()+'/'+plan[0].version+'.pkg',
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
  const run = { cancelled:false, owner:newOwner('install') };
  installRun = run;

  overlay(`
    <div class="scrim"></div>
    <div class="sheet prog-card" style="top:24%">
      <div class="sheet-head" style="padding-bottom:14px">
        <div class="sheet-title">${isUpdate ? 'Updating' : 'Installing'} ${esc(plan.length>1 ? plan.length + ' packages' : plan[0].name)}</div>
      </div>
      <div class="sheet-body">
        <div class="prog-hero">${icon(plan[0],64)}
          <div style="flex:1">
            <div class="prog-name">${esc(plan[0].name)}</div>
            <div class="prog-step" id="progStep">Starting…</div>
          </div>
          <div style="text-align:right;font-size:11.5px;color:var(--ink-3)">
            <div id="progPct">0%</div><div>of ${bytes(plan.reduce((a,b)=>a+b.size,0))}</div></div>
        </div>
        <div class="bar"><i id="progBar"></i></div>
        <div class="prog-log" id="progLog"></div>
      </div>
      <div class="sheet-foot"><button class="btn" data-act="cancel-install">Cancel</button></div>
    </div>`, run.owner);

  const bar = $('#progBar'), pct = $('#progPct'), stepEl = $('#progStep'), logEl = $('#progLog');
  let si = 0, logQueue = [];

  function pumpLog(){
    while (logQueue.length){
      const d = document.createElement('div');
      d.innerHTML = logQueue.shift();
      logEl.appendChild(d);
      logEl.scrollTop = logEl.scrollHeight;
      if (logEl.children.length > 6) logEl.removeChild(logEl.firstChild);
    }
  }

  function nextStep(){
    if (run.cancelled) return;
    if (si >= steps.length){
      setTimeout(() => {
        if (run.cancelled) return;
        plan.forEach(function(x){
          x.installed = true;
          x.pkgVersion = x.version;
          x.hasUpdate = false;
          // anything pulled in only to satisfy a dependency is removable later
          x.autoInstalled = primary.indexOf(x.id) === -1;
        });
        if (installRun === run) installRun = null;
        closeOverlay(run.owner);
        render();
        toast(isUpdate ? `Updated ${plan[0].name}` : `Installed ${plan[0].name}`, 'ok');
        if (plan[0].type === 'kext') toast('Restart required to load the kernel extension');
      }, 320);
      return;
    }
    const st = steps[si];
    stepEl.textContent = st.label;
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
      const overall = Math.round((si + st.w[i] / 100) / steps.length * 100);
      bar.style.width = overall + '%';
      pct.textContent = overall + '%';
      if (i > 0) pumpLog();
      i++;
    }, 210 + Math.random() * 110);
  }
  setTimeout(nextStep, 300);
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

  const cancelEl = e.target.closest('[data-act="cancel-install"]');
  if (cancelEl && installRun && ownsOverlay(installRun.owner)){
    installRun.cancelled = true;   // stops this run's timers for good
    const owner = installRun.owner;
    installRun = null;
    closeOverlay(owner);
    toast('Installation cancelled');
    render();
    return;
  }

  const nav = e.target.closest('[data-nav]');
  if (nav){
    const r = nav.dataset.nav, s = nav.dataset.sec;
    if (r === 'featured')  go('featured', { replace:true });
    else if (r === 'category') go('category', { replace:true });
    else if (r === 'source')   go('source', { section:s, replace:true });
    else go(r, { replace:true });
    return;
  }
  const cat = e.target.closest('[data-cat]');
  if (cat){ go('categorylist', { section:cat.dataset.cat, replace:true }); return; }

  const pkgEl = e.target.closest('[data-pkg]');
  const act  = e.target.closest('[data-act]');

  if (pkgEl && !act && !e.target.closest('.pill,[data-act]')){
    go('pkg', { pkgId:pkgEl.dataset.pkg });
    return;
  }
  const tab = e.target.closest('[data-tab]');
  if (tab){ go('pkg', { pkgId:state.pkgId, tab:tab.dataset.tab, keepTab:true }); return; }

  if (!act) return;
  const a = act.dataset.act;

  if (a === 'install')        openInstall(act.dataset.pkg);
  else if (a === 'remove')    openRemove(act.dataset.pkg);
  else if (a === 'do-install'){ const ids = act.dataset.plan.split(','); closeOverlay(ownerOf(act)); runInstall(ids, [act.dataset.primary]); }
  else if (a === 'do-remove'){ const p = byId(act.dataset.pkg); closeOverlay(ownerOf(act)); runRemove(p); }
  else if (a === 'add-source')openAddSource();
  else if (a === 'save-source')saveSource(ownerOf(act));
  else if (a === 'retry-src'){ runRefresh(); }
  else if (a === 'refresh-all')runRefresh();
  else if (a === 'update-all')runUpdateAll();
});

function runRemove(p){
  const orphans = orphansAfterRemoving(p);
  const total = [p].concat(orphans);
  const owner = newOwner('remove:' + p.id);
  overlay(`
    <div class="scrim"></div>
    <div class="sheet prog-card" style="top:28%">
      <div class="sheet-head" style="padding-bottom:12px"><div class="sheet-title">Removing ${esc(total.length>1 ? total.length + ' Packages' : p.name)}</div></div>
      <div class="sheet-body">
        <div class="prog-step" id="rmStep" style="margin-bottom:9px">Running uninstall script…</div>
        <div class="bar"><i id="rmBar"></i></div>
      </div>
    </div>`, owner);
  let w = 0;
  const iv = setInterval(() => {
    w += 22 + Math.random()*20;
    $('#rmBar').style.width = Math.min(100, w) + '%';
    if (w >= 100){
      clearInterval(iv);
      $('#rmStep').textContent = p.type === 'app' ? 'Moved to the Trash' : 'Payload removed · database updated';
      setTimeout(() => {
        total.forEach(function(x){ x.installed = false; x.pkgVersion = null; x.hasUpdate = false; x.autoInstalled = false; });
        closeOverlay(owner);
        go('installed', { replace:true });
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
