// ── Helpers ─────────────────────────────────────────────────────────────────
function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function csrfToken() {
  var m = document.querySelector('meta[name="csrf-token"]');
  return m ? m.content : '';
}

function sleep(ms) {
  return new Promise(function(resolve) { setTimeout(resolve, ms); });
}

function todayStr() {
  var d = new Date();
  return d.getFullYear() +
    String(d.getMonth() + 1).padStart(2, '0') +
    String(d.getDate()).padStart(2, '0');
}

// ── CSV header (col 18 = Rol) ────────────────────────────────────────────────
var CSV_HEADER = 'Día,Mes,Año,Estado,INEGI,Municipio,Abatido,Detenidos,Organización,' +
  'Grupo afiliado,Nombre,Apellido Paterno,Apellido Materno,Alias,Género,Edad,' +
  'Posición liderazgo,Rol,SEDENA,SEMAR,GN,SSCP,FGR,SSP-Estatal,' +
  'FGE/PGJ,Policía municipal,Otro,Fuente';

// Indices (0-based) of numeric fields
var NUMERIC_IDX = [0, 1, 2, 4, 6, 7, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26];

// ── CSV row parser (handles quoted fields) ───────────────────────────────────
function parseCSVRow(line) {
  var fields = [], cur = '', inQ = false;
  for (var i = 0; i < line.length; i++) {
    var c = line[i];
    if (c === '"') {
      if (inQ && line[i + 1] === '"') { cur += '"'; i++; }
      else { inQ = !inQ; }
    } else if (c === ',' && !inQ) {
      fields.push(cur.trim());
      cur = '';
    } else {
      cur += c;
    }
  }
  fields.push(cur.trim());
  return fields;
}

