/* ARGUS report renderer (minimal layout).
 * Vanilla JS, no dependencies, no network access.
 * Security: every value from the results data is inserted with textContent / DOM APIs.
 * This file never assigns HTML strings to the DOM. Markdown from check metadata is parsed
 * by a small internal renderer that also builds DOM nodes.
 */
(function () {
  'use strict';

  var STATUS_LABEL = { Passed: 'Passed', Failed: 'Failed', Investigate: 'To review', Error: 'Error', Skipped: 'Skipped', NotRun: 'Not run' };
  var OTHER = ['Error', 'Skipped', 'NotRun'];   // grey; Investigate (To review) is orange
  var SEVERITIES = ['Critical', 'High', 'Medium', 'Low', 'Info'];
  var SEV_RANK = { Critical: 0, High: 1, Medium: 2, Low: 3, Info: 4 };
  var GROUP_RANK = { Failed: 0, Investigate: 1, Error: 2, Skipped: 3, NotRun: 4, Passed: 5 };
  var AREA_ORDER = ['EntraID', 'Applications', 'Licensing', 'GroupsTeams', 'SharePoint', 'Exchange', 'Copilot'];
  var SVG_NS = 'http://www.w3.org/2000/svg';
  var ICONS = {
    printer: ['M7 9V3.5h10V9', 'M5 9h14a2 2 0 0 1 2 2v5h-4M7 16H3v-5a2 2 0 0 1 2-2', 'M7 13.5h10V21H7z'],
    sun: ['C12 12 4', 'M12 2.5v2M12 19.5v2M4.6 4.6l1.4 1.4M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4L6 18M18 6l1.4-1.4'],
    moon: ['M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z'],
    monitor: ['M4 5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z', 'M8.5 20h7M12 16v4'],
    chevron: ['M9 6l6 6-6 6'],
    eye: ['M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z', 'C12 12 3'],
    alert: ['M12 3.5l9 15.5H3z', 'M12 10v4.5', 'M12 17v.01'],
    left: ['M15 6l-6 6 6 6'],
    right: ['M9 6l6 6-6 6'],
    expand: ['M14 4h6v6', 'M20 4l-6.5 6.5', 'M10 20H4v-6', 'M4 20l6.5-6.5'],
    close: ['M6 6l12 12', 'M18 6L6 18']
  };

  var data;
  try {
    data = JSON.parse(document.getElementById('argus-data').textContent);
  } catch (e) {
    document.getElementById('main').textContent = 'The embedded results data could not be read: ' + e.message;
    return;
  }

  var results = Array.isArray(data.Results) ? data.Results : [];
  var score = data.Score || {};
  var run = data.Run || {};
  var tenant = data.Tenant || {};
  var env = data.Environment || {};
  var tool = data.Tool || {};
  var report = data.Report || {};

  // filter: '' | 'Failed' | 'Passed' | 'Review' | 'Other'; sort key: status | id | title | severity
  var state = { search: '', filter: '', area: '', sort: 'status', dir: 1 };
  var checkNodes = {};
  var groupNodes = {};
  var controls = { tabs: [], totals: [], areaCards: [], sortHeads: [] };
  var quiet = false;   // true while opening/closing checks programmatically (print, deep link)

  // ---------------------------------------------------------------- helpers

  function el(tag, props) {
    var node = document.createElement(tag);
    if (props) {
      Object.keys(props).forEach(function (key) {
        var value = props[key];
        if (value === undefined || value === null || value === false) { return; }
        if (key === 'text') { node.textContent = String(value); }
        else if (key === 'class') { node.className = value; }
        else if (key === 'href') { var url = safeUrl(value); if (url) { node.setAttribute('href', url); } }
        else if (key.indexOf('on') === 0 && typeof value === 'function') { node.addEventListener(key.slice(2), value); }
        else { node.setAttribute(key, value === true ? '' : String(value)); }
      });
    }
    for (var i = 2; i < arguments.length; i++) { append(node, arguments[i]); }
    return node;
  }

  function append(parent, child) {
    if (child === null || child === undefined || child === false) { return; }
    if (Array.isArray(child)) { child.forEach(function (c) { append(parent, c); }); return; }
    parent.appendChild(typeof child === 'object' ? child : document.createTextNode(String(child)));
  }

  function svg(tag, attrs) {
    var node = document.createElementNS(SVG_NS, tag);
    Object.keys(attrs || {}).forEach(function (key) {
      if (key === 'text') { node.textContent = String(attrs[key]); } else { node.setAttribute(key, String(attrs[key])); }
    });
    for (var i = 2; i < arguments.length; i++) { if (arguments[i]) { node.appendChild(arguments[i]); } }
    return node;
  }

  function icon(name, size, cls) {
    var node = svg('svg', {
      width: size || 16, height: size || 16, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
      'stroke-width': 1.8, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true', focusable: 'false'
    });
    if (cls) { node.setAttribute('class', cls); }
    (ICONS[name] || []).forEach(function (d) {
      if (d.charAt(0) === 'C') {
        var p = d.slice(1).trim().split(/\s+/);
        node.appendChild(svg('circle', { cx: p[0], cy: p[1], r: p[2] }));
      } else {
        node.appendChild(svg('path', { d: d }));
      }
    });
    return node;
  }

  function safeUrl(value) {
    var url = String(value || '');
    if (/^https:\/\/[^\s]+$/i.test(url)) { return url; }
    if (/^#[\w.\-]+$/.test(url)) { return url; }
    return null;
  }

  function fmtNumber(n) {
    if (n === null || n === undefined || n === '') { return '—'; }
    var num = Number(n);
    return isNaN(num) ? String(n) : num.toLocaleString('en-US');
  }

  function fmtDuration(seconds) {
    var s = Number(seconds) || 0;
    if (s < 60) { return Math.round(s) + ' s'; }
    return Math.floor(s / 60) + ' min ' + Math.round(s % 60) + ' s';
  }

  function fmtTimestamp(iso) {
    if (!iso) { return '—'; }
    var m = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?(Z|[+\-]\d{2}:\d{2})?$/.exec(String(iso));
    if (!m) { return String(iso); }
    return m[1] + ' ' + m[2] + ' (' + (m[3] === 'Z' || !m[3] ? 'UTC' : 'UTC' + m[3]) + ')';
  }

  function cellText(value) {
    if (value === null || value === undefined) { return ''; }
    if (Array.isArray(value)) { return value.map(cellText).join('; '); }
    if (typeof value === 'object') { return JSON.stringify(value); }
    return String(value);
  }

  function kind(status) { return status === 'Passed' ? 'pass' : status === 'Failed' ? 'fail' : status === 'Investigate' ? 'review' : 'other'; }
  function isOther(r) { return OTHER.indexOf(r.Status) >= 0; }

  function badge(status) {
    return el('span', { class: 'badge ' + kind(status), text: STATUS_LABEL[status] || status });
  }

  function counts(list) {
    var c = { total: list.length, Passed: 0, Failed: 0, Investigate: 0, Review: 0, Other: 0 };
    OTHER.forEach(function (s) { c[s] = 0; });
    list.forEach(function (r) {
      c[r.Status] = (c[r.Status] || 0) + 1;
      if (r.Status === 'Investigate') { c.Review++; }
      if (isOther(r)) { c.Other++; }
    });
    return c;
  }

  function areaInfo(area) {
    return (score.Areas || []).filter(function (x) { return x.Area === area; })[0] || {};
  }

  function areaName(area) {
    var a = areaInfo(area);
    if (a.DisplayName) { return a.DisplayName; }
    var r = results.filter(function (x) { return x.Area === area; })[0];
    return (r && r.AreaDisplayName) || area;
  }

  function areaList() {
    var present = {};
    results.forEach(function (r) { present[r.Area] = true; });
    var ordered = AREA_ORDER.filter(function (a) { return present[a]; });
    Object.keys(present).forEach(function (a) { if (ordered.indexOf(a) < 0) { ordered.push(a); } });
    return ordered;
  }

  function resultBar(c, cls) {
    var bar = el('div', { class: cls, role: 'img', 'aria-label': c.Passed + ' passed, ' + c.Failed + ' failed, ' + c.Review + ' to review, ' + c.Other + ' other' });
    if (c.Passed) { bar.appendChild(el('span', { class: 'seg-pass', style: 'flex:' + c.Passed })); }
    if (c.Failed) { bar.appendChild(el('span', { class: 'seg-fail', style: 'flex:' + c.Failed })); }
    if (c.Review) { bar.appendChild(el('span', { class: 'seg-review', style: 'flex:' + c.Review })); }
    if (c.Other) { bar.appendChild(el('span', { class: 'seg-other', style: 'flex:' + c.Other })); }
    return bar;
  }

  function scrollToChecks() {
    document.getElementById('checks').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function copyText(text, button) {
    function done(ok) {
      button.textContent = ok ? 'Copied' : 'Copy failed';
      setTimeout(function () { button.textContent = 'Copy'; }, 1400);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(fallbackCopy(text)); });
    } else {
      done(fallbackCopy(text));
    }
  }

  function fallbackCopy(text) {
    var area = el('textarea', { readonly: true, 'aria-hidden': 'true' });
    area.value = text;
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    document.body.removeChild(area);
    return ok;
  }

  // Text width in CSS pixels for the findings table font (canvas measurement, no layout needed).
  var measureContext = null;
  var measureFamily = null;
  function textWidth(text, bold) {
    if (!measureContext) {
      measureContext = document.createElement('canvas').getContext('2d');
      measureFamily = getComputedStyle(document.body).fontFamily;
    }
    if (!measureContext) { return String(text).length * 7.2; }
    measureContext.font = (bold ? '500 ' : '400 ') + '12.5px ' + measureFamily;
    return measureContext.measureText(String(text)).width;
  }

  function csvValue(value) {
    var text = cellText(value);
    if (/^[=+\-@\t\r]/.test(text)) { text = "'" + text; }   // neutralise spreadsheet formulas
    return '"' + text.replace(/"/g, '""') + '"';
  }

  function downloadCsv(fileName, columns, rows) {
    var lines = [columns.map(csvValue).join(',')];
    rows.forEach(function (row) { lines.push(columns.map(function (c) { return csvValue(row[c]); }).join(',')); });
    var blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var link = el('a', { download: fileName });
    link.href = url;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  // ------------------------------------------------- mini markdown (trusted metadata only)

  function md(text) {
    var root = el('div', { class: 'md' });
    var lines = String(text || '').replace(/\r\n/g, '\n').split('\n');
    var i = 0;
    while (i < lines.length) {
      var line = lines[i];
      if (/^\s*```/.test(line)) {
        var code = [];
        i++;
        while (i < lines.length && !/^\s*```/.test(lines[i])) { code.push(lines[i]); i++; }
        i++;
        root.appendChild(el('pre', null, el('code', { text: code.join('\n') })));
        continue;
      }
      if (/^\s*$/.test(line)) { i++; continue; }
      var ordered = /^\s*\d+[.)]\s+/;
      var bullet = /^\s*[-*]\s+/;
      if (ordered.test(line) || bullet.test(line)) {
        var pattern = ordered.test(line) ? ordered : bullet;
        var list = el(pattern === ordered ? 'ol' : 'ul');
        while (i < lines.length && pattern.test(lines[i])) {
          list.appendChild(inline(el('li'), lines[i].replace(pattern, '')));
          i++;
        }
        root.appendChild(list);
        continue;
      }
      var para = [];
      while (i < lines.length && !/^\s*$/.test(lines[i]) && !ordered.test(lines[i]) && !bullet.test(lines[i]) && !/^\s*```/.test(lines[i])) {
        para.push(lines[i].trim());
        i++;
      }
      root.appendChild(inline(el('p'), para.join(' ')));
    }
    return root;
  }

  function inline(parent, text) {
    String(text).split(/(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)\s]+\))/).forEach(function (token) {
      if (!token) { return; }
      var m;
      if ((m = /^\*\*([^*]+)\*\*$/.exec(token))) { parent.appendChild(el('strong', { text: m[1] })); }
      else if ((m = /^`([^`]+)`$/.exec(token))) { parent.appendChild(el('code', { text: m[1] })); }
      else if ((m = /^\[([^\]]+)\]\(([^)\s]+)\)$/.exec(token)) && safeUrl(m[2])) {
        parent.appendChild(el('a', { href: m[2], text: m[1], target: '_blank', rel: 'noopener noreferrer' }));
      }
      else { parent.appendChild(document.createTextNode(token)); }
    });
    return parent;
  }

  // ---------------------------------------------------------------- theme

  function currentTheme() {
    var stored = null;
    try { stored = window.localStorage.getItem('argus-theme'); } catch (e) { stored = null; }
    return stored === 'light' || stored === 'dark' ? stored : 'auto';
  }

  function applyTheme(theme) {
    if (theme === 'auto') { document.documentElement.removeAttribute('data-theme'); }
    else { document.documentElement.setAttribute('data-theme', theme); }
  }

  function cycleTheme() {
    var next = { auto: 'light', light: 'dark', dark: 'auto' }[currentTheme()];
    try { window.localStorage.setItem('argus-theme', next); } catch (e) { /* storage unavailable */ }
    applyTheme(next);
    updateThemeButton();
  }

  function updateThemeButton() {
    var button = controls.theme;
    var theme = currentTheme();
    while (button.firstChild) { button.removeChild(button.firstChild); }
    button.appendChild(icon({ auto: 'monitor', light: 'sun', dark: 'moon' }[theme], 18));
    button.setAttribute('title', 'Theme: ' + theme);
    button.setAttribute('aria-label', 'Colour theme: ' + theme + '. Select to change.');
  }

  // ---------------------------------------------------------------- header

  function renderHeader() {
    var tenantLabel = tenant.Name || tenant.DefaultDomain || 'Unknown tenant';
    // The title is also the default file name when the report is printed / saved as PDF.
    document.title = 'ARGUS';

    controls.theme = el('button', { type: 'button', class: 'icon-btn', onclick: cycleTheme });
    updateThemeButton();
    document.getElementById('appbar').appendChild(el('div', { class: 'appbar-inner' },
      el('span', { class: 'brand' }, el('span', { class: 'brand-mark' }, icon('eye', 16)), el('span', { class: 'wordmark', text: 'ARGUS' }),
        // Prerelease builds (version with a suffix, e.g. 1.0.0-preview1) are marked as a preview.
        /-/.test(String(tool.Version || '')) ? el('span', { class: 'preview-badge', title: 'ARGUS ' + tool.Version + ' (preview release)', text: 'Preview' }) : null),
      el('span', { class: 'muted', text: 'Governance report' }),
      el('span', { class: 'appbar-spacer' }),
      el('button', { type: 'button', class: 'icon-btn', title: 'Print or save as PDF', 'aria-label': 'Print or save as PDF', onclick: function () { window.print(); } }, icon('printer', 18)),
      controls.theme));

    var meta = el('div', { class: 'meta' },
      tenant.DefaultDomain ? el('span', { text: tenant.DefaultDomain }) : null,
      el('span', { text: fmtTimestamp(run.StartedAt) }),
      run.Account ? el('span', { text: run.Account }) : null,
      report.CompanyName ? el('span', { text: 'Prepared by ' + report.CompanyName }) : null);

    var logo = null;
    if (typeof report.LogoDataUri === 'string' && /^data:image\/(png|jpeg|gif|svg\+xml);base64,[A-Za-z0-9+\/=]+$/.test(report.LogoDataUri)) {
      logo = el('img', { class: 'logo', alt: report.CompanyName ? report.CompanyName + ' logo' : 'Logo' });
      logo.src = report.LogoDataUri;
    }
    append(document.getElementById('hero'), [el('h1', { text: tenantLabel }), meta, logo]);
  }

  function renderNotes() {
    if (env.ConcealedReportNames === true) {
      document.getElementById('notes').appendChild(el('div', { class: 'warn', role: 'note' }, icon('alert', 18),
        el('div', null, el('strong', { text: 'Usage reports return concealed names' }),
          'Usage reports hide user, group and site names in this tenant, so checks based on them are marked To review. ' +
          'Turn off the setting in Microsoft 365 admin center › Settings › Org settings › Reports, then run ARGUS again.')));
    }
  }

  // ---------------------------------------------------------------- overview (iris)

  // Every check is one tick around the iris, grouped by area; tick colour = status,
  // tick length = severity. The pupil holds the score; the inner ring is the score arc.
  var TICK_LENGTH = { Critical: 50, High: 43, Medium: 36, Low: 29, Info: 22 };
  var IRIS = { cx: 360, cy: 280, tick: 158, label: 242, ring: 128, fibreIn: 94, fibreOut: 120, pupil: 88 };
  var IRIS_AREA = { EntraID: 'Entra ID', Applications: 'Applications', Licensing: 'Licensing', GroupsTeams: 'Groups & Teams', SharePoint: 'SharePoint', Exchange: 'Exchange', Copilot: 'Copilot' };
  var VERDICT = {
    A: 'Governance is in good shape',
    B: 'Governance is solid, with a few gaps',
    C: 'Governance needs targeted work',
    D: 'Governance needs attention',
    F: 'Governance needs urgent attention'
  };

  function polar(radius, deg) {
    var rad = (deg - 90) * Math.PI / 180;
    return { x: IRIS.cx + radius * Math.cos(rad), y: IRIS.cy + radius * Math.sin(rad) };
  }

  function arcPath(radius, from, to) {
    var a = polar(radius, from);
    var b = polar(radius, to);
    var large = to - from > 180 ? 1 : 0;
    return 'M' + a.x.toFixed(2) + ' ' + a.y.toFixed(2) + ' A' + radius + ' ' + radius + ' 0 ' + large + ' 1 ' + b.x.toFixed(2) + ' ' + b.y.toFixed(2);
  }

  function sectorPath(inner, outer, from, to) {
    var a = polar(outer, from);
    var b = polar(outer, to);
    var c = polar(inner, to);
    var d = polar(inner, from);
    var large = to - from > 180 ? 1 : 0;
    return 'M' + a.x.toFixed(2) + ' ' + a.y.toFixed(2) + ' A' + outer + ' ' + outer + ' 0 ' + large + ' 1 ' + b.x.toFixed(2) + ' ' + b.y.toFixed(2) +
      ' L' + c.x.toFixed(2) + ' ' + c.y.toFixed(2) + ' A' + inner + ' ' + inner + ' 0 ' + large + ' 0 ' + d.x.toFixed(2) + ' ' + d.y.toFixed(2) + ' Z';
  }

  function revealCheck(id) {
    state.filter = '';
    state.area = '';
    state.search = '';
    applyFilters();
    openCheck(id);
  }

  function filterArea(area) {
    state.area = state.area === area ? '' : area;
    applyFilters();
    if (state.area) { scrollToChecks(); }
  }

  function renderIris() {
    var areas = areaList();
    var total = results.length;
    var value = typeof score.Score === 'number' ? score.Score : null;
    var chart = svg('svg', {
      class: 'iris', viewBox: '0 0 720 560', role: 'img',
      'aria-label': 'Governance score ' + (value === null ? 'not available' : value + '%') + '. ' + total + ' checks around the ring, grouped by area and coloured by status.'
    });

    // Iris texture: fine radial fibres between pupil and score ring (decorative).
    var fibres = svg('g', { class: 'iris-fibres', 'aria-hidden': 'true' });
    for (var f = 0; f < 144; f++) {
      var deg = f * 2.5;
      var inner = polar(IRIS.fibreIn + (f % 3) * 2, deg);
      var outer = polar(IRIS.fibreOut - (f % 4) * 3, deg + 1.2);
      fibres.appendChild(svg('line', { x1: inner.x.toFixed(2), y1: inner.y.toFixed(2), x2: outer.x.toFixed(2), y2: outer.y.toFixed(2) }));
    }
    chart.appendChild(fibres);

    // Score ring: track + arc proportional to the score.
    chart.appendChild(svg('circle', { class: 'iris-track', cx: IRIS.cx, cy: IRIS.cy, r: IRIS.ring }));
    if (value !== null && value > 0) {
      var end = Math.min(value, 99.95) * 3.6;
      chart.appendChild(svg('path', { class: 'iris-score', d: arcPath(IRIS.ring, 0, end) }));
    }

    // Pupil with the score.
    chart.appendChild(svg('circle', { class: 'iris-pupil', cx: IRIS.cx, cy: IRIS.cy, r: IRIS.pupil }));
    chart.appendChild(svg('text', { class: 'iris-caption', x: IRIS.cx, y: IRIS.cy - 42, 'text-anchor': 'middle', text: 'SCORE' }));
    chart.appendChild(svg('text', { class: 'iris-value', x: IRIS.cx, y: IRIS.cy + 4, 'text-anchor': 'middle', 'dominant-baseline': 'central' },
      svg('tspan', { text: value === null ? '—' : value }),
      value === null ? null : svg('tspan', { class: 'iris-pct', dx: 2, text: '%' })));
    chart.appendChild(svg('text', { class: 'iris-grade', x: IRIS.cx, y: IRIS.cy + 50, 'text-anchor': 'middle', text: score.Grade ? 'GRADE ' + score.Grade : 'NO SCORE' }));

    // Ticks, one per check, grouped by area with a gap between areas.
    var gap = areas.length > 1 ? 6 : 0;
    var step = total ? (360 - gap * areas.length) / total : 0;
    // Each check is an annular segment (an iris blade); a small gap keeps segments distinct.
    var blade = Math.min(step * 0.18, 1.4);
    var angle = gap / 2;
    var index = 0;
    areas.forEach(function (area) {
      var list = results.filter(function (r) { return r.Area === area; })
        .sort(function (a, b) { return (GROUP_RANK[a.Status] - GROUP_RANK[b.Status]) || (a.Id < b.Id ? -1 : 1); });
      var from = angle;
      var group = svg('g', { class: 'iris-area' });
      list.forEach(function (r) {
        var mid = angle + step / 2;
        var tick = svg('path', {
          class: 'iris-tick s-' + kind(r.Status), d: sectorPath(IRIS.tick, IRIS.tick + (TICK_LENGTH[r.Severity] || 26), mid - step / 2 + blade / 2, mid + step / 2 - blade / 2),
          style: 'animation-delay:' + Math.min(index * 14, 700) + 'ms'
        }, svg('title', { text: r.Id + ' · ' + r.Title + ' · ' + (STATUS_LABEL[r.Status] || r.Status) + ' · ' + r.Severity }));
        tick.addEventListener('click', function () { revealCheck(r.Id); });
        group.appendChild(tick);
        angle += step;
        index++;
      });
      var to = angle;
      angle += gap;

      // Area arc + label outside the ticks; click filters the check list.
      var midAngle = (from + to) / 2;
      var pos = polar(IRIS.label, midAngle);
      // Upper-half labels grow downwards, towards the area arc: lift them by up to one line.
      pos.y -= Math.max(0, Math.cos(midAngle * Math.PI / 180)) * 20;
      var anchor = midAngle < 15 || midAngle > 345 || (midAngle > 165 && midAngle < 195) ? 'middle' : midAngle < 180 ? 'start' : 'end';
      var a = areaInfo(area);
      var label = svg('g', { class: 'iris-label', tabindex: '0', role: 'button', 'aria-label': 'Show only ' + areaName(area) + ' checks' },
        svg('path', { class: 'iris-arc', d: arcPath(IRIS.tick + 62, from, Math.max(from + 0.5, to)) }),
        svg('text', { class: 'iris-label-name', x: pos.x.toFixed(2), y: pos.y.toFixed(2), 'text-anchor': anchor, 'dominant-baseline': 'central', text: IRIS_AREA[area] || areaName(area) }),
        svg('text', { class: 'iris-label-score', x: pos.x.toFixed(2), y: (pos.y + 18).toFixed(2), 'text-anchor': anchor, 'dominant-baseline': 'central', text: typeof a.Score === 'number' ? a.Score + '% · ' + a.Grade : '—' }));
      label.addEventListener('click', function () { filterArea(area); });
      label.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); filterArea(area); } });
      group.appendChild(label);
      chart.appendChild(group);
    });

    var legend = el('ul', { class: 'iris-legend' },
      el('li', null, el('span', { class: 'key pass' }), 'Passed'),
      el('li', null, el('span', { class: 'key fail' }), 'Failed'),
      el('li', null, el('span', { class: 'key review' }), 'To review'),
      el('li', null, el('span', { class: 'key other' }), 'Other'),
      el('li', { class: 'muted' }, 'Tick length = severity'));
    return el('div', { class: 'iris-wrap' }, chart, legend);
  }

  // Grade bands as in Get-ArgusScore: A >= 90, B >= 75, C >= 60, D >= 40, F < 40.
  var GRADE_BANDS = [['F', 0, 40], ['D', 40, 60], ['C', 60, 75], ['B', 75, 90], ['A', 90, 100]];

  // Score spectrum (red -> orange -> yellow -> green) per theme: one source for the grade scale gradient,
  // the gradient of the score number and the iris arc. Positions follow the grade thresholds.
  var SPECTRUM = {
    light: [[0, '#dc2626'], [40, '#ea580c'], [60, '#ca8a04'], [75, '#65a30d'], [90, '#16a34a'], [100, '#15803d']],
    dark: [[0, '#f87171'], [40, '#fb923c'], [60, '#facc15'], [75, '#a3e635'], [90, '#4ade80'], [100, '#4ade80']]
  };

  function spectrumAt(stops, value) {
    var v = Math.max(0, Math.min(100, value));
    for (var i = 1; i < stops.length; i++) {
      if (v <= stops[i][0]) {
        var t = (v - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]);
        var a = stops[i - 1][1];
        var b = stops[i][1];
        var mix = [1, 3, 5].map(function (k) {
          var x = parseInt(a.substr(k, 2), 16);
          var y = parseInt(b.substr(k, 2), 16);
          return ('0' + Math.round(x + (y - x) * t).toString(16)).slice(-2);
        });
        return '#' + mix.join('');
      }
    }
    return stops[stops.length - 1][1];
  }

  // CSS variables for both themes; the stylesheet picks the set of the active theme.
  function scoreColorVars(value) {
    var vars = [];
    Object.keys(SPECTRUM).forEach(function (mode) {
      var stops = SPECTRUM[mode];
      vars.push('--spectrum-' + mode + ':linear-gradient(90deg,' + stops.map(function (s) { return s[1] + ' ' + s[0] + '%'; }).join(',') + ')');
      if (value !== null) {
        // The number shows the stretch of the spectrum that leads to the score.
        vars.push('--score-from-' + mode + ':' + spectrumAt(stops, value - 25));
        vars.push('--score-to-' + mode + ':' + spectrumAt(stops, value));
      }
    });
    return vars.join(';');
  }

  // Headline score: the percentage, its grade and where it sits on the grade scale.
  function renderScore(value) {
    var points = typeof score.EvaluatedWeight === 'number' && score.EvaluatedWeight > 0
      ? fmtNumber(score.EarnedWeight) + ' of ' + fmtNumber(score.EvaluatedWeight) + ' weighted points earned'
      : 'No weighted check was evaluated';
    var bands = el('div', { class: 'scale-track' });
    var labels = el('div', { class: 'scale-labels', 'aria-hidden': 'true' });
    GRADE_BANDS.forEach(function (b) {
      var fill = value === null ? 0 : Math.max(0, Math.min(1, (value - b[1]) / (b[2] - b[1])));
      var current = score.Grade === b[0] ? ' current' : '';
      // Each band shows its own stretch of one continuous spectrum; the part above the score is veiled.
      var width = b[2] - b[1];
      var spectrum = 'background-size:' + (10000 / width).toFixed(2) + '% 100%;background-position:' + (100 * b[1] / (100 - width)).toFixed(2) + '% 0';
      bands.appendChild(el('span', { class: 'scale-band' + current, style: 'flex:' + width + ';' + spectrum },
        el('span', { class: 'scale-rest', style: 'left:' + (fill * 100).toFixed(1) + '%' })));
      labels.appendChild(el('span', { class: 'scale-label' + current, style: 'flex:' + (b[2] - b[1]) },
        b[0], b[1] ? el('span', { class: 'scale-num', text: b[1] + '+' }) : null));
    });
    var scale = el('div', {
      class: 'scale', role: 'img',
      'aria-label': value === null ? 'Grade scale: no score' : 'Score ' + value + '% on a grade scale from F (below 40) to A (90 and above)'
    }, bands, labels);
    if (value !== null) {
      scale.appendChild(el('span', { class: 'scale-marker', style: 'left:' + Math.max(0, Math.min(100, value)) + '%' }));
    }
    return el('div', { class: 'score-block' },
      el('div', { class: 'eyebrow', text: 'Governance score' }),
      el('div', { class: 'score-row' },
        el('div', { class: 'score-big' }, el('b', { text: value === null ? '—' : value }), value === null ? null : el('span', { text: '%' })),
        el('div', { class: 'score-side' },
          el('span', { class: 'grade-pill', text: score.Grade ? 'Grade ' + score.Grade : 'No grade' }),
          el('span', { class: 'score-points', text: points }))),
      scale);
  }

  function priorities() {
    return results.filter(function (r) { return r.Status === 'Failed'; })
      .sort(function (a, b) { return (SEV_RANK[a.Severity] - SEV_RANK[b.Severity]) || ((b.AffectedCount || 0) - (a.AffectedCount || 0)) || (a.Id < b.Id ? -1 : 1); })
      .slice(0, 5);
  }

  function renderBrief() {
    var c = counts(results);
    var value = typeof score.Score === 'number' ? score.Score : null;
    var failed = results.filter(function (r) { return r.Status === 'Failed'; });
    var serious = failed.filter(function (r) { return r.Severity === 'Critical' || r.Severity === 'High'; }).length;

    var headline = value === null ? 'Not enough checks could be evaluated' : (VERDICT[score.Grade] || 'Governance assessment');
    var sentence = failed.length
      ? failed.length + (failed.length === 1 ? ' check failed' : ' checks failed') + (serious ? ', ' + serious + ' of them high or critical severity.' : '.')
      : 'No check failed.';
    if (c.Review) { sentence += ' ' + c.Review + (c.Review === 1 ? ' check needs' : ' checks need') + ' review.'; }
    sentence += ' Coverage ' + fmtNumber(score.Coverage) + '% of ' + fmtNumber(results.length) + ' checks.';

    function total(key, label, cls) {
      var button = el('button', {
        type: 'button', class: 'total ' + cls, 'aria-pressed': 'false', title: 'Show ' + label.toLowerCase() + ' checks',
        onclick: function () { state.filter = state.filter === key ? '' : key; applyFilters(); scrollToChecks(); }
      }, el('b', { text: fmtNumber(c[key]) }), el('span', { text: label }));
      button.dataset.filter = key;
      controls.totals.push(button);
      return button;
    }
    var otherParts = OTHER.filter(function (s) { return c[s]; }).map(function (s) { return c[s] + ' ' + STATUS_LABEL[s].toLowerCase(); });

    var top = priorities();
    var list = top.length
      ? el('ol', { class: 'priorities' }, top.map(function (r, i) {
        return el('li', null, el('button', { type: 'button', class: 'priority', onclick: function () { revealCheck(r.Id); } },
          el('span', { class: 'p-rank', text: String(i + 1).padStart(2, '0') }),
          el('span', { class: 'p-body' },
            el('span', { class: 'p-title', text: r.Title }),
            el('span', { class: 'p-meta', text: areaName(r.Area) + ' · ' + r.Severity + ' · ' + r.Id })),
          el('span', { class: 'p-count', text: r.AffectedCount > 0 ? fmtNumber(r.AffectedCount) : '' })));
      }))
      : el('p', { class: 'muted', text: 'Nothing to fix: no check failed.' });

    var bySeverity = el('div', { class: 'sev-strip', role: 'list', 'aria-label': 'Failed checks by severity' },
      SEVERITIES.map(function (s) {
        var n = failed.filter(function (r) { return r.Severity === s; }).length;
        return el('div', { class: 'sev-cell' + (n ? ' has' : ''), role: 'listitem' }, el('b', { text: n }), el('span', { text: s }));
      }));

    // Head band: score + assessment across the card; below, the iris beside the brief.
    var head = el('div', { class: 'overview-head' },
      renderScore(value),
      el('div', { class: 'assessment' },
        el('div', { class: 'eyebrow', text: 'Assessment' }),
        el('h2', { class: 'verdict', text: headline }),
        el('p', { class: 'verdict-sub', text: sentence }),
        score.IsPartial ? el('p', { class: 'partial', text: 'Partial result: not enough checks could be evaluated for a reliable score.' }) : null));
    var brief = el('div', { class: 'brief' },
      el('div', { class: 'eyebrow', text: 'Results' }),
      el('div', { class: 'totals' }, total('Passed', 'Passed', 'pass'), total('Failed', 'Failed', 'fail'), total('Review', 'To review', 'review'), total('Other', 'Other', 'other')),
      otherParts.length ? el('div', { class: 'other-detail', text: 'Other: ' + otherParts.join(', ') + '.' }) : null,
      el('div', { class: 'eyebrow spaced', text: 'Failed by severity' }),
      bySeverity,
      el('div', { class: 'eyebrow spaced', text: 'Priorities' }),
      list);
    return { head: head, brief: brief };
  }

  function renderOverview() {
    var host = document.getElementById('overview');
    host.setAttribute('style', scoreColorVars(typeof score.Score === 'number' ? score.Score : null));
    if (typeof score.Score === 'number') { host.classList.add('has-score'); }
    var parts = renderBrief();
    host.appendChild(parts.head);
    host.appendChild(el('div', { class: 'overview-body' }, renderIris(), parts.brief));
  }

  // ---------------------------------------------------------------- areas

  function renderAreas() {
    var host = document.getElementById('areas');
    areaList().forEach(function (area) {
      var c = counts(results.filter(function (r) { return r.Area === area; }));
      var a = areaInfo(area);
      var card = el('button', {
        type: 'button', class: 'card area-card', 'aria-pressed': 'false', title: 'Show only ' + areaName(area) + ' checks',
        onclick: function () { state.area = state.area === area ? '' : area; applyFilters(); if (state.area) { scrollToChecks(); } }
      },
      el('div', { class: 'area-top' },
        el('span', { class: 'area-name', text: areaName(area) }),
        el('span', { class: 'area-score' }, el('b', { text: typeof a.Score === 'number' ? a.Score : '—' }), el('span', { text: typeof a.Score === 'number' ? 'Grade ' + a.Grade : 'no score' }))),
      resultBar(c, 'stack'),
      el('div', { class: 'area-counts' },
        el('span', null, el('b', { class: 'c-pass', text: c.Passed }), ' passed'),
        el('span', null, el('b', { class: 'c-fail', text: c.Failed }), ' failed'),
        c.Review ? el('span', null, el('b', { class: 'c-review', text: c.Review }), ' to review') : null,
        c.Other ? el('span', null, el('b', { text: c.Other }), ' other') : null));
      card.dataset.area = area;
      controls.areaCards.push(card);
      host.appendChild(card);
    });
    host.appendChild(renderScoreLoss(areaList().length));
  }

  // Where the score is lost: weighted points not earned per area (evaluated - earned), largest first,
  // drawn as one neutral line. The card fills the rest of the last grid row (see .area-loss in the CSS);
  // the expand button opens a larger chart with a detail table.
  var lossChartCount = 0;   // unique gradient ids (card chart and zoom chart)
  // Colour bands of "Where the score is lost" in weighted points lost (a failed High check = 5 points):
  // above 15 red, above 10 orange, above 5 yellow, 5 or less yellow-green.
  var LOSS_BANDS = [
    { above: 15, color: '--loss-high' },
    { above: 10, color: '--loss-mid' },
    { above: 5, color: '--loss-low' },
    { above: -1, color: '--loss-min' }
  ];

  function scoreLossData() {
    var rows = areaList().map(function (area) {
      var a = areaInfo(area);
      var lost = Math.max(0, (a.EvaluatedWeight || 0) - (a.EarnedWeight || 0));
      return { area: area, info: a, lost: Math.round(lost * 10) / 10 };
    }).filter(function (r) { return r.lost > 0; })
      .sort(function (x, y) { return (y.lost - x.lost) || (AREA_ORDER.indexOf(x.area) - AREA_ORDER.indexOf(y.area)); });
    var total = rows.reduce(function (sum, r) { return sum + r.lost; }, 0);
    var running = 0;
    rows.forEach(function (r) {
      running += r.lost;
      r.share = total ? Math.round(100 * r.lost / total) : 0;
      r.cumulative = total ? Math.round(100 * running / total) : 0;
    });
    return { rows: rows, total: Math.round(total * 10) / 10 };
  }

  // Draws the line once the chart is on screen (immediately without IntersectionObserver or with reduced motion).
  function drawWhenVisible(node) {
    var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced || typeof IntersectionObserver === 'undefined') { node.classList.add('is-drawn'); return; }
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { node.classList.add('is-drawn'); observer.disconnect(); }
      });
    }, { threshold: 0.35 });
    observer.observe(node);
  }

  // Line chart of points lost per area. size: { w, h, large }. onSelect(area) runs on click.
  function lossChart(rows, size, onSelect) {
    var w = size.w;
    var h = size.h;
    var pad = size.large ? { l: 44, r: 24, t: 28, b: 40 } : { l: 18, r: 18, t: 24, b: 30 };
    var n = rows.length;
    var max = rows[0].lost;
    var x = function (i) { return n === 1 ? w / 2 : pad.l + i * (w - pad.l - pad.r) / (n - 1); };
    var y = function (v) { return pad.t + (1 - v / max) * (h - pad.t - pad.b); };
    var base = y(0);

    var chart = svg('svg', {
      class: 'loss-svg', viewBox: '0 0 ' + w + ' ' + h, role: 'img',
      'aria-label': 'Weighted points lost by area, largest first: ' + rows.map(function (r) { return areaName(r.area) + ' ' + r.lost; }).join(', ') + '.'
    });

    // Colour follows the weighted points lost (LOSS_BANDS, highest first), with a short blend at each
    // threshold. The vertical gradient runs from the top value down to zero.
    var gradientId = 'loss-gradient-' + (++lossChartCount);
    var offsetOf = function (points) { return Math.max(0, Math.min(1, (y(points) - y(max)) / (base - y(max) || 1))); };
    var blend = 0.01;
    var gradient = svg('linearGradient', { id: gradientId, gradientUnits: 'userSpaceOnUse', x1: 0, x2: 0, y1: y(max).toFixed(1), y2: base.toFixed(1) });
    var addStop = function (offset, color) { gradient.appendChild(svg('stop', { offset: offset.toFixed(4), style: 'stop-color:var(' + color + ')' })); };
    addStop(0, LOSS_BANDS[0].color);
    for (var b = 1; b < LOSS_BANDS.length; b++) {
      var at = offsetOf(LOSS_BANDS[b - 1].above);
      addStop(Math.max(0, at - blend), LOSS_BANDS[b - 1].color);
      addStop(Math.min(1, at + blend), LOSS_BANDS[b].color);
    }
    addStop(1, LOSS_BANDS[LOSS_BANDS.length - 1].color);
    chart.appendChild(svg('defs', null, gradient));
    // Dots take the exact colour of their band (no blend), so a point next to a threshold is never mixed.
    var bandColor = function (lost) {
      for (var k = 0; k < LOSS_BANDS.length; k++) {
        if (lost > LOSS_BANDS[k].above) { return 'var(' + LOSS_BANDS[k].color + ')'; }
      }
      return 'var(' + LOSS_BANDS[LOSS_BANDS.length - 1].color + ')';
    };
    var paint = 'url(#' + gradientId + ')';

    // Recessive grid: baseline, plus half and max lines with values in the large view.
    var ticks = size.large ? [0, max / 2, max] : [0];
    ticks.forEach(function (t) {
      chart.appendChild(svg('line', { class: t === 0 ? 'loss-axis' : 'loss-grid', x1: pad.l, x2: w - pad.r, y1: y(t).toFixed(1), y2: y(t).toFixed(1) }));
      if (size.large) {
        chart.appendChild(svg('text', { class: 'loss-tick', x: pad.l - 10, y: y(t).toFixed(1), 'text-anchor': 'end', 'dominant-baseline': 'central', text: fmtNumber(Math.round(t * 10) / 10) }));
      }
    });

    var points = rows.map(function (r, i) { return x(i).toFixed(1) + ' ' + y(r.lost).toFixed(1); });
    chart.appendChild(svg('path', { class: 'loss-area', style: 'fill:' + paint, d: 'M' + x(0).toFixed(1) + ' ' + base.toFixed(1) + ' L' + points.join(' L') + ' L' + x(n - 1).toFixed(1) + ' ' + base.toFixed(1) + ' Z' }));
    chart.appendChild(svg('path', { class: 'loss-line', style: 'stroke:' + paint, pathLength: 1, d: 'M' + points.join(' L') }));
    var guide = svg('line', { class: 'loss-guide', x1: 0, x2: 0, y1: pad.t - 8, y2: base });
    chart.appendChild(guide);

    var dots = rows.map(function (r, i) {
      var dot = svg('circle', { class: 'loss-dot' + (i === 0 ? ' is-max' : ''), cx: x(i).toFixed(1), cy: y(r.lost).toFixed(1), r: size.large ? 5 : 4, style: 'stroke:' + bandColor(r.lost) + (i === 0 ? ';fill:' + bandColor(r.lost) : '') + ';transition-delay:' + (300 + i * 70) + 'ms' });
      chart.appendChild(dot);
      var anchor = n > 1 && i === 0 ? 'start' : n > 1 && i === n - 1 ? 'end' : 'middle';
      var label = IRIS_AREA[r.area] || areaName(r.area);
      chart.appendChild(svg('text', { class: 'loss-xlabel', x: x(i).toFixed(1), y: h - pad.b + (size.large ? 24 : 20), 'text-anchor': anchor, text: label }));
      return dot;
    });
    // Selective direct label: only the largest loss carries its value.
    chart.appendChild(svg('text', { class: 'loss-maxlabel', x: (x(0) + (n > 1 ? 8 : 0)).toFixed(1), y: (y(rows[0].lost) - 10).toFixed(1), 'text-anchor': n > 1 ? 'start' : 'middle', text: fmtNumber(rows[0].lost) + ' pts' }));

    var tip = el('div', { class: 'loss-tip', role: 'status', 'aria-live': 'polite' });
    var wrap = el('div', { class: 'loss-chart' + (size.large ? ' is-large' : '') }, chart, tip);

    // Hover layer: one hit column per point, wider than the mark.
    var step = n > 1 ? (w - pad.l - pad.r) / (n - 1) : w;
    rows.forEach(function (r, i) {
      var hit = svg('rect', { class: 'loss-hit', x: (x(i) - step / 2).toFixed(1), y: 0, width: step.toFixed(1), height: h });
      hit.addEventListener('mouseenter', function () {
        guide.setAttribute('x1', x(i).toFixed(1));
        guide.setAttribute('x2', x(i).toFixed(1));
        wrap.classList.add('is-hover');
        dots.forEach(function (d, k) { d.classList.toggle('is-active', k === i); });
        while (tip.firstChild) { tip.removeChild(tip.firstChild); }
        tip.appendChild(el('b', { text: areaName(r.area) }));
        tip.appendChild(el('span', { text: fmtNumber(r.lost) + ' points lost · ' + r.share + '% of the loss' }));
        tip.appendChild(el('span', { class: 'muted', text: typeof r.info.Score === 'number' ? 'Area score ' + r.info.Score + '% · Grade ' + r.info.Grade : 'No area score' }));
        tip.style.left = (100 * x(i) / w).toFixed(2) + '%';
        tip.style.top = (100 * y(r.lost) / h).toFixed(2) + '%';
        tip.dataset.edge = i === 0 && n > 1 ? 'start' : i === n - 1 && n > 1 ? 'end' : '';
      });
      hit.addEventListener('mouseleave', function () {
        wrap.classList.remove('is-hover');
        dots.forEach(function (d) { d.classList.remove('is-active'); });
      });
      hit.addEventListener('click', function () { onSelect(r.area); });
      chart.appendChild(hit);
    });
    return wrap;
  }

  function renderScoreLoss(areaCount) {
    var loss = scoreLossData();
    var card = el('div', {
      class: 'card area-loss',
      style: '--span3:' + (areaCount % 3 ? 3 - areaCount % 3 : 3) + ';--span2:' + (areaCount % 2 ? 1 : 2)
    });
    var expand = loss.rows.length ? el('button', {
      type: 'button', class: 'icon-btn loss-expand no-print', title: 'Expand', 'aria-label': 'Open the detailed view of where the score is lost',
      onclick: function () { openScoreLoss(loss, expand); }
    }, icon('expand', 16)) : null;
    card.appendChild(el('div', { class: 'area-top' },
      el('span', { class: 'area-name', text: 'Where the score is lost' }),
      el('span', { class: 'loss-head' },
        el('span', { class: 'muted loss-total', text: loss.total ? fmtNumber(loss.total) + ' of ' + fmtNumber(score.EvaluatedWeight) + ' weighted points' : '' }),
        expand)));

    if (!loss.rows.length) {
      card.appendChild(el('p', { class: 'muted', text: 'Nothing lost: every evaluated check passed.' }));
      return card;
    }
    var chart = lossChart(loss.rows, { w: 840, h: 116 }, filterArea);
    card.appendChild(chart);
    drawWhenVisible(chart);
    return card;
  }

  // Detailed view: larger chart and a table with every figure (also the accessible view of the chart).
  function openScoreLoss(loss, opener) {
    var weights = score.Weights || {};
    var how = 'Each check weighs by severity (Critical ' + (weights.Critical || 0) + ', High ' + (weights.High || 0) + ', Medium ' + (weights.Medium || 0) + ', Low ' + (weights.Low || 0) +
      '); Passed earns its weight, To review ' + Math.round(100 * (typeof score.InvestigateCredit === 'number' ? score.InvestigateCredit : 0.5)) + '%, Failed nothing.';
    var dialog = el('dialog', { class: 'loss-dialog', 'aria-labelledby': 'loss-dialog-title' });
    // Content sits in an inner box so a click on the backdrop (target = dialog) can close it.
    var body = el('div', { class: 'loss-dialog-body' });
    dialog.appendChild(body);
    var select = function (area) { dialog.close(); filterArea(area); };

    var table = el('table', { class: 'loss-table' },
      el('thead', null, el('tr', null, ['Area', 'Score', 'Points earned', 'Points lost', 'Share of loss', 'Cumulative', 'Failed checks'].map(function (t, i) {
        return el('th', { scope: 'col', class: i ? 'num' : '', text: t });
      }))),
      el('tbody', null, loss.rows.map(function (r) {
        var failed = results.filter(function (c) { return c.Area === r.area && c.Status === 'Failed'; }).length;
        return el('tr', null,
          el('td', null, el('button', { type: 'button', class: 'text-btn loss-link', title: 'Show only ' + areaName(r.area) + ' checks', onclick: function () { select(r.area); }, text: areaName(r.area) })),
          el('td', { class: 'num', text: typeof r.info.Score === 'number' ? r.info.Score + '% · ' + r.info.Grade : '—' }),
          el('td', { class: 'num', text: fmtNumber(r.info.EarnedWeight || 0) + ' / ' + fmtNumber(r.info.EvaluatedWeight || 0) }),
          el('td', { class: 'num strong', text: fmtNumber(r.lost) }),
          el('td', { class: 'num', text: r.share + '%' }),
          el('td', { class: 'num', text: r.cumulative + '%' }),
          el('td', { class: 'num', text: failed }));
      })));

    var chart = lossChart(loss.rows, { w: 820, h: 165, large: true }, select);
    body.appendChild(el('div', { class: 'loss-dialog-head' },
      el('div', null,
        el('div', { class: 'eyebrow', text: 'Score analysis' }),
        el('h2', { id: 'loss-dialog-title', text: 'Where the score is lost' }),
        el('p', { class: 'muted', text: fmtNumber(loss.total) + ' of ' + fmtNumber(score.EvaluatedWeight) + ' weighted points are not earned. ' + how })),
      el('button', { type: 'button', class: 'icon-btn', title: 'Close', 'aria-label': 'Close', onclick: function () { dialog.close(); } }, icon('close', 18))));
    body.appendChild(chart);
    body.appendChild(el('div', { class: 'loss-table-wrap' }, table));
    dialog.addEventListener('click', function (e) { if (e.target === dialog) { dialog.close(); } });
    dialog.addEventListener('close', function () {
      if (dialog.parentNode) { dialog.parentNode.removeChild(dialog); }
      if (opener && opener.focus) { opener.focus(); }
    });
    document.body.appendChild(dialog);
    dialog.showModal();
    // Draw after the dialog is painted so the line animates in.
    var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced) { chart.classList.add('is-drawn'); }
    else { window.requestAnimationFrame(function () { window.requestAnimationFrame(function () { chart.classList.add('is-drawn'); }); }); }
  }

  // ---------------------------------------------------------------- toolbar + groups

  function renderToolbar() {
    var c = counts(results);
    var tabs = el('div', { class: 'tabs', role: 'group', 'aria-label': 'Filter checks' });
    [['', 'All', c.total], ['Failed', 'Failed', c.Failed], ['Passed', 'Passed', c.Passed], ['Review', 'To review', c.Review], ['Other', 'Other', c.Other]].forEach(function (t) {
      var b = el('button', { type: 'button', class: 'tab', 'aria-pressed': 'false', onclick: function () { state.filter = t[0]; applyFilters(); } },
        t[1], el('span', { class: 'n', text: t[2] }));
      b.dataset.filter = t[0];
      controls.tabs.push(b);
      tabs.appendChild(b);
    });
    controls.search = el('input', { type: 'search', placeholder: 'Search checks', 'aria-label': 'Search checks' });
    controls.search.addEventListener('input', function () { state.search = controls.search.value.trim().toLowerCase(); applyFilters(); });
    controls.areaReset = el('button', { type: 'button', class: 'text-btn', hidden: true, onclick: function () { state.area = ''; applyFilters(); } });
    append(document.getElementById('toolbar'), [tabs, el('div', { class: 'toolbar-end' }, controls.areaReset, controls.search)]);
  }

  function matches(r) {
    if (state.filter === 'Other' && !isOther(r)) { return false; }
    if (state.filter === 'Review' && r.Status !== 'Investigate') { return false; }
    if ((state.filter === 'Passed' || state.filter === 'Failed') && r.Status !== state.filter) { return false; }
    if (state.area && r.Area !== state.area) { return false; }
    if (state.search) {
      var hay = [r.Id, r.Title, r.Summary, r.Category, (r.Tags || []).join(' ')].join(' ').toLowerCase();
      if (hay.indexOf(state.search) < 0) { return false; }
    }
    return true;
  }

  function order(a, b) {
    var byId = a.Id < b.Id ? -1 : a.Id > b.Id ? 1 : 0;
    var byStatus = (GROUP_RANK[a.Status] - GROUP_RANK[b.Status]) || (SEV_RANK[a.Severity] - SEV_RANK[b.Severity]);
    var result;
    switch (state.sort) {
      case 'id': result = byId; break;
      case 'title': result = String(a.Title).localeCompare(String(b.Title), 'en', { numeric: true }) || byId; break;
      case 'severity': result = (SEV_RANK[a.Severity] - SEV_RANK[b.Severity]) || (GROUP_RANK[a.Status] - GROUP_RANK[b.Status]) || byId; break;
      default: result = byStatus || byId;
    }
    return result * state.dir;
  }

  function sortHead(key, label) {
    var button = el('button', { type: 'button', class: 'sort-head', title: 'Sort by ' + label.toLowerCase(), onclick: function () {
      state.dir = state.sort === key ? -state.dir : 1;
      state.sort = key;
      sortRows();
    } }, label);
    button.dataset.sort = key;
    controls.sortHeads.push(button);
    return button;
  }

  function sortRows() {
    Object.keys(groupNodes).forEach(function (area) {
      var body = groupNodes[area].body;
      results.filter(function (r) { return r.Area === area; }).sort(order).forEach(function (r) { body.appendChild(checkNodes[r.Id].details); });
    });
    controls.sortHeads.forEach(function (b) {
      var active = b.dataset.sort === state.sort;
      b.setAttribute('aria-sort', active ? (state.dir === 1 ? 'ascending' : 'descending') : 'none');
    });
    Object.keys(checkNodes).forEach(function (id) { if (checkNodes[id].rendered) { updateNav(id); } });
  }

  function renderGroups() {
    var host = document.getElementById('groups');
    areaList().forEach(function (area) {
      var list = results.filter(function (r) { return r.Area === area; }).sort(order);
      var c = counts(list);
      var a = areaInfo(area);
      var body = el('div', null,
        el('div', { class: 'col-head row-grid' },
          el('span'), sortHead('status', 'Status'), sortHead('id', 'Id'), sortHead('title', 'Check'), sortHead('severity', 'Severity'), el('span', { text: 'Affected' })));
      var group = el('details', { class: 'card group', open: true },
        el('summary', null,
          icon('chevron', 16, 'chev'),
          el('span', { class: 'group-title', text: areaName(area) }),
          el('span', { class: 'group-counts' },
            el('span', null, el('b', { class: 'c-pass', text: c.Passed }), ' passed'),
            el('span', null, el('b', { class: 'c-fail', text: c.Failed }), ' failed'),
            c.Review ? el('span', null, el('b', { class: 'c-review', text: c.Review }), ' to review') : null,
            c.Other ? el('span', { text: c.Other + ' other' }) : null),
          el('span', { class: 'group-score' }, 'Score', el('b', { text: typeof a.Score === 'number' ? a.Score : '—' }))),
        body);
      var section = el('section', { id: 'area-' + area, 'aria-label': areaName(area), style: 'margin-top:0' }, group);
      groupNodes[area] = { section: section, group: group, body: body };
      list.forEach(function (r) { body.appendChild(renderRow(r)); });
      host.appendChild(section);
    });
  }

  function renderRow(r) {
    var host = el('div', { class: 'detail-host' });
    var details = el('details', { class: 'check', id: r.Id },
      el('summary', { class: 'row-grid' },
        icon('chevron', 14, 'chev'),
        el('span', null, badge(r.Status)),
        el('span', { class: 'c-id', text: r.Id }),
        el('span', { class: 'c-title', text: r.Title }),
        el('span', { class: 'c-sev', text: r.Severity }),
        el('span', { class: 'c-affected', text: r.Status === 'Failed' && r.AffectedCount > 0 ? fmtNumber(r.AffectedCount) : '' })),
      host);
    var entry = { details: details, result: r, host: host, rendered: false };
    checkNodes[r.Id] = entry;
    details.addEventListener('toggle', function () {
      if (!details.open) { return; }
      ensureDetail(entry);
      if (quiet) { return; }
      // One check open at a time keeps the place in the list clear.
      Object.keys(checkNodes).forEach(function (id) { if (id !== r.Id && checkNodes[id].details.open) { checkNodes[id].details.open = false; } });
      if (window.history && window.history.replaceState) { window.history.replaceState(null, '', '#' + r.Id); }
    });
    return details;
  }

  function ensureDetail(entry) {
    if (entry.rendered) { return; }
    entry.rendered = true;
    entry.host.appendChild(renderDetail(entry.result));
  }

  // Checks currently visible, in display order (used by previous / next).
  function visibleIds() {
    var ids = [];
    areaList().forEach(function (area) {
      if (groupNodes[area].section.hidden) { return; }
      results.filter(function (r) { return r.Area === area; }).sort(order).forEach(function (r) {
        if (!checkNodes[r.Id].details.hidden) { ids.push(r.Id); }
      });
    });
    return ids;
  }

  function openCheck(id) {
    var entry = checkNodes[id];
    if (!entry) { return; }
    groupNodes[entry.result.Area].group.open = true;
    entry.details.open = true;
    entry.details.scrollIntoView({ block: 'start' });
    entry.details.querySelector('summary').focus({ preventScroll: true });
  }

  function applyFilters() {
    var visible = 0;
    Object.keys(groupNodes).forEach(function (area) {
      var shown = 0;
      results.filter(function (r) { return r.Area === area; }).forEach(function (r) {
        var show = matches(r);
        checkNodes[r.Id].details.hidden = !show;
        if (show) { shown++; }
      });
      groupNodes[area].section.hidden = shown === 0;
      visible += shown;
    });
    document.getElementById('no-match').hidden = visible > 0;
    document.getElementById('checks-count').textContent = visible === results.length ? results.length + ' checks' : visible + ' of ' + results.length;
    controls.tabs.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.filter === state.filter)); });
    controls.totals.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.filter === state.filter)); });
    controls.areaCards.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.area === state.area)); });
    controls.areaReset.hidden = !state.area;
    controls.areaReset.textContent = state.area ? areaName(state.area) + ' ×' : '';
    if (controls.search.value.trim().toLowerCase() !== state.search) { controls.search.value = state.search; }
    Object.keys(checkNodes).forEach(function (id) { if (checkNodes[id].rendered) { updateNav(id); } });
  }

  // ---------------------------------------------------------------- detail

  function renderDetail(r) {
    var box = el('div', { class: 'detail ' + kind(r.Status) });
    var evaluated = r.Status === 'Passed' || r.Status === 'Failed' || r.Status === 'Investigate';

    append(box, el('div', { class: 'detail-meta' },
      el('span', { text: STATUS_LABEL[r.Status] || r.Status }),
      el('span', { text: r.Severity + ' severity' }),
      r.Category ? el('span', { text: r.Category }) : null,
      evaluated && r.EvaluatedCount !== null && r.EvaluatedCount !== undefined ? el('span', { text: fmtNumber(r.AffectedCount) + ' of ' + fmtNumber(r.EvaluatedCount) + ' affected' }) : null,
      r.ExcludedCount ? el('span', { text: fmtNumber(r.ExcludedCount) + ' excluded by configuration' }) : null,
      el('span', { class: 'mono', text: r.Id })));

    if (r.SkipReason || r.ErrorMessage) { box.appendChild(el('p', { class: 'reason', text: r.SkipReason || r.ErrorMessage })); }
    if (r.Summary) { box.appendChild(el('p', { class: 'detail-summary', text: r.Summary })); }

    box.appendChild(md(r.Description));
    box.appendChild(el('h3', { text: 'Why it matters' }));
    box.appendChild(md(r.Rationale));

    var findings = Array.isArray(r.Findings) ? r.Findings : [];
    var total = typeof r.FindingsTotal === 'number' ? r.FindingsTotal : findings.length;
    if (findings.length || total) { box.appendChild(renderFindings(r, findings, total)); }

    var rem = r.Remediation || {};
    if (rem.Steps || rem.PortalUrl || rem.PowerShell) {
      box.appendChild(el('h3', { text: 'How to fix' }));
      if (rem.Steps) { box.appendChild(md(rem.Steps)); }
      if (rem.PortalUrl && safeUrl(rem.PortalUrl)) {
        box.appendChild(el('p', null, el('a', { href: rem.PortalUrl, text: 'Open the admin portal', target: '_blank', rel: 'noopener noreferrer' })));
      }
      if (rem.PowerShell) {
        var copy = el('button', { type: 'button', class: 'text-btn copy-btn', text: 'Copy' });
        copy.addEventListener('click', function () { copyText(rem.PowerShell, copy); });
        box.appendChild(el('div', { class: 'code' },
          el('div', { class: 'code-head' }, el('span', { text: 'PowerShell sample. Review before running; ARGUS never runs it.' }), copy),
          el('pre', null, el('code', { text: rem.PowerShell }))));
      }
    }

    var refs = (r.References || []).filter(function (x) { return x && safeUrl(x.Url); });
    if (refs.length) {
      box.appendChild(el('h3', { text: 'References' }));
      box.appendChild(el('ul', { class: 'refs' }, refs.map(function (x) {
        return el('li', null, el('a', { href: x.Url, text: x.Title || x.Url, target: '_blank', rel: 'noopener noreferrer' }));
      })));
    }

    var params = r.Parameters || {};
    var keys = Object.keys(params);
    if (keys.length) {
      box.appendChild(el('p', { class: 'params', text: 'Parameters: ' + keys.map(function (k) { return k + ' = ' + cellText(params[k]); }).join(', ') }));
    }

    // Navigation sits below the check panel, outside its border.
    var nav = el('nav', { class: 'check-nav', 'aria-label': 'Move between checks' });
    checkNodes[r.Id].nav = nav;
    setTimeout(function () { updateNav(r.Id); }, 0);
    var frag = document.createDocumentFragment();
    append(frag, [box, nav]);
    return frag;
  }

  function updateNav(id) {
    var entry = checkNodes[id];
    if (!entry || !entry.nav) { return; }
    var ids = visibleIds();
    var index = ids.indexOf(id);
    var prev = index > 0 ? ids[index - 1] : null;
    var next = index >= 0 && index < ids.length - 1 ? ids[index + 1] : null;
    function navButton(target, cls, dir) {
      var r = target ? checkNodes[target].result : null;
      return el('button', {
        type: 'button', class: 'nav-btn ' + cls, disabled: !target,
        title: r ? r.Id + ' — ' + r.Title : '',
        onclick: function () { if (target) { openCheck(target); } }
      }, dir === 'prev' ? icon('left', 14) : null, el('span', { text: r ? (dir === 'prev' ? 'Previous: ' : 'Next: ') + r.Title : '' }), dir === 'next' ? icon('right', 14) : null);
    }
    while (entry.nav.firstChild) { entry.nav.removeChild(entry.nav.firstChild); }
    append(entry.nav, [
      navButton(prev, 'nav-prev', 'prev'),
      el('span', { class: 'nav-pos', text: index >= 0 ? (index + 1) + ' of ' + ids.length : '' }),
      navButton(next, 'nav-next', 'next')
    ]);
  }

  function renderFindings(r, rows, total) {
    var columns = Array.isArray(r.FindingColumns) && r.FindingColumns.length ? r.FindingColumns.slice() : (rows[0] ? Object.keys(rows[0]) : []);
    var wrap = el('div');
    var tbody = el('tbody');
    var sortState = { column: null, dir: 1 };
    var current = rows.slice();
    var countLabel = el('span', { class: 'muted' });
    var search = el('input', { type: 'search', placeholder: 'Filter', 'aria-label': 'Filter findings of ' + r.Id });
    var exportButton = el('button', { type: 'button', class: 'text-btn', text: 'Export CSV', onclick: function () { downloadCsv(r.Id + '-findings.csv', columns, current); } });

    // Column widths (Excel-like): start from the content, resize by dragging the header edge,
    // double-click the edge to fit, Shift+Left/Right on a focused header for the keyboard.
    var table = el('table', { class: 'resizable' });
    var colgroup = el('colgroup');
    var widths = columns.map(function (c) { return fitWidth(c, rows.slice(0, 300)); });
    var cols = widths.map(function (w) { var col = el('col'); col.style.width = w + 'px'; colgroup.appendChild(col); return col; });
    function applyWidths() {
      widths.forEach(function (w, i) { cols[i].style.width = w + 'px'; });
      table.style.width = widths.reduce(function (sum, w) { return sum + w; }, 0) + 'px';
    }
    function fitWidth(column, sample) {
      var longest = textWidth(column, true);
      sample.forEach(function (row) { longest = Math.max(longest, textWidth(cellText(row[column]), false)); });
      return Math.max(64, Math.min(560, Math.ceil(longest) + 30));
    }

    var headRow = el('tr');
    columns.forEach(function (column, index) {
      var th = el('th', { class: 'sortable', scope: 'col', tabindex: '0', 'aria-sort': 'none', title: column }, el('span', { class: 'th-label', text: column }));
      function sortBy() {
        sortState.dir = sortState.column === column ? -sortState.dir : 1;
        sortState.column = column;
        Array.prototype.forEach.call(headRow.children, function (h) { h.setAttribute('aria-sort', 'none'); });
        th.setAttribute('aria-sort', sortState.dir === 1 ? 'ascending' : 'descending');
        draw();
      }
      th.addEventListener('click', sortBy);
      th.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); sortBy(); }
        else if (e.shiftKey && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) {
          e.preventDefault();
          widths[index] = Math.max(48, widths[index] + (e.key === 'ArrowRight' ? 24 : -24));
          applyWidths();
        }
      });

      var handle = el('span', { class: 'col-resizer', 'aria-hidden': 'true', title: 'Drag to resize, double-click to fit' });
      handle.addEventListener('click', function (e) { e.stopPropagation(); });
      handle.addEventListener('dblclick', function (e) {
        e.stopPropagation();
        widths[index] = fitWidth(column, current);
        applyWidths();
      });
      handle.addEventListener('pointerdown', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var startX = e.clientX;
        var startWidth = widths[index];
        // Pointer coordinates are in screen pixels; widths are CSS pixels (the page may be zoomed).
        var scale = table.getBoundingClientRect().width / (table.offsetWidth || 1) || 1;
        handle.setPointerCapture(e.pointerId);
        document.body.classList.add('resizing');
        function move(ev) {
          widths[index] = Math.max(48, Math.round(startWidth + (ev.clientX - startX) / scale));
          applyWidths();
        }
        function up() {
          handle.removeEventListener('pointermove', move);
          handle.removeEventListener('pointerup', up);
          handle.removeEventListener('pointercancel', up);
          document.body.classList.remove('resizing');
        }
        handle.addEventListener('pointermove', move);
        handle.addEventListener('pointerup', up);
        handle.addEventListener('pointercancel', up);
      });
      th.appendChild(handle);
      headRow.appendChild(th);
    });

    function draw() {
      var term = search.value.trim().toLowerCase();
      current = rows.filter(function (row) {
        return !term || columns.some(function (c) { return cellText(row[c]).toLowerCase().indexOf(term) >= 0; });
      });
      if (sortState.column) {
        var c = sortState.column;
        current.sort(function (a, b) {
          var x = a[c], y = b[c];
          if (typeof x === 'number' && typeof y === 'number') { return (x - y) * sortState.dir; }
          return cellText(x).localeCompare(cellText(y), 'en', { numeric: true }) * sortState.dir;
        });
      }
      while (tbody.firstChild) { tbody.removeChild(tbody.firstChild); }
      var frag = document.createDocumentFragment();
      current.forEach(function (row) {
        var tr = el('tr');
        columns.forEach(function (c) {
          var value = cellText(row[c]);
          tr.appendChild(el('td', { text: value, title: value.length > 12 ? value : null }));
        });
        frag.appendChild(tr);
      });
      tbody.appendChild(frag);
      countLabel.textContent = current.length === rows.length ? fmtNumber(rows.length) + ' rows' : fmtNumber(current.length) + ' of ' + fmtNumber(rows.length);
    }
    search.addEventListener('input', draw);

    append(table, [colgroup, el('thead', null, headRow), tbody]);
    applyWidths();
    wrap.appendChild(el('div', { class: 'findings-head' }, el('h3', { text: 'Findings' }), countLabel, search, exportButton));
    wrap.appendChild(el('div', { class: 'findings-table' }, table));
    if (total > rows.length) {
      wrap.appendChild(el('p', { class: 'cap-note', text: 'Showing ' + fmtNumber(rows.length) + ' of ' + fmtNumber(total) + '. The full list is in the JSON and CSV outputs.' }));
    }
    draw();
    return wrap;
  }

  // ---------------------------------------------------------------- footer

  function renderFooter() {
    var scopes = {};
    results.forEach(function (r) { ((r.Requires || {}).GraphScopes || []).forEach(function (s) { scopes[s] = true; }); });
    var notEvaluated = results.filter(function (r) { return r.Status === 'Skipped' || r.Status === 'Error' || r.Status === 'NotRun'; });

    var table = notEvaluated.length ? el('table', null,
      el('thead', null, el('tr', null, el('th', { text: 'Check' }), el('th', { text: 'Status' }), el('th', { text: 'Reason' }))),
      el('tbody', null, notEvaluated.map(function (r) {
        return el('tr', null, el('td', null, el('a', { href: '#' + r.Id, class: 'mono', text: r.Id })), el('td', { text: STATUS_LABEL[r.Status] }), el('td', { text: r.SkipReason || r.ErrorMessage || '' }));
      }))) : el('p', { text: 'All selected checks were evaluated.' });

    var filters = run.Filters || {};
    var filterText = ['Area', 'Id', 'ExcludeId', 'Tag'].filter(function (k) { return filters[k] && filters[k].length; })
      .map(function (k) { return '-' + k + ' ' + filters[k].join(', '); }).join('  ');

    function row(label, value) { return [el('dt', { text: label }), el('dd', null, value)]; }

    document.getElementById('footer').appendChild(el('div', { class: 'footer-inner' },
      el('details', null,
        el('summary', { text: 'Run details' }),
        el('h3', { text: 'Not evaluated' }), table,
        el('h3', { text: 'Run' }),
        el('dl', { class: 'kv' },
          row('Tenant ID', el('span', { class: 'mono', text: tenant.Id || '—' })),
          row('Duration', fmtDuration(run.DurationSeconds)),
          row('Sign-in', run.AuthMode || '—'),
          row('Connected', (env.ConnectedServices || []).join(', ') || 'none'),
          row('Graph scopes used', el('span', { class: 'mono', text: Object.keys(scopes).sort().join(', ') || 'none' })),
          row('Filters', filterText || 'none'),
          row('Configuration', run.ConfigFile || 'defaults'),
          row('ARGUS', (tool.Version || '') + ' · results schema ' + (data.SchemaVersion || '')))),
      el('p', { class: 'disclaimer' },
        'ARGUS runs read-only governance checks and never changes the tenant. Remediation steps and PowerShell samples are guidance only. ',
        el('a', { href: tool.ProjectUri, text: 'ARGUS ' + (tool.Version || ''), target: '_blank', rel: 'noopener noreferrer' }))));
  }

  // ---------------------------------------------------------------- deep links + print

  function openFromHash() {
    var id = decodeURIComponent((window.location.hash || '').slice(1));
    var entry = checkNodes[id];
    if (!entry) { return; }
    if (entry.details.hidden) { state.search = ''; state.filter = ''; state.area = ''; applyFilters(); }
    openCheck(id);
  }

  var printState = null;
  window.addEventListener('beforeprint', function () {
    printState = { checks: {}, groups: {} };
    quiet = true;
    Object.keys(checkNodes).forEach(function (id) {
      var entry = checkNodes[id];
      printState.checks[id] = entry.details.open;
      if (!entry.details.hidden) { ensureDetail(entry); entry.details.open = true; }
    });
    Object.keys(groupNodes).forEach(function (a) { printState.groups[a] = groupNodes[a].group.open; groupNodes[a].group.open = true; });
    var footer = document.querySelector('.footer details');
    if (footer) { printState.footer = footer.open; footer.open = true; }
  });
  window.addEventListener('afterprint', function () {
    if (!printState) { return; }
    Object.keys(checkNodes).forEach(function (id) { checkNodes[id].details.open = printState.checks[id]; });
    Object.keys(groupNodes).forEach(function (a) { groupNodes[a].group.open = printState.groups[a]; });
    var footer = document.querySelector('.footer details');
    if (footer) { footer.open = printState.footer; }
    setTimeout(function () { quiet = false; }, 0);
    printState = null;
  });

  // ---------------------------------------------------------------- boot

  applyTheme(currentTheme());
  renderHeader();
  renderNotes();
  renderOverview();
  renderAreas();
  renderToolbar();
  renderGroups();
  renderFooter();
  sortRows();
  applyFilters();
  openFromHash();
  window.addEventListener('hashchange', openFromHash);
}());
