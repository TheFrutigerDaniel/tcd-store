/* ============================================================
   TCD Store — mock package database
   Mirrors the on-disk schema the Objective-C port will use.
   Fields mirror a Cydia-style `Packages` index entry.
   ============================================================ */

const GLYPHS = {
  terminal:`<path d="M3 4h18v16H3z" fill="currentColor" opacity=".22"/><path d="M3 4h18v16H3z" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M6.5 9.5l3 2.5-3 2.5M12 15h5.5" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>`,
  brush:`<path d="M16.5 2.5a2.2 2.2 0 0 1 3.1 3.1l-8 8-4.1 1 1-4.1z" fill="currentColor"/><path d="M6.5 15c-1.6.5-2.2 1.6-2.4 3.1-.1 1 .7 1.6 1.6 1.4 1.4-.3 2.4-1 2.7-2.6z" fill="currentColor" opacity=".7"/>`,
  chip:`<rect x="6.5" y="6.5" width="11" height="11" rx="1.6" fill="currentColor"/><g stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><path d="M9.5 2.5v4M14.5 2.5v4M9.5 17.5v4M14.5 17.5v4M2.5 9.5h4M2.5 14.5h4M17.5 9.5h4M17.5 14.5h4"/></g>`,
  wave:`<path d="M2 14.5c2.2 0 2.2-5 4.4-5s2.2 5 4.4 5 2.2-5 4.4-5 2.2 5 4.4 5 2.2-5 4.4-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M2 9.5c2.2 0 2.2-4 4.4-4s2.2 4 4.4 4 2.2-4 4.4-4 2.2 4 4.4 4 2.2-4 4.4-4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" opacity=".45"/>`,
  shield:`<path d="M12 2.2l8 3.2v6.1c0 5-3.6 8.6-8 10.3-4.4-1.7-8-5.3-8-10.3V5.4z" fill="currentColor" opacity=".28"/><path d="M12 2.2l8 3.2v6.1c0 5-3.6 8.6-8 10.3-4.4-1.7-8-5.3-8-10.3V5.4z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M8.4 12.1l2.6 2.6 4.8-5" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>`,
  key:`<circle cx="7.5" cy="16.5" r="4.2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M10.6 13.4L20 4M17 7l2.4 2.4M14.6 9.4l2.4 2.4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>`,
  leaf:`<path d="M20 3.5c0 9-4.8 14-11 14-1.6 0-3-.3-4.2-.8C4 12 8 6.5 20 3.5z" fill="currentColor"/><path d="M4.8 20.5C8 15.6 12.4 12 18 9.4" fill="none" stroke="rgba(0,0,0,.32)" stroke-width="1.6" stroke-linecap="round"/>`,
  cube:`<path d="M12 2.4l9 4.8v9.6l-9 4.8-9-4.8V7.2z" fill="currentColor" opacity=".3"/><path d="M12 2.4l9 4.8v9.6l-9 4.8-9-4.8V7.2z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M3.2 7.3L12 12l8.8-4.7M12 12v9.4" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>`,
  sliders:`<g stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M4 7h7M15 7h5M4 12h3M11 12h9M4 17h9M17 17h3"/></g><g fill="currentColor"><circle cx="13" cy="7" r="2.4"/><circle cx="9" cy="12" r="2.4"/><circle cx="15" cy="17" r="2.4"/></g>`,
  bolt:`<path d="M13.4 2L5 13.2h5.3L9.9 22 19 10.4h-5.6z" fill="currentColor"/>`,
  network:`<g fill="currentColor"><circle cx="12" cy="4.6" r="2.6"/><circle cx="4.6" cy="18" r="2.6"/><circle cx="19.4" cy="18" r="2.6"/></g><g stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><path d="M10.6 6.9L6 15.6M13.4 6.9l4.6 8.7M7.2 18h9.6"/></g>`,
  camera:`<path d="M9 4.6h6l1.4 2.4H21a1.6 1.6 0 0 1 1.6 1.6v9.8A1.6 1.6 0 0 1 21 20H3a1.6 1.6 0 0 1-1.6-1.6V8.6A1.6 1.6 0 0 1 3 7h4.6z" fill="currentColor" opacity=".28"/><path d="M9 4.6h6l1.4 2.4H21A1.6 1.6 0 0 1 22.6 8.6v9.8A1.6 1.6 0 0 1 21 20H3a1.6 1.6 0 0 1-1.6-1.6V8.6A1.6 1.6 0 0 1 3 7h4.6z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><circle cx="12" cy="13.2" r="3.6" fill="none" stroke="currentColor" stroke-width="1.7"/>`,
  palette:`<path d="M12 2.6C6.8 2.6 2.6 6.8 2.6 12s4.2 9.4 9.4 9.4c1.3 0 2-.8 2-1.8 0-1.6-1.6-1.9-1.6-3.2 0-1 .8-1.7 1.9-1.7h1.9c2.6 0 4.8-2.1 4.8-4.8 0-4.1-3.9-7.3-9-7.3z" fill="currentColor" opacity=".3"/><g fill="currentColor"><circle cx="7.6" cy="12.4" r="1.9"/><circle cx="9.6" cy="8.2" r="1.9"/><circle cx="14.2" cy="7.6" r="1.9"/><circle cx="17" cy="11.4" r="1.9"/></g>`,
  wrench:`<path d="M20.5 5.2a5.6 5.6 0 0 1-7.2 7.2L5.6 20a2.3 2.3 0 0 1-3.3-3.3l7.6-7.7A5.6 5.6 0 0 1 17.2 2l-3.2 3.2 1.4 3.4 3.4 1.4L22 6.8z" fill="currentColor"/>`,
  globe:`<circle cx="12" cy="12" r="9.4" fill="currentColor" opacity=".25"/><circle cx="12" cy="12" r="9.4" fill="none" stroke="currentColor" stroke-width="1.7"/><g fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2.6 12h18.8M12 2.6c2.5 2.6 3.8 6 3.8 9.4s-1.3 6.8-3.8 9.4c-2.5-2.6-3.8-6-3.8-9.4S9.5 5.2 12 2.6z"/></g>`,
  layers:`<path d="M12 2.4l9.5 4.9L12 12.2 2.5 7.3z" fill="currentColor" opacity=".38"/><path d="M2.5 12.2L12 17l9.5-4.8-9.5-4.8zM2.5 16.6L12 21.4l9.5-4.8" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>`,
  cpu:`<rect x="5" y="5" width="14" height="14" rx="2" fill="currentColor" opacity=".3"/><rect x="5" y="5" width="14" height="14" rx="2" fill="none" stroke="currentColor" stroke-width="1.6"/><rect x="9" y="9" width="6" height="6" rx="1" fill="currentColor"/><g stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M9 2.5v2.5M15 2.5v2.5M9 19v2.5M15 19v2.5M2.5 9H5M2.5 15H5M19 9h2.5M19 15h2.5"/></g>`,
  feather:`<path d="M20.4 3.6c-8 0-13.6 4-13.6 10.4 0 1.6.3 2.7.3 2.7s-1.6-.6-3-2C2 16.2 1.5 18.6 1.5 18.6s3.1.9 5.5-.6c1.5-.9 2.6-2.4 2.6-2.4s.9 1 2.2 1c5.8 0 8.6-6 8.6-13z" fill="currentColor" opacity=".3"/><path d="M20.4 3.6c-8 0-13.6 4-13.6 10.4 0 1.6.3 2.7.3 2.7s-1.6-.6-3-2C2 16.2 1.5 18.6 1.5 18.6s3.1.9 5.5-.6c1.5-.9 2.6-2.4 2.6-2.4s.9 1 2.2 1c5.8 0 8.6-6 8.6-13z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>`,
  sparkle:`<path d="M12 2l1.9 6.1L20 10l-6.1 1.9L12 18l-1.9-6.1L4 10l6.1-1.9z" fill="currentColor"/><path d="M18.4 15.2l.8 2.4 2.4.8-2.4.8-.8 2.4-.8-2.4-2.4-.8 2.4-.8z" fill="currentColor" opacity=".7"/>`,
  window:`<rect x="2.4" y="3.6" width="19.2" height="16.8" rx="2.4" fill="currentColor" opacity=".25"/><rect x="2.4" y="3.6" width="19.2" height="16.8" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M2.4 8.4h19.2" stroke="currentColor" stroke-width="1.6"/><g fill="currentColor"><circle cx="5.4" cy="6" r=".95"/><circle cx="8.2" cy="6" r=".95"/><circle cx="11" cy="6" r=".95"/></g>`,
  gear:`<path d="M19.6 13.4a7.9 7.9 0 0 0 0-2.8l2-1.5-2-3.4-2.4 1a7.7 7.7 0 0 0-2.4-1.4l-.4-2.6h-4l-.4 2.6c-.9.3-1.7.8-2.4 1.4l-2.4-1-2 3.4 2 1.5a7.9 7.9 0 0 0 0 2.8l-2 1.5 2 3.4 2.4-1c.7.6 1.5 1.1 2.4 1.4l.4 2.6h4l.4-2.6c.9-.3 1.7-.8 2.4-1.4l2.4 1 2-3.4z" fill="currentColor" opacity=".3"/><path d="M19.6 13.4a7.9 7.9 0 0 0 0-2.8l2-1.5-2-3.4-2.4 1a7.7 7.7 0 0 0-2.4-1.4l-.4-2.6h-4l-.4 2.6c-.9.3-1.7.8-2.4 1.4l-2.4-1-2 3.4 2 1.5a7.9 7.9 0 0 0 0 2.8l-2 1.5 2 3.4 2.4-1c.7.6 1.5 1.1 2.4 1.4l.4 2.6h4l.4-2.6c.9-.3 1.7-.8 2.4-1.4l2.4 1 2-3.4z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><circle cx="12" cy="12" r="3" fill="currentColor"/>`,
  lock:`<rect x="4.4" y="10.2" width="15.2" height="11.4" rx="2.4" fill="currentColor" opacity=".3"/><rect x="4.4" y="10.2" width="15.2" height="11.4" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M8 10.2V7.6a4 4 0 0 1 8 0v2.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="15.6" r="1.7" fill="currentColor"/>`,
  archive:`<rect x="2.6" y="4" width="18.8" height="4.6" rx="1.6" fill="currentColor"/><path d="M4.4 8.6h15.2v9.8a2 2 0 0 1-2 2H6.4a2 2 0 0 1-2-2z" fill="currentColor" opacity=".45"/><path d="M4.4 8.6h15.2v9.8a2 2 0 0 1-2 2H6.4a2 2 0 0 1-2-2z" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M10 12.4h4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>`,
  monitor:`<rect x="2.2" y="3.8" width="19.6" height="13.2" rx="2.2" fill="currentColor" opacity=".28"/><rect x="2.2" y="3.8" width="19.6" height="13.2" rx="2.2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M8.4 20.4h7.2M12 17v3.4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>`,
  battery:`<rect x="2" y="7.4" width="17.4" height="9.2" rx="2.4" fill="currentColor" opacity=".28"/><rect x="2" y="7.4" width="17.4" height="9.2" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M21.4 10.6v2.8" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/><path d="M4.6 12h6.8" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>`,
  wifi:`<g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M2.4 8.4a14 14 0 0 1 19.2 0M6 12.2a9 9 0 0 1 12 0M9.4 15.8a4.4 4.4 0 0 1 5.2 0"/></g><circle cx="12" cy="19.4" r="1.7" fill="currentColor"/>`,
  book:`<path d="M4 3.4h6.2c1 0 1.8.8 1.8 1.8v15c0-1-.8-1.8-1.8-1.8H4z" fill="currentColor" opacity=".45"/><path d="M4 3.4h6.2c1 0 1.8.8 1.8 1.8v15c0-1-.8-1.8-1.8-1.8H4z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M20 3.4h-6.2c-1 0-1.8.8-1.8 1.8v15c0-1 .8-1.8 1.8-1.8H20z" fill="currentColor" opacity=".45"/><path d="M20 3.4h-6.2c-1 0-1.8.8-1.8 1.8v15c0-1 .8-1.8 1.8-1.8H20z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>`,
  bug:`<path d="M8.6 8.4a3.4 3.4 0 0 1 6.8 0v7a3.4 3.4 0 0 1-6.8 0z" fill="currentColor"/><path d="M12 5V2.4M8.6 8.4L5 6.6M15.4 8.4l3.6-1.8M8.6 12H4.4M15.4 12h4.2M8.6 15.2L5 17M15.4 15.2L19 17" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>`,
  star:`<path d="M12 2.2l3 6.3 6.9.9-5 4.8 1.3 6.8L12 17.8 5.8 21l1.3-6.8-5-4.8 6.9-.9z" fill="currentColor"/>`,
  play:`<circle cx="12" cy="12" r="9.4" fill="currentColor" opacity=".3"/><circle cx="12" cy="12" r="9.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M9.6 7.2l7.2 4.8-7.2 4.8z" fill="currentColor"/>`,
  bridge:`<path d="M2 9.6h20M4.4 9.6V6.2M9 9.6V6.2M15 9.6V6.2M19.6 9.6V6.2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M2 13.4c3.4-3 6.4-3 9.8 0 3.4 3 6.6 3 10.2 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M2 18.2c3.4-3 6.4-3 9.8 0 3.4 3 6.6 3 10.2 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" opacity=".45"/>`
};