// ── Row validator ────────────────────────────────────────────────────────────
function reserializeFields(fields) {
  return fields.map(function(f) {
    return (f.indexOf(',') !== -1 || f.indexOf('"') !== -1)
      ? '"' + f.replace(/"/g, '""') + '"'
      : f;
  }).join(',');
}

function validateRow(rawLine, sourceUrl) {
  // Clean intra-field newlines
  var line = rawLine.replace(/[\r\n]+/g, ' ').trim();
  if (!line) return { ok: false, error: 'Línea vacía' };

  var fields = parseCSVRow(line);

  // Auto-correct known Claude bug: extra empty field right before the URL
  if (fields.length === 29 && fields[27] === '' && fields[28].startsWith('http')) {
    fields.splice(27, 1);
    line = reserializeFields(fields);
  }

  if (fields.length !== 28) {
    return { ok: false, error: 'Campos: ' + fields.length + ' (esperado 28)' };
  }

  // Numeric fields must be empty or numeric
  for (var i = 0; i < NUMERIC_IDX.length; i++) {
    var idx = NUMERIC_IDX[i];
    var val = fields[idx];
    if (val !== '' && isNaN(Number(val))) {
      return { ok: false, error: 'Campo numérico #' + (idx + 1) + ' tiene texto: "' + val + '"' };
    }
  }

  // Rol (index 17) must not be empty
  if (!fields[17]) {
    return { ok: false, error: 'Campo Rol (col 18) está vacío' };
  }

  // Fuente (index 27) must look like a URL
  if (!fields[27].startsWith('http')) {
    return { ok: false, error: 'Fuente no parece URL: "' + fields[27] + '"' };
  }

  return { ok: true, cleaned: line };
}

// ── Build pure CSV (header + data rows only) ─────────────────────────────────
function buildCSV(allRows) {
  return [CSV_HEADER].concat(allRows).join('\n');
}

// ── Build log file ───────────────────────────────────────────────────────────
function buildLog(stats, formatErrors) {
  var now  = new Date().toLocaleString('es-MX');
  var lines = [
    '=== RESUMEN DE EJECUCIÓN: ' + now + ' ===',
    '',
    'Total de notas encontradas:              ' + stats.total,
    'Notas procesadas exitosamente:           ' + stats.ok,
    'Filas CSV generadas:                     ' + stats.csvRows,
    '---',
    'Descartadas – error de fetch:            ' + stats.fetchError,
    'Descartadas – título excluido:           ' + stats.tituloExcluido,
    'Descartadas – snippet / URL:             ' + stats.snippetIrrelev,
    'Descartadas – Claude (no es detención):  ' + stats.claudeDescartar,
    'Errores de formato en filas:             ' + stats.formatErrors,
    'Errores inesperados:                     ' + stats.errorInesp
  ];

  if (formatErrors.length > 0) {
    lines.push('');
    lines.push('=== ERRORES DE FORMATO ===');
    formatErrors.forEach(function(fe, i) {
      lines.push('');
      lines.push('[' + (i + 1) + '] URL: ' + fe.url);
      lines.push('    Fila: ' + fe.row);
      lines.push('    Motivo: ' + fe.error);
    });
  }

  return lines.join('\n');
}

// ── Build summary HTML ───────────────────────────────────────────────────────
function summaryRow(label, value, highlight) {
  return '<div class="summary-row">' +
    '<span class="summary-label">' + escHtml(label) + '</span>' +
    '<span class="summary-value' + (highlight ? ' highlight' : '') + '">' + value + '</span>' +
    '</div>';
}

function buildSummaryHTML(stats) {
  return '<h6>Resumen de extracción</h6>' +
    summaryRow('Total de notas encontradas',          stats.total,         false) +
    summaryRow('Notas procesadas exitosamente',       stats.ok,            false) +
    summaryRow('Filas CSV generadas',                 stats.csvRows,       stats.csvRows > 0) +
    '<div style="margin-top:10px;font-weight:600;font-size:12px;color:#aaa;text-transform:uppercase;letter-spacing:.5px;">Descartadas por causa</div>' +
    summaryRow('Error de fetch o contenido vacío',   stats.fetchError,     false) +
    summaryRow('Título con palabras excluidas',       stats.tituloExcluido, false) +
    summaryRow('Snippet / URL sin términos relevantes', stats.snippetIrrelev, false) +
    summaryRow('Claude: nota no es detención',        stats.claudeDescartar, false) +
    summaryRow('Errores de formato en filas',         stats.formatErrors,  stats.formatErrors > 0) +
    summaryRow('Error inesperado',                    stats.errorInesp,    false);
}

// ── Trigger file downloads ───────────────────────────────────────────────────
function offerDownloads(csvContent, logContent) {
  var today = todayStr();

  function makeBtn(id, content, filename, mime) {
    var blob = new Blob([content], { type: mime });
    var url  = URL.createObjectURL(blob);
    var btn  = document.getElementById(id);
    if (!btn) return;
    btn.onclick = function() {
      var a = document.createElement('a');
      a.href = url; a.download = filename; a.click();
    };
  }

  makeBtn('download-btn',     '﻿' + csvContent,
          'detenciones_' + today + '.csv', 'text/csv;charset=utf-8;');
  makeBtn('download-log-btn', logContent,
          'detenciones_' + today + '.log', 'text/plain;charset=utf-8;');

  var area = document.getElementById('download-area');
  if (area) area.style.display = 'flex';
}

// ── Etapa 1: Búsqueda ────────────────────────────────────────────────────────
function initSearch() {
  var btn = document.getElementById('search-btn');
  if (!btn) return;

  btn.addEventListener('click', function() {
    var status = document.getElementById('status-msg');
    var grid   = document.getElementById('results-grid');
    var extSec = document.getElementById('extraction-section');

    btn.disabled       = true;
    btn.innerHTML      = '<span class="agent-spinner"></span> Buscando…';
    status.textContent = 'Lanzando 6 búsquedas en paralelo…';
    grid.innerHTML     = '';
    if (extSec) extSec.style.display = 'none';

    fetch(btn.getAttribute('data-search-url'), {
      headers: { 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' }
    })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.error) { status.textContent = 'Error: ' + data.error; return; }

      var articles = data.articles || [];
      status.textContent = articles.length
        ? articles.length + ' noticias encontradas (duplicados eliminados)'
        : 'No se encontraron noticias.';

      articles.forEach(function(a) {
        var domain;
        try { domain = new URL(a.link).hostname.replace('www.', ''); }
        catch (e) { domain = a.source || ''; }

        var card = document.createElement('div');
        card.className = 'news-card';
        card.innerHTML =
          '<div style="display:flex;justify-content:space-between;align-items:center;">' +
            '<span class="card-source">' + escHtml(domain)       + '</span>' +
            '<span class="card-date">'   + escHtml(a.date || '') + '</span>' +
          '</div>' +
          '<div class="card-title">'   + escHtml(a.title   || '') + '</div>' +
          '<div class="card-snippet">' + escHtml(a.snippet || '') + '</div>' +
          '<a class="card-link" href="' + escHtml(a.link) + '" target="_blank" rel="noopener">' +
            'Ver nota <i class="material-icons" style="font-size:14px;">open_in_new</i>' +
          '</a>';
        grid.appendChild(card);
      });

      if (articles.length > 0 && extSec) {
        extSec.style.display = 'block';
        resetExtractionUI();
      }
    })
    .catch(function(err) { status.textContent = 'Error de red: ' + err.message; })
    .finally(function() {
      btn.disabled  = false;
      btn.innerHTML = '<i class="material-icons" style="font-size:18px;">search</i> Buscar noticias del día';
    });
  });
}

