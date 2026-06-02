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

// ── CSV header ───────────────────────────────────────────────────────────────
var CSV_HEADER = 'Día,Mes,Año,Estado,INEGI,Municipio,Abatido,Detenidos,Organización,' +
  'Grupo afiliado,Nombre,Apellido Paterno,Apellido Materno,Alias,Género,Edad,' +
  'Posición liderazgo,Jefe regional,SEDENA,SEMAR,GN,SSCP,FGR,SSP-Estatal,' +
  'FGE/PGJ,Policía municipal,Otro,Fuente';

// ── Etapa 1: Búsqueda ────────────────────────────────────────────────────────
function initSearch() {
  var btn = document.getElementById('search-btn');
  if (!btn) return;

  btn.addEventListener('click', function() {
    var status = document.getElementById('status-msg');
    var grid   = document.getElementById('results-grid');
    var extSec = document.getElementById('extraction-section');

    btn.disabled    = true;
    btn.innerHTML   = '<span class="agent-spinner"></span> Buscando…';
    status.textContent = 'Lanzando 6 búsquedas en paralelo…';
    grid.innerHTML  = '';
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

      // Show extraction section if we have results
      if (articles.length > 0 && extSec) {
        extSec.style.display = 'block';
        resetExtractionUI();
      }
    })
    .catch(function(err) {
      status.textContent = 'Error de red: ' + err.message;
    })
    .finally(function() {
      btn.disabled  = false;
      btn.innerHTML = '<i class="material-icons" style="font-size:18px;">search</i> Buscar noticias del día';
    });
  });
}

// ── Etapa 2: Extracción ──────────────────────────────────────────────────────
function resetExtractionUI() {
  var prog     = document.getElementById('progress-area');
  var summary  = document.getElementById('summary-area');
  var download = document.getElementById('download-area');
  var extBtn   = document.getElementById('extract-btn');

  if (prog)     prog.style.display     = 'none';
  if (summary)  summary.style.display  = 'none';
  if (download) download.style.display = 'none';
  if (extBtn)   {
    extBtn.disabled  = false;
    extBtn.innerHTML = '<i class="material-icons" style="font-size:18px;">table_chart</i> Extraer datos';
  }
}

function getArticlesFromCards() {
  var cards = document.querySelectorAll('.news-card');
  return Array.from(cards).map(function(card) {
    var linkEl    = card.querySelector('.card-link');
    var titleEl   = card.querySelector('.card-title');
    var snippetEl = card.querySelector('.card-snippet');
    return {
      url:     linkEl    ? linkEl.href                   : '',
      title:   titleEl   ? titleEl.textContent.trim()    : '',
      snippet: snippetEl ? snippetEl.textContent.trim()  : ''
    };
  }).filter(function(a) { return a.url; });
}

function buildSummaryHTML(stats) {
  return '<h6>Resumen de extracción</h6>' +
    row('Total de notas encontradas',       stats.total,           false) +
    row('Notas procesadas exitosamente',    stats.ok,              false) +
    row('Filas CSV generadas',             stats.csvRows,          true)  +
    '<div style="margin-top:10px;font-weight:600;font-size:12px;color:#aaa;text-transform:uppercase;letter-spacing:.5px;">Descartadas por causa</div>' +
    row('Error de fetch o contenido vacío', stats.fetchError,      false) +
    row('Título con palabras excluidas',    stats.tituloExcluido,  false) +
    row('Snippet sin términos relevantes',  stats.snippetIrrelev,  false) +
    row('Claude: nota no es detención',     stats.claudeDescartar, false) +
    row('Error inesperado',                stats.errorInesp,       false);
}

function row(label, value, highlight) {
  return '<div class="summary-row">' +
    '<span class="summary-label">' + escHtml(label) + '</span>' +
    '<span class="summary-value' + (highlight ? ' highlight' : '') + '">' + value + '</span>' +
    '</div>';
}

function buildCSVContent(allRows, stats) {
  var lines = [CSV_HEADER].concat(allRows);
  var now   = new Date().toLocaleString('es-MX');
  lines.push('');
  lines.push('# === RESUMEN DE EJECUCIÓN ===');
  lines.push('# Total de notas encontradas: '                       + stats.total);
  lines.push('# Notas procesadas exitosamente: '                    + stats.ok);
  lines.push('# Filas CSV generadas: '                              + stats.csvRows);
  lines.push('# Descartadas por error de fetch o contenido vacío: ' + stats.fetchError);
  lines.push('# Descartadas por título excluido: '                  + stats.tituloExcluido);
  lines.push('# Descartadas por snippet irrelevante: '              + stats.snippetIrrelev);
  lines.push('# Descartadas por Claude (no es detención concreta): ' + stats.claudeDescartar);
  lines.push('# Descartadas por error inesperado: '                 + stats.errorInesp);
  lines.push('# Generado: ' + now);
  return lines.join('\n');
}