const ICON_DEFS = {
  violet:['#8e7cf0','#5b49c9'], blue:['#5b9bee','#2f7fd4'], teal:['#4fc3c9','#1f8f96'],
  green:['#68c96f','#2e9e46'], amber:['#f7b955','#e08a1a'], red:['#f4796b','#d0342c'],
  slate:['#8f9bab','#5c6675'], pink:['#f38fb1','#d95b86'], indigo:['#6d8cf5','#3b57c8'],
  graphite:['#7b8493','#464f5c'], cyan:['#5fd0e0','#1f9cb0'], olive:['#9cb45f','#658032']
};

/* ---------- sources ---------- */
const SOURCES = [
  { id:'tcd',      name:'TCD Store',            url:'https://repo.tcd-store.dev/', status:'ok',   kind:'official' },
  { id:'tcd-legacy',name:'TCD Legacy Archive',   url:'https://legacy.tcd-store.dev/', status:'ok', kind:'official' },
  { id:'applejack',name:'Applejack',            url:'https://pkgs.applejack.dev/', status:'warn', kind:'third-party' },
  { id:'sourcery', name:'Sourcery',             url:'http://sourcery.example.org/p/', status:'ok',  kind:'third-party' },
  { id:'ninthrow', name:'Ninth Row (broken)',   url:'https://mirror.9throw.net/x/', status:'err', kind:'third-party' }
];