// ── Etapa 2: Extracción ──────────────────────────────────────────────────────
function resetExtractionUI() {
  ['progress-area', 'summary-area', 'download-area'].forEach(function(id) {
    var el = document.getElementById(id);
    if (el) el.style.display = 'none';
  });
  var btn = document.getElementById('extract-btn');
  if (btn) {
    btn.disabled  = false;
    btn.innerHTML = '<i class="material-icons" style="font-size:18px;">table_chart</i> Extraer datos';
  }
}

function getArticlesFromCards() {
  return Array.from(document.querySelectorAll('.news-card')).map(function(card) {
    var linkEl    = card.querySelector('.card-link');
    var titleEl   = card.querySelector('.card-title');
    var snippetEl = card.querySelector('.card-snippet');
    return {
      url:     linkEl    ? linkEl.href                  : '',
      title:   titleEl   ? titleEl.textContent.trim()   : '',
      snippet: snippetEl ? snippetEl.textContent.trim() : ''
    };
  }).filter(function(a) { return a.url; });
}

function initExtraction() {
  var extBtn = document.getElementById('extract-btn');
  if (!extBtn) return;

  extBtn.addEventListener('click', async function() {
    var articles = getArticlesFromCards();
    if (!articles.length) return;

    var extractUrl = extBtn.getAttribute('data-extract-url');
    var progArea   = document.getElementById('progress-area');
    var progMsg    = document.getElementById('progress-msg');
    var progBar    = document.getElementById('progress-bar');
    var summaryEl  = document.getElementById('summary-area');
    var downloadEl = document.getElementById('download-area');

    extBtn.disabled  = true;
    extBtn.innerHTML = '<span class="agent-spinner"></span> Procesando…';
    progArea.style.display   = 'block';
    summaryEl.style.display  = 'none';
    downloadEl.style.display = 'none';
    progBar.style.width      = '0%';

    var allRows    = [];
    var fmtErrors  = [];
    var stats = {
      total: articles.length, ok: 0, csvRows: 0,
      fetchError: 0, tituloExcluido: 0, snippetIrrelev: 0,
      claudeDescartar: 0, formatErrors: 0, errorInesp: 0
    };

    var batchSize    = 3;
    var totalBatches = Math.ceil(articles.length / batchSize);

    for (var i = 0; i < articles.length; i += batchSize) {
      var batch   = articles.slice(i, i + batchSize);
      var batchNo = Math.floor(i / batchSize) + 1;
      var done    = Math.min(i + batchSize, articles.length);

      progMsg.textContent = 'Procesando nota ' + done + ' de ' + articles.length +
                            ' (lote ' + batchNo + ' de ' + totalBatches + ')…';
      progBar.style.width = Math.round((i / articles.length) * 100) + '%';

      try {
        var resp = await fetch(extractUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken(),
            'Accept':       'application/json'
          },
          body: JSON.stringify({ articles: batch })
        });
        var data = await resp.json();

        if (data.error) {
          progMsg.textContent = 'Error del servidor: ' + data.error;
          extBtn.disabled  = false;
          extBtn.innerHTML = '<i class="material-icons" style="font-size:18px;">table_chart</i> Extraer datos';
          return;
        }

        (data.results || []).forEach(function(r) {
          switch (r.status) {
            case 'ok':
              stats.ok++;
              (r.csv_rows || []).forEach(function(rawRow) {
                var v = validateRow(rawRow, r.url);
                if (v.ok) {
                  allRows.push(v.cleaned);
                  stats.csvRows++;
                } else {
                  fmtErrors.push({ url: r.url, row: rawRow.substring(0, 120), error: v.error });
                  stats.formatErrors++;
                }
              });
              break;
            case 'discarded':
              if      (r.reason === 'fetch_error')         stats.fetchError++;
              else if (r.reason === 'titulo_excluido')     stats.tituloExcluido++;
              else if (r.reason === 'snippet_irrelevante') stats.snippetIrrelev++;
              else if (r.reason === 'claude_descartar')    stats.claudeDescartar++;
              else                                          stats.errorInesp++;
              break;
            default:
              stats.errorInesp++;
          }
        });
      } catch (err) {
        batch.forEach(function() { stats.errorInesp++; });
        console.error('Batch error:', err);
      }

      if (i + batchSize < articles.length) await sleep(1200);
    }

    progBar.style.width = '100%';
    progMsg.textContent = 'Extracción completada.';

    summaryEl.innerHTML = buildSummaryHTML(stats);
    summaryEl.style.display = 'block';

    offerDownloads(buildCSV(allRows), buildLog(stats, fmtErrors));

    extBtn.disabled  = false;
    extBtn.innerHTML = '<i class="material-icons" style="font-size:18px;">table_chart</i> Extraer datos';
  });
}

// ── Init ─────────────────────────────────────────────────────────────────────
function initAgentDetentions() {
  initSearch();
  initExtraction();
}

document.addEventListener('DOMContentLoaded', initAgentDetentions);