function triggerDownload(csvContent) {
  var today = new Date();
  var y     = today.getFullYear();
  var m     = String(today.getMonth() + 1).padStart(2, '0');
  var d     = String(today.getDate()).padStart(2, '0');
  var fname = 'detenciones_' + y + m + d + '.csv';

  var blob = new Blob(['﻿' + csvContent], { type: 'text/csv;charset=utf-8;' });
  var url  = URL.createObjectURL(blob);

  var btn  = document.getElementById('download-btn');
  btn.onclick = function() {
    var a      = document.createElement('a');
    a.href     = url;
    a.download = fname;
    a.click();
  };

  var downloadArea = document.getElementById('download-area');
  if (downloadArea) downloadArea.style.display = 'block';
}

function initExtraction() {
  var extBtn = document.getElementById('extract-btn');
  if (!extBtn) return;

  extBtn.addEventListener('click', async function() {
    var articles = getArticlesFromCards();
    if (articles.length === 0) return;

    var extractUrl = extBtn.getAttribute('data-extract-url');
    var prog       = document.getElementById('progress-area');
    var progMsg    = document.getElementById('progress-msg');
    var progBar    = document.getElementById('progress-bar');
    var summaryEl  = document.getElementById('summary-area');
    var downloadEl = document.getElementById('download-area');

    // Reset UI
    extBtn.disabled  = true;
    extBtn.innerHTML = '<span class="agent-spinner"></span> Procesando…';
    prog.style.display    = 'block';
    summaryEl.style.display  = 'none';
    downloadEl.style.display = 'none';
    progBar.style.width = '0%';

    var allRows = [];
    var stats   = { total: articles.length, ok: 0, csvRows: 0,
                    fetchError: 0, tituloExcluido: 0, snippetIrrelev: 0,
                    claudeDescartar: 0, errorInesp: 0 };

    var batchSize    = 3;
    var totalBatches = Math.ceil(articles.length / batchSize);

    for (var i = 0; i < articles.length; i += batchSize) {
      var batch      = articles.slice(i, i + batchSize);
      var batchNum   = Math.floor(i / batchSize) + 1;
      var processed  = Math.min(i + batchSize, articles.length);

      progMsg.textContent = 'Procesando nota ' + processed + ' de ' + articles.length +
                            ' (lote ' + batchNum + ' de ' + totalBatches + ')…';
      progBar.style.width = Math.round((i / articles.length) * 100) + '%';

      try {
        var resp = await fetch(extractUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken(),
            'Accept':       'application/json'
          },
          body: JSON.stringify({ articles: batch }),
          signal: AbortSignal.timeout ? AbortSignal.timeout(120000) : undefined
        });

        var data = await resp.json();
        (data.results || []).forEach(function(r) {
          switch (r.status) {
            case 'ok':
              stats.ok++;
              (r.csv_rows || []).forEach(function(row) {
                allRows.push(row);
                stats.csvRows++;
              });
              break;
            case 'discarded':
              if      (r.reason === 'fetch_error')          stats.fetchError++;
              else if (r.reason === 'titulo_excluido')      stats.tituloExcluido++;
              else if (r.reason === 'snippet_irrelevante')   stats.snippetIrrelev++;
              else if (r.reason === 'claude_descartar')      stats.claudeDescartar++;
              else                                           stats.errorInesp++;
              break;
            default:
              stats.errorInesp++;
          }
        });
      } catch (err) {
        // Batch error — count articles as errors
        batch.forEach(function() { stats.errorInesp++; });
        console.error('Batch error:', err);
      }

      // Delay between batches (not after the last one)
      if (i + batchSize < articles.length) {
        await sleep(1200);
      }
    }

    // Finalize progress
    progBar.style.width = '100%';
    progMsg.textContent = 'Extracción completada.';

    // Show summary
    summaryEl.innerHTML  = buildSummaryHTML(stats);
    summaryEl.style.display = 'block';

    // Generate and offer CSV download
    var csvContent = buildCSVContent(allRows, stats);
    triggerDownload(csvContent);

    // Restore button
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