/* ---------- packages ---------- */
const PKGS = [
  { id:'iTerm2', name:'iTerm2', version:'2.9.3', type:'app', section:'Developer Tools',
    developer:'George Nachman', icon:['graphite','terminal'], cPrice:0,
    summary:'A replacement for Terminal with split panes, search and tmux integration.',
    description:'iTerm2 is a replacement for Terminal.app that does everything Terminal.app does and more. Split panes, searchable scrollback, trigger support, profile hotkeys and a hotkey window. Every release is built and tested against the oldest macOS version we support, so a working build always exists for your machine.',
    depends:[], conflicts:[],
    size:9_418_752, stars:4, rating:2481, minOs:'10.7', source:'tcd',
    notes:['Universal binary — runs on 32- and 64-bit Macs alike.','Uninstall is clean: no receipts, no leftovers.'],
    changelog:[
      ['2.9.3','Aug 12, 2013','Fixed a crash when resizing a split pane while a profile is switching. Fixed unicode 9 width handling in tmux integration.'],
      ['2.9.2','Jul 30, 2013','Added "New Split Vertically" to the shortcuts menu. Fixed bell not firing in some tmux configurations.'],
      ['2.9.1','Jul 19, 2013','Fixed a regression where the password manager prompt appeared behind fullscreen windows.']
    ] },

  { id:'handbrake', name:'HandBrake', version:'0.9.4', type:'app', section:'Video',
    developer:'HandBrake Team', icon:['indigo','camera'], cPrice:0,
    summary:'Video transcoder — convert almost anything to almost anything.',
    description:'HandBrake converts video from nearly any format to a selection of widely supported ones. This build is compiled against the last libavcodec that still supports 32-bit targets, which is why the encoder list looks unusual next to modern HandBrake. Preset passthrough and hardware acceleration from VideoToolbox are both available.',
    depends:[], conflicts:[],
    size:18_874_368, stars:4, rating:1204, minOs:'10.7', source:'tcd',
    notes:['Includes H.264, MPEG-4, VP8 and VP9 encoders.','CLI binary is at Contents/Resources/HandBrakeCLI.'],
    changelog:[
      ['0.9.4','Sep 4, 2013','Rebuilt against the 32-bit-safe libavcodec. Fixed a crash converting very long chapters.'],
      ['0.9.3','Jul 22, 2013','Added the "Fast 1080p30" preset. Fixed subtitle burning offset on some MKV sources.']
    ] },

  { id:'fakesmc', name:'FakeSMC', version:'1.3.1', type:'kext', section:'System',
    developer:'Slice', icon:['graphite','chip'], cPrice:0,
    summary:'Emulates the Super Microcontroller Chip so SMC sensors work on non-Apple hardware.',
    description:'Almost every hackintosh and many older Macs need FakeSMC before any fan-speed or temperature utility can read the hardware. It presents a fake but plausible SMC to the IOKit layer, and it loads as a kext into /System/Library/Extensions.',
    depends:['openscpx'], conflicts:['smcsuperio'],
    size:233_472, stars:4, rating:612, minOs:'10.7', source:'tcd-legacy',
    notes:['A kext, not an app. The store will offer to remove it after reboot.','Signed with the TCD Store identity so it survives a fresh boot.'],
    changelog:[
      ['1.3.1','Jun 18, 2013','Added Ivy Bridge bridge support. Fixed a leak in the temperature getter.'],
      ['1.3.0','Feb 2, 2013','Sandy Bridge and Ivy Bridge support. Replaced the old IOHID approach.']
    ] },

  { id:'openscpx', name:'OpenSCPx Plug-in', version:'1.0.2', type:'kext', section:'System',
    developer:'LinuxDriver', icon:['graphite','gear'], cPrice:0,
    summary:'CPU power-management provider required by FakeSMC on older chipsets.',
    description:'FakeSMC queries the CPU through an SCPM plug-in. This is the Intel one. It is listed as a hard dependency so the store pulls it in automatically rather than leaving you with a kext that silently reports nothing.',
    depends:[], conflicts:[],
    size:172_032, stars:3, rating:188, minOs:'10.7', source:'tcd-legacy',
    notes:['Loaded before FakeSMC. The store orders kext installation automatically.'],
    changelog:[ ['1.0.2','May 30, 2013','Fixed CPU reporting on Westmere.'] ] },

  { id:'smcsuperio', name:'SMCSuperIO', version:'1.1.1', type:'kext', section:'System',
    developer:'Slice', icon:['graphite','chip'], cPrice:0,
    summary:'Direct hardware SMC access. Faster and more accurate than FakeSMC, but conflicts with it.',
    description:'SMCSuperIO talks to the Super I/O chip directly instead of emulating it, so temperature and fan readings are exact. Only some chipsets are supported and it cannot be loaded alongside FakeSMC — the two provide the same service and the second one to load will fail. The store treats this as a hard conflict and will not let you install both.',
    depends:['openscpx'], conflicts:['fakesmc'],
    size:141_312, stars:3, rating:94, minOs:'10.7', source:'tcd-legacy',
    notes:['Hard conflict with FakeSMC. Remove one before installing the other.','Only works on machines with a supported Super I/O chip.'],
    changelog:[
      ['1.1.1','Apr 9, 2013','Added ITE 8728 support.'],
      ['1.1.0','Feb 20, 2013','Reworked for the 10.7+ kext ABI.']
    ] },

  { id:'mesa', name:'Mesa3D for Intel HD 4000', version:'12.0.1', type:'pkg', section:'Graphics',
    developer:'Mesa Project', icon:['blue','cpu'], cPrice:0,
    summary:'OpenGL driver that replaces Apple\'s — far faster OpenGL on Ivy Bridge.',
    description:'Apple stopped shipping a usable OpenGL driver long before Ivy Bridge. This Mesa build is a drop-in replacement: install it, log out, and OpenGL apps jump from single-digit frame rates to something playable. It also unlocks GL 3.2 and 4.1 on hardware Apple capped at 3.1.',
    depends:['intelopenglfix'], conflicts:['graphicsoverride'],
    size:104_857_600, stars:5, rating:873, minOs:'10.8', source:'applejack',
    notes:['100 MB download. Requires a restart.','Only worth installing on Ivy Bridge. Haswell and later are fine already.'],
    changelog:[
      ['12.0.1','Aug 27, 2013','Fixed a black-screen regression introduced in 12.0.0 when using two displays.'],
      ['12.0.0','Jul 15, 2013','GL 4.1 core profile on Ivy Bridge. New Gallium state tracker.']
    ] },

  { id:'intelopenglfix', name:'Intel Graphics Fixup', version:'1.2.4', type:'kext', section:'Graphics',
    developer:'Pawel Król', icon:['blue','layers'], cPrice:0,
    summary:'Required companion kext for Mesa3D — exposes the registers Mesa needs.',
    description:'Mesa needs direct access to graphics registers that macOS normally hides. IntelGraphicsFixup is a kext that exposes them to kexts loaded after it. It must be installed before Mesa3D; the store handles the ordering.',
    depends:[], conflicts:[],
    size:98_304, stars:4, rating:141, minOs:'10.8', source:'applejack',
    notes:['Must load before Mesa3D. The store orders this automatically.'],
    changelog:[ ['1.2.4','Aug 27, 2013','Ivy Bridge framebuffer fix. Matches Mesa 12.0.1.'] ] },

  { id:'graphicsoverride', name:'GraphicsOverride', version:'1.0.3', type:'kext', section:'Graphics',
    developer:'Acidanthera', icon:['violet','monitor'], cPrice:0,
    summary:'Fixes black screens and bad sleeps on laptops with hybrid graphics.',
    description:'GraphicsOverride patches the graphics drivers so a laptop with switchable graphics boots to a working framebuffer instead of a black screen, and so the display comes back after sleep. If it is already loaded, Mesa3D cannot take over the OpenGL stack — the two are mutually exclusive and the store will say so before installing either.',
    depends:[], conflicts:['mesa'],
    size:82_944, stars:4, rating:232, minOs:'10.8', source:'tcd-legacy',
    notes:['Mutually exclusive with Mesa3D. The store blocks one until the other is removed.','A kext — the store offers to remove it after reboot.'],
    changelog:[
      ['1.0.3','Sep 1, 2013','Mavericks sleep/wake fixes. Added Haswell framebuffer support.'],
      ['1.0.2','Jul 20, 2013','Fixed black screen on cold boot with Optimus.'],
      ['1.0.0','May 11, 2013','First release extracted from WhateverGreen.']
    ] },

  { id:'bettertouchtool', name:'BetterTouchTool', version:'2.0.2', type:'app', section:'Utilities',
    developer:'Andreas Hegen', icon:['graphite','sliders'], cPrice:0,
    summary:'Reassign every button on your keyboard and every gesture on your trackpad.',
    description:'BetterTouchTool maps hardware buttons and trackpad gestures to shortcuts, app actions or shell commands. It can remap the volume keys to do something useful, bind a three-finger swipe to a workspace switch, and put a touch bar on a keyboard that never had one. Runs entirely in the background and is cheap on battery.',
    depends:[], conflicts:[],
    size:6_291_456, stars:5, rating:1567, minOs:'10.7', source:'tcd',
    notes:['Needs Accessibility permission on 10.8+. The store explains this on first launch.','A preference pane is installed alongside the app.'],
    changelog:[
      ['2.0.2','Sep 2, 2013','Added per-space shortcuts. Fixed trackpad three-finger detection on 10.9.'],
      ['2.0.1','Aug 10, 2013','Fixed an issue where mouse buttons stayed bound after a display sleep.'],
      ['2.0.0','Jul 18, 2013','Complete rewrite. New default preferences structure.']
    ] },

  { id:'cyberduck', name:'Cyberduck', version:'4.7.3', type:'app', section:'Networking',
    developer:'David Kocher', icon:['cyan','globe'], cPrice:0,
    summary:'S3, FTP and WebDAV client in one window, with a proper file browser.',
    description:'Cyberduck is a file transfer client for a dozen protocols, with bookmarks, a connection history and QuickLook support on the Mac. This build is the last one to support 10.7 — later versions raised the minimum to 10.8. Protocols: S3, FTP, FTPS, SFTP, WebDAV, Google Drive, Dropbox.',
    depends:[], conflicts:[],
    size:31_457_280, stars:4, rating:674, minOs:'10.7', source:'tcd-legacy',
    notes:['Last version supporting 10.7.','Interoperability build only; the update check is disabled.'],
    changelog:[
      ['4.7.3','Jun 6, 2013','Final 10.7-compatible release. Fixed an S3 listing truncation at 1000 keys.'],
      ['4.7.2','May 14, 2013','Added Google Drive. Fixed a certificate prompt loop on self-signed hosts.']
    ] },

  { id:'sublimetext', name:'Sublime Text 2', version:'2.0.2', type:'app', section:'Developer Tools',
    developer:'Sublime HQ', icon:['amber','brush'], cPrice:0,
    summary:'Fast text editor. Still the best thing to edit code on an old machine.',
    description:'Sublime Text stays open across a project of thousands of files without getting slow, which is exactly the property you want on a machine with 8 GB of RAM. This is a trial build — it is fully functional and shows an occasional nag. Version 3 was the first to require 10.8 and 64-bit.',
    depends:[], conflicts:[],
    size:7_340_032, stars:5, rating:2103, minOs:'10.7', source:'tcd',
    notes:['Trial build. Unlicensed copies prompt on save.','A licence bought in 2013 still activates this version.'],
    changelog:[
      ['2.0.2','May 8, 2013','64-bit build. Fixed a crash with very long lines.'],
      ['2.0.1','Mar 21, 2013','Auto-save improvements. Faster file indexing on network volumes.'],
      ['2.0.0','Feb 20, 2013','64-bit Mac support, new theme engine.']
    ] },

  { id:'onsy', name:'OnyX', version:'2.2.1', type:'app', section:'System',
    developer:'TiTi', icon:['slate','wrench'], cPrice:0,
    summary:'Maintenance tool: rebuild catalogues, clear caches, fix permissions.',
    description:'OnyX exposes the maintenance routines that ship inside OS X but are not reachable from the Finder. Rebuilding launch services databases, clearing preference caches, forcing a safe-mode boot, resetting the login window — all of it is here, with an interface that tells you what each button will do before it does it.',
    depends:[], conflicts:[],
    size:2_097_152, stars:4, rating:409, minOs:'10.7', source:'tcd-legacy',
    notes:['Requests admin rights per action, never once for the whole session.'],
    changelog:[ ['2.2.1','Mar 12, 2013','10.8 compatibility. Fixed the "Reset Privacy" entry on 10.7.'] ] },

  { id:'vlc', name:'VLC', version:'2.1.1', type:'app', section:'Video',
    developer:'VideoLAN', icon:['amber','play'], cPrice:0,
    summary:'Plays basically every format, and plays DVDs on hardware that cannot.',
    description:'VLC is the reference for format coverage and the reference for "it will not crash". This is a 32-bit build, which means it is the last version that runs on 2006-era Macs. Hardware decoding works on most Intel integrated graphics of that vintage, with the caveat that the interface and the decoder cannot both be active.',
    depends:[], conflicts:[],
    size:41_943_040, stars:4, rating:3190, minOs:'10.6', source:'tcd-legacy',
    notes:['32-bit build — the only way it runs on pre-2008 Macs.','A command-line interface is available for scripting.'],
    changelog:[
      ['2.1.1','Apr 16, 2013','32-bit build for legacy hardware. Fixed DVD menu navigation on some drives.'],
      ['2.1.0','Mar 8, 2013','New interface. Fixed a long-standing A/V desync bug.']
    ] },

  { id:'java6', name:'Java 6 JRE', version:'1.6.0_26', type:'pkg', section:'Developer Tools',
    developer:'Apple / Oracle', icon:['red','cube'], cPrice:0,
    summary:'The last Java 6 release on Mac OS X. Replaced by Java 8 — they do not coexist.',
    description:'Java 6 is what a stock 10.7 or 10.8 machine shipped with. It cannot be updated to Java 8 in place: the two use different launch services registrations and different JVM directories, and having both installed reliably breaks the applet plugin registration. Remove this before installing Java 8.',
    depends:[], conflicts:['java8'],
    size:35_651_584, stars:2, rating:288, minOs:'10.7', source:'tcd-legacy',
    notes:['Superseded by Java 8. The store will not install both.','Removing this also removes the Java preference pane.'],
    changelog:[ ['1.6.0_26','Feb 17, 2012','Final Java 6 release. Last to support Mac OS X 10.7.'] ] },

  { id:'netqos', name:'NetQoS Governor', version:'3.2.0', type:'kext', section:'Networking',
    developer:'NetQoS', icon:['indigo','sliders'], cPrice:0,
    summary:'Shapes and prioritises traffic with a kext-based filter. Conflicts with VPN tap drivers.',
    description:'NetQoS puts a priority filter in the kernel and lets you set per-application bandwidth caps. Because it filters at the tap layer it takes exclusive ownership of the tun/tap device, which means it cannot run at the same time as a VPN client that ships its own driver. Pick one.',
    depends:[], conflicts:['openvpn'],
    size:204_800, stars:3, rating:76, minOs:'10.7', source:'tcd-legacy',
    notes:['Exclusive ownership of /dev/tap*. Conflicts with VPN clients that ship a tap driver.','A kext — the store offers to remove it after reboot.'],
    changelog:[
      ['3.2.0','Jun 3, 2013','Per-app rules. Fixed a leak in the packet classifier.'],
      ['3.1.0','Feb 8, 2013','10.8 compatibility.']
    ] },

  { id:'openvpn', name:'OpenVPN GUI', version:'2.3.2', type:'pkg', section:'Networking',
    developer:'OpenVPN', icon:['indigo','lock'], cPrice:0,
    summary:'Tunnel client with an OpenVPN tap driver — the last 10.7-safe build.',
    description:'The OpenVPN project stopped shipping a 32-bit macOS build after 2.3, so this is the last version that runs on a 2009 MacBook. Includes the tun/tap driver and the GUI client, both as a single .pkg so the driver and the app stay version-matched.',
    depends:[], conflicts:['netqos'],
    size:5_767_168, stars:4, rating:386, minOs:'10.7', source:'tcd',
    notes:['A .pkg: it installs the kernel driver as well as the app.','Installs into /Applications and /usr/local.'],
    changelog:[
      ['2.3.2','Dec 4, 2012','Last 32-bit macOS build. Fixes a DNS leak on reconnect.'],
      ['2.3.1','Nov 9, 2012','Windows-only fixes, tagged here for consistency.']
    ] },

  { id:'java8', name:'Java 8 JRE', version:'1.8.0_202', type:'pkg', section:'Developer Tools',
    developer:'Oracle', icon:['red','cube'], cPrice:0,
    summary:'Runtime for legacy Java apps and build tools. The last 32-bit JRE.',
    description:'Anything built against Java 6 or 7 will run on this and nothing newer will. It is the last 32-bit JRE Oracle ever shipped, and it is the one you want if you are running an old Android toolchain, an old Maven, or a 32-bit IDE on a 64-bit system with no other option.',
    depends:[], conflicts:['java6'],
    size:58_720_256, stars:3, rating:512, minOs:'10.7', source:'tcd-legacy',
    notes:['Replaces any existing Java 6. The store warns before it does.','Has a preference pane under Java.'],
    changelog:[
      ['1.8.0_202','Apr 16, 2014','Security updates only. Last Oracle release for 32-bit macOS.'],
      ['1.8.0_45','Apr 15, 2014','Final pre-release. Improved TLS defaults.']
    ] },

  { id:'pixelmator', name:'Pixelmator', version:'3.5.5', type:'app', section:'Graphics',
    developer:'Pixelmator Team', icon:['pink','palette'], cPrice:0,
    summary:'Image editor that runs faster than Photoshop and stays under $30.',
    description:'Pixelmator is a full image editor built on Core Image and Core Graphics, which is why it feels instant on hardware where Photoshop crawls. Layers, masks, curves, healing brush, distortion tools, and a very competent RAW workflow. This is the last version supporting 10.7.',
    depends:[], conflicts:[],
    size:22_544_384, stars:5, rating:987, minOs:'10.7', source:'tcd-legacy',
    notes:['Trial build. The Mac App Store version is expired.','Only version supporting 10.7 — the trial is 30 days per session.']
  },

  { id:'caffeine', name:'Caffeine', version:'1.0.1', type:'app', section:'Utilities',
    developer:'Intellum', icon:['slate','bolt'], cPrice:0,
    summary:'Keeps the Mac awake. One click, no config, tiny.',
    description:'Caffeine clicks a menubar item and the machine stops sleeping. That is the whole feature set, and on an old laptop it is a genuinely useful whole feature set. A timer can turn it off automatically after an hour so you do not come back to a flat battery.',
    depends:[], conflicts:[],
    size:131_072, stars:4, rating:158, minOs:'10.7', source:'tcd-legacy',
    notes:['Runs as a menubar app. 128 KB.'],
    changelog:[ ['1.0.1','May 30, 2013','10.9 compatibility. Fixed a crash when the display is hot-plugged.'] ] },

  { id:'javafix', name:'Legacy Java Bridge Fix', version:'1.2.0', type:'kext', section:'System',
    developer:'TCD Store', icon:['violet','bridge'], cPrice:0,
    summary:'Restores the Java bridge so old App Store apps can talk to newer installers.',
    description:'Applications linked against the old JavaBridge fail to launch on a machine with a newer Java installed, which is a confusing way to discover the problem. This kext restores the bridge symbols. The store flags it as a system-level change and requires an explicit confirmation.',
    depends:[], conflicts:[],
    size:65_536, stars:3, rating:61, minOs:'10.7', source:'tcd',
    notes:['System-level change. The confirmation sheet lists exactly what it modifies.'],
    changelog:[ ['1.2.0','Aug 5, 2013','Rebuilt against the 10.9 SDK, still loads on 10.7.'] ] }
];

