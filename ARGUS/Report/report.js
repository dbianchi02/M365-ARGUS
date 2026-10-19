/* ARGUS report renderer (minimal layout).
 * Vanilla JS, no dependencies, no network access.
 * Security: every value from the results data is inserted with textContent / DOM APIs.
 * This file never assigns HTML strings to the DOM. Markdown from check metadata is parsed
 * by a small internal renderer that also builds DOM nodes.
 */
(function () {
  'use strict';

  var STATUS_LABEL = { Passed: 'Passed', Failed: 'Failed', Investigate: 'To review', Error: 'Error', Skipped: 'Skipped', NotRun: 'Not run' };
  var OTHER = ['Investigate', 'Error', 'Skipped', 'NotRun'];
  var SEVERITIES = ['Critical', 'High', 'Medium', 'Low', 'Info'];
  var SEV_RANK = { Critical: 0, High: 1, Medium: 2, Low: 3, Info: 4 };
  var GROUP_RANK = { Failed: 0, Investigate: 1, Error: 2, Skipped: 3, NotRun: 4, Passed: 5 };
  var AREA_ORDER = ['EntraID', 'Applications', 'Licensing', 'GroupsTeams', 'SharePoint', 'Exchange'];
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
    right: ['M9 6l6 6-6 6']
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

  // filter: '' | 'Failed' | 'Passed' | 'Other'; sort key: status | id | title | severity
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

  function kind(status) { return status === 'Passed' ? 'pass' : status === 'Failed' ? 'fail' : 'other'; }
  function isOther(r) { return r.Status !== 'Passed' && r.Status !== 'Failed'; }

  function badge(status) {
    return el('span', { class: 'badge ' + kind(status), text: STATUS_LABEL[status] || status });
  }

  function counts(list) {
    var c = { total: list.length, Passed: 0, Failed: 0, Other: 0 };
    OTHER.forEach(function (s) { c[s] = 0; });
    list.forEach(function (r) {
      c[r.Status] = (c[r.Status] || 0) + 1;
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
    var bar = el('div', { class: cls, role: 'img', 'aria-label': c.Passed + ' passed, ' + c.Failed + ' failed, ' + c.Other + ' other' });
    if (c.Passed) { bar.appendChild(el('span', { class: 'seg-pass', style: 'flex:' + c.Passed })); }
    if (c.Failed) { bar.appendChild(el('span', { class: 'seg-fail', style: 'flex:' + c.Failed })); }
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
    document.title = 'ARGUS - ' + tenantLabel + ' - ' + fmtTimestamp(run.StartedAt);

    controls.theme = el('button', { type: 'button', class: 'icon-btn', onclick: cycleTheme });
    updateThemeButton();
    document.getElementById('appbar').appendChild(el('div', { class: 'appbar-inner' },
      el('span', { class: 'brand' }, el('span', { class: 'brand-mark' }, icon('eye', 16)), el('span', { class: 'wordmark', text: 'ARGUS' })),
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

  // ---------------------------------------------------------------- overview + charts

  function renderOverview() {
    var host = document.getElementById('overview');
    var value = typeof score.Score === 'number' ? score.Score : null;
    var c = counts(results);

    host.appendChild(el('div', null,
      el('div', { class: 'score-label', text: 'Governance score' }),
      el('div', { class: 'score-value' }, el('b', { text: value === null ? '—' : value }), el('span', { text: '/ 100' })),
      el('div', { class: 'score-meta' },
        'Grade ' + (score.Grade || 'n/a') + ' · ' + fmtNumber(score.Coverage) + '% coverage',
        score.IsPartial ? el('div', { class: 'partial', text: 'Partial: not enough checks could be evaluated.' }) : null)));

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
    host.appendChild(el('div', null,
      resultBar(c, 'result-bar'),
      el('div', { class: 'totals' }, total('Passed', 'Passed', 'pass'), total('Failed', 'Failed', 'fail'), total('Other', 'Not passed or failed', 'other')),
      otherParts.length ? el('div', { class: 'other-detail', text: 'Other: ' + otherParts.join(', ') + '.' }) : null));
  }

  function renderResultsChart() {
    var host = document.getElementById('chart-results');
    var c = counts(results);
    var total = c.total || 1;
    var size = 120;
    var r = 48;
    var circ = 2 * Math.PI * r;
    var parts = [['Passed', 'pass', c.Passed], ['Failed', 'fail', c.Failed], ['Other', 'other', c.Other]].filter(function (p) { return p[2]; });
    var gap = parts.length > 1 ? 2 : 0;
    var offset = 0;
    var chart = svg('svg', { viewBox: '0 0 ' + size + ' ' + size, role: 'img', 'aria-label': c.Passed + ' passed, ' + c.Failed + ' failed, ' + c.Other + ' other' },
      svg('circle', { cx: 60, cy: 60, r: r, fill: 'none', 'stroke-width': 12, style: 'stroke: var(--subtle)' }));
    parts.forEach(function (p) {
      var len = circ * p[2] / total;
      var dash = Math.max(len - gap, 0.5);
      chart.appendChild(svg('circle', {
        cx: 60, cy: 60, r: r, fill: 'none', 'stroke-width': 12,
        style: 'stroke: var(--' + p[1] + ')' + (p[1] === 'other' ? '; opacity: 0.55' : ''),
        'stroke-dasharray': dash + ' ' + (circ - dash), 'stroke-dashoffset': -offset, transform: 'rotate(-90 60 60)'
      }));
      offset += len;
    });
    var passRate = c.Passed + c.Failed ? Math.round(100 * c.Passed / (c.Passed + c.Failed)) : 0;
    chart.appendChild(svg('text', { class: 'donut-total', x: 60, y: 56, 'text-anchor': 'middle', 'dominant-baseline': 'central', 'font-size': 22, text: passRate + '%' }));
    chart.appendChild(svg('text', { class: 'donut-sub', x: 60, y: 76, 'text-anchor': 'middle', 'font-size': 10, text: 'pass rate' }));

    host.appendChild(el('h2', { text: 'Results' }));
    host.appendChild(el('div', { class: 'donut' }, chart, el('ul', { class: 'legend' },
      el('li', null, el('span', { class: 'key pass' }), 'Passed', el('b', { text: c.Passed })),
      el('li', null, el('span', { class: 'key fail' }), 'Failed', el('b', { text: c.Failed })),
      el('li', null, el('span', { class: 'key other' }), 'Other', el('b', { text: c.Other })))));
  }

  function renderSeverityChart() {
    var host = document.getElementById('chart-severity');
    var failed = results.filter(function (r) { return r.Status === 'Failed'; });
    var max = 1;
    var bySev = {};
    SEVERITIES.forEach(function (s) {
      bySev[s] = failed.filter(function (r) { return r.Severity === s; }).length;
      max = Math.max(max, bySev[s]);
    });
    host.appendChild(el('h2', { text: 'Failed by severity' }));
    SEVERITIES.forEach(function (s) {
      host.appendChild(el('div', { class: 'hbar' },
        el('span', { text: s }),
        el('div', { class: 'track', role: 'img', 'aria-label': s + ': ' + bySev[s] + ' failed' }, el('div', { class: 'fill', style: 'width:' + (100 * bySev[s] / max) + '%' })),
        el('span', { class: 'val', text: bySev[s] })));
    });
  }

  function renderTopChart() {
    var host = document.getElementById('chart-top');
    var top = results.filter(function (r) { return r.Status === 'Failed' && r.AffectedCount > 0; })
      .sort(function (a, b) { return b.AffectedCount - a.AffectedCount; }).slice(0, 5);
    host.appendChild(el('h2', { text: 'Largest findings' }));
    if (!top.length) {
      host.appendChild(el('p', { class: 'empty-chart', text: 'No failed check lists affected objects.' }));
      return;
    }
    var max = top[0].AffectedCount;
    host.appendChild(el('ul', { class: 'top-list' }, top.map(function (r) {
      return el('li', null, el('a', { href: '#' + r.Id, title: r.Id + ' — ' + r.Title },
        el('div', { class: 't-line' }, el('span', { class: 't-title', text: r.Title }), el('span', { class: 't-val', text: fmtNumber(r.AffectedCount) })),
        el('div', { class: 'track' }, el('div', { class: 'fill', style: 'width:' + Math.max(2, 100 * r.AffectedCount / max) + '%' }))));
    })));
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
        c.Other ? el('span', null, el('b', { text: c.Other }), ' other') : null));
      card.dataset.area = area;
      controls.areaCards.push(card);
      host.appendChild(card);
    });
  }

  // ---------------------------------------------------------------- toolbar + groups

  function renderToolbar() {
    var c = counts(results);
    var tabs = el('div', { class: 'tabs', role: 'group', 'aria-label': 'Filter checks' });
    [['', 'All', c.total], ['Failed', 'Failed', c.Failed], ['Passed', 'Passed', c.Passed], ['Other', 'Other', c.Other]].forEach(function (t) {
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
    if (state.filter && state.filter !== 'Other' && r.Status !== state.filter) { return false; }
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

    var headRow = el('tr');
    columns.forEach(function (column) {
      var th = el('th', { class: 'sortable', scope: 'col', tabindex: '0', text: column, 'aria-sort': 'none' });
      function sortBy() {
        sortState.dir = sortState.column === column ? -sortState.dir : 1;
        sortState.column = column;
        Array.prototype.forEach.call(headRow.children, function (h) { h.setAttribute('aria-sort', 'none'); });
        th.setAttribute('aria-sort', sortState.dir === 1 ? 'ascending' : 'descending');
        draw();
      }
      th.addEventListener('click', sortBy);
      th.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); sortBy(); } });
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
        columns.forEach(function (c) { tr.appendChild(el('td', { text: cellText(row[c]) })); });
        frag.appendChild(tr);
      });
      tbody.appendChild(frag);
      countLabel.textContent = current.length === rows.length ? fmtNumber(rows.length) + ' rows' : fmtNumber(current.length) + ' of ' + fmtNumber(rows.length);
    }
    search.addEventListener('input', draw);

    wrap.appendChild(el('div', { class: 'findings-head' }, el('h3', { text: 'Findings' }), countLabel, search, exportButton));
    wrap.appendChild(el('div', { class: 'findings-table' }, el('table', null, el('thead', null, headRow), tbody)));
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
  renderResultsChart();
  renderSeverityChart();
  renderTopChart();
  renderAreas();
  renderToolbar();
  renderGroups();
  renderFooter();
  sortRows();
  applyFilters();
  openFromHash();
  window.addEventListener('hashchange', openFromHash);
}());