PKGS.forEach(function(p,i){
  p.uid        = 'pkg.' + p.id;
  p.installed  = false;
  p.pkgVersion = null;
  p.autoInstalled = false;
  p.stars      = p.stars || 0;
  p.rating     = p.rating || 0;
  p.depends    = p.depends || [];
  p.conflicts  = p.conflicts || [];
  p.notes      = p.notes || [];
  p.changelog  = p.changelog || [];
  p.shots      = p.type === 'app' ? 3 : (p.type === 'pkg' ? 2 : 1);
  p._accent    = ICON_DEFS[p.icon[0]];
  p._glyph     = GLYPHS[p.icon[1]] || GLYPHS.cube;
  p.versions   = buildVersionHistory(p);
});

/* ------------------------------------------------------------------
   Version history.
   A source index can list more than one version of a package, which is
   what the blue-triangle disclosure offers: install a specific version,
   update to a newer one, or roll back to an older one. The real versions
   come from the changelog where there is one; the rest are stepped down
   so every package has something to unfold.
   ------------------------------------------------------------------ */
function buildVersionHistory(p){
  const out = [p.version];
  (p.changelog || []).forEach(function(c){
    if (out.indexOf(c[0]) === -1) out.push(c[0]);
  });
  let guard = 0;
  while (out.length < 4 && guard++ < 20) out.push(stepDownVersion(out[out.length - 1]));
  return out;
}
function stepDownVersion(v){
  const parts = String(v).split('.');
  if (parts.length < 2) return v;
  const last = parts[parts.length - 1];
  const n = parseInt(last, 10);
  parts[parts.length - 1] = String(isNaN(n) ? last : Math.max(0, n - 1));
  return parts.join('.');
}

/* pre-installed state so Installed / Updates aren't empty on first run */
const PREINSTALLED = { 'bettertouchtool':'1.9.9', 'caffeine':'1.0.1' };
Object.keys(PREINSTALLED).forEach(function(id){
  const p = PKGS.filter(function(x){ return x.id === id; })[0];
  if(!p) return;
  p.installed = true;
  p.pkgVersion = PREINSTALLED[id];
  p.hasUpdate  = (PREINSTALLED[id] !== p.version);
});

const SECTIONS = ['Developer Tools','Utilities','System','Graphics','Networking','Video','Graphics'];
const CATEGORIES = [
  { key:'Developer Tools', icon:['graphite','terminal'], blurb:'Editors, build tools, runtimes.' },
  { key:'System',          icon:['graphite','gear'],     blurb:'Kexts, drivers, maintenance.' },
  { key:'Graphics',        icon:['violet','palette'],    blurb:'Drivers and image editors.' },
  { key:'Utilities',       icon:['blue','sliders'],     blurb:'Small tools that earn their keep.' },
  { key:'Networking',      icon:['cyan','globe'],       blurb:'Browsers, transfer, tunnels.' },
  { key:'Video',           icon:['indigo','camera'],     blurb:'Players, encoders, editors.' }
];

/* A source index may offer several versions. Newest first. */
function newestFirst(versions){
  return versions.slice().sort(function(a,b){ return vcmp(b, a); });
}
function relationToInstalled(pkg, version){
  if (!pkg.installed) return 'new';
  const c = vcmp(version, pkg.pkgVersion || '0');
  if (c > 0) return 'update';
  if (c < 0) return 'downgrade';
  return 'reinstall';
}

/* version compare — semver-ish, with the "legacy 1.8.0_202" style handled */
function vcmp(a, b){
  const pa = String(a).split(/[._-]/), pb = String(b).split(/[._-]/);
  const n = Math.max(pa.length, pb.length);
  for (let i = 0; i < n; i++){
    const x = parseInt(pa[i] || '0', 10), y = parseInt(pb[i] || '0', 10);
    if (isNaN(x) || isNaN(y)) { if ((pa[i]||'') === (pb[i]||'')) continue; return (pa[i]||'') > (pb[i]||'') ? 1 : -1; }
    if (x !== y) return x > y ? 1 : -1;
  }
  return 0;
}
