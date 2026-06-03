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

function generateRunId() {
  var d = new Date();
  return todayStr() + '_' +
    String(d.getHours()).padStart(2, '0') +
    String(d.getMinutes()).padStart(2, '0') +
    String(d.getSeconds()).padStart(2, '0');
}

// ── CSV header (col 18 = Rol) ────────────────────────────────────────────────
var CSV_HEADER = 'Día,Mes,Año,Estado,INEGI,Municipio,Abatido,Detenidos,Organización,' +
  'Grupo afiliado,Nombre,Apellido Paterno,Apellido Materno,Alias,Género,Edad,' +
  'Posición liderazgo,Rol,SEDENA,SEMAR,GN,SSCP,FGR,SSP-Estatal,' +
  'FGE/PGJ,Policía municipal,Otro,Fuente';

var NUMERIC_IDX = [0, 1, 2, 4, 6, 7, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26];

// ── CSV row parser ──────────────────────────────────────────────────────────
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

function reserializeFields(fields) {
  return fields.map(function(f) {
    return (f.indexOf(',') !== -1 || f.indexOf('"') !== -1)
      ? '"' + f.replace(/"/g, '""') + '"'
      : f;
  }).join(',');
}

// ── Row validator ────────────────────────────────────────────────────────────
function validateRow(rawLine, sourceUrl) {
  var line = rawLine.replace(/[\r\n]+/g, ' ').trim();
  if (!line) return { ok: false, error: 'Línea vacía' };

  var fields = parseCSVRow(line);

  if (fields.length === 29 && fields[27] === '' && fields[28].startsWith('http')) {
    fields.splice(27, 1);
    line = reserializeFields(fields);
  }

  if (fields.length !== 28) {
    return { ok: false, error: 'Campos: ' + fields.length + ' (esperado 28)' };
  }

  for (var i = 0; i < NUMERIC_IDX.length; i++) {
    var idx = NUMERIC_IDX[i];
    var val = fields[idx];
    if (val !== '' && isNaN(Number(val))) {
      return { ok: false, error: 'Campo numérico #' + (idx + 1) + ' tiene texto: "' + val + '"' };
    }
  }

  if (!fields[17]) {
    return { ok: false, error: 'Campo Rol (col 18) está vacío' };
  }

  if (!fields[27].startsWith('http')) {
    return { ok: false, error: 'Fuente no parece URL: "' + fields[27] + '"' };
  }

  return { ok: true, cleaned: line };
}

// ── CSV and Log builders ─────────────────────────────────────────────────────
function buildCSV(allRows) {
  return [CSV_HEADER].concat(allRows).join('\n');
}

var REASON_LABEL = {
  'fetch_error':         'Error de fetch o contenido vacío',
  'titulo_excluido':     'Título con palabras excluidas',
  'snippet_irrelevante': 'Snippet/URL sin términos relevantes',
  'claude_descartar':    'Claude: nota no describe detención concreta',
  'claude_error':        'Error al llamar a Claude',
  'unexpected_error':    'Error inesperado'
};

function buildLog(stats, formatErrors, articleLog, groupLog) {
  var now   = new Date().toLocaleString('es-MX');
  var runId = window._runId || todayStr();

  var lines = [
    '=== RESUMEN DE EJECUCIÓN ===',
    'ID de corrida: ' + runId,
    'Fecha y hora:  ' + now,
    'Tiempo total de procesamiento:           ' + (stats.totalProcessingTime || 'N/A'),
    '',
    'Total de artículos encontrados:          ' + (stats.total || 0),
    'Grupos únicos identificados:             ' + (groupLog ? groupLog.length : 0),
    'Grupos procesados exitosamente:          ' + (stats.ok || 0),
    'Filas CSV generadas:                     ' + (stats.csvRows || 0),
    '---',
    'Descartadas – error de fetch:            ' + (stats.fetchError || 0),
    'Descartadas – título excluido:           ' + (stats.tituloExcluido || 0),
    'Descartadas – snippet / URL:             ' + (stats.snippetIrrelev || 0),
    'Descartadas – Claude (no es detención):  ' + (stats.claudeDescartar || 0),
    'Errores de formato en filas:             ' + (stats.formatErrors || 0),
    'Duplicados eliminados:                   ' + (stats.duplicatesRemoved || 0),
    'Errores inesperados:                     ' + (stats.errorInesp || 0)
  ];

  if (groupLog && groupLog.length > 0) {
    lines.push('');
    lines.push('=== DETALLE POR GRUPO (' + groupLog.length + ' grupos) ===');

    groupLog.forEach(function(g, i) {
      var idx = String(i + 1).padStart(2, '0');
      var marker, detail;

      if (g.status === 'ok' && g.csvRows > 0) {
        marker = '✓ INCLUIDA (' + g.csvRows + ' fila' + (g.csvRows > 1 ? 's' : '') + ')';
        detail = null;
      } else if (g.status === 'ok' && g.csvRows === 0) {
        marker = '~ PROCESADA / SIN FILAS';
        detail = 'Claude respondió pero no generó filas válidas';
      } else if (g.status === 'fallback_partial') {
        marker = '⚠ PROCESADA PARCIALMENTE (fallback)';
        detail = 'Intentó ' + g.attempts + ' artículos del grupo, ' + g.csvRows + ' con éxito';
      } else if (g.status === 'fallback_failed') {
        marker = '✗ GRUPO RECHAZADO';
        detail = 'Todos los ' + g.attempts + ' artículos fallaron';
      } else {
        marker = '! ERROR';
        detail = g.reason || 'error desconocido';
      }

      lines.push('');
      lines.push('[' + idx + '] ' + marker);
      lines.push('     Tema: ' + (g.theme || 'desconocido'));
      lines.push('     Artículos: ' + (g.articleCount || 0));
      if (detail) lines.push('     → ' + detail);

      // Add timing information
      if (g.startTime && g.endTime && g.durationMs) {
        var durSec = (g.durationMs / 1000).toFixed(1);
        lines.push('     Tiempo: ' + g.startTime + ' → ' + g.endTime + ' (' + durSec + 's)');
      }

      if (g.fallbackLog && g.fallbackLog.length > 0) {
        g.fallbackLog.forEach(function(log) {
          lines.push('       ' + log);
        });
      }
    });
  }

  if (formatErrors && formatErrors.length > 0) {
    lines.push('');
    lines.push('=== ERRORES DE FORMATO EN FILAS ===');
    formatErrors.forEach(function(fe, i) {
      lines.push('');
      lines.push('[' + (i + 1) + '] URL: ' + fe.url);
      lines.push('    Fila: ' + fe.row);
      lines.push('    Motivo: ' + fe.error);
    });
  }

  return lines.join('\n');
}

function summaryRow(label, value, highlight) {
  return '<div class="summary-row">' +
    '<span class="summary-label">' + escHtml(label) + '</span>' +
    '<span class="summary-value' + (highlight ? ' highlight' : '') + '">' + value + '</span>' +
    '</div>';
}

function buildSummaryHTML(stats) {
  return '<h6>Resumen de extracción</h6>' +
    summaryRow('Grupos únicos identificados',        stats.groupsFound || 0, false) +
    summaryRow('Grupos procesados exitosamente',     stats.ok,               false) +
    summaryRow('Filas CSV generadas',                stats.csvRows,          stats.csvRows > 0) +
    '<div style="margin-top:10px;font-weight:600;font-size:12px;color:#aaa;text-transform:uppercase;letter-spacing:.5px;">Descartadas por causa</div>' +
    summaryRow('Error de fetch o contenido vacío',   stats.fetchError,       false) +
    summaryRow('Título con palabras excluidas',      stats.tituloExcluido,   false) +
    summaryRow('Snippet / URL sin términos relevantes', stats.snippetIrrelev, false) +
    summaryRow('Claude: nota no es detención',       stats.claudeDescartar,  false) +
    summaryRow('Errores de formato en filas',        stats.formatErrors,     stats.formatErrors > 0) +
    summaryRow('Duplicados eliminados',              stats.duplicatesRemoved || 0, (stats.duplicatesRemoved || 0) > 0) +
    summaryRow('Error inesperado',                   stats.errorInesp,       false);
}

function offerDownloads(csvContent, logContent) {
  var today = window._runId || todayStr();

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

    window._runId      = generateRunId();
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

// ── Etapa 2: Extracción con deduplicación ────────────────────────────────────
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
    extBtn.innerHTML = '<span class="agent-spinner"></span> Deduplicando…';
    progArea.style.display   = 'block';
    summaryEl.style.display  = 'none';
    downloadEl.style.display = 'none';
    progBar.style.width      = '0%';

    // Step 1: Deduplicate articles by theme
    progMsg.textContent = 'Agrupando artículos por tema (' + articles.length + ')…';

    var dedupeUrl = window.location.pathname.replace('/detentions', '') + '/detentions/deduplicate';

    try {
      var dedupeResp = await fetch(dedupeUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' },
        body: JSON.stringify({ articles: articles })
      });
      var dedupeData = await dedupeResp.json();

      if (dedupeData.error) {
        progMsg.textContent = 'Error en deduplicación: ' + dedupeData.error;
        extBtn.disabled  = false;
        extBtn.innerHTML = '<i class="material-icons" style="font-size:18px;">table_chart</i> Extraer datos';
        return;
      }

      var groups = dedupeData.groups || [];
      progMsg.textContent = 'Grupos identificados: ' + groups.length + '. Procesando…';
      await sleep(1000);

      // Step 2: Process groups with fallback
      await processGroupsWithFallback(groups, extractUrl, progMsg, progBar, summaryEl, downloadEl, extBtn);

    } catch (err) {
      progMsg.textContent = 'Error de red: ' + err.message;
      extBtn.disabled  = false;
      extBtn.innerHTML = '<i class="material-icons" style="font-size:18px;">table_chart</i> Extraer datos';
    }
  });
}

async function processGroupsWithFallback(groups, extractUrl, progMsg, progBar, summaryEl, downloadEl, extBtn) {
  var allRows     = [];
  var fmtErrors   = [];
  var groupLog    = [];
  var stats = {
    total: groups.reduce((sum, g) => sum + g.articles.length, 0),
    groupsFound: groups.length,
    ok: 0, csvRows: 0,
    fetchError: 0, tituloExcluido: 0, snippetIrrelev: 0,
    claudeDescartar: 0, formatErrors: 0, errorInesp: 0,
    duplicatesRemoved: 0
  };

  // DIAGNÓSTICO: Reordenar grupos para procesar La Razón primero
  // Buscar el grupo que contiene "colusión" o "transportista" (La Razón)
  var laRazonIndex = -1;
  for (var i = 0; i < groups.length; i++) {
    var theme = (groups[i].theme || '').toLowerCase();
    if (theme.includes('colusión') || theme.includes('transportista')) {
      laRazonIndex = i;
      break;
    }
  }
  if (laRazonIndex > 0) {
    // Mover La Razón al principio
    var laRazonGroup = groups.splice(laRazonIndex, 1)[0];
    groups.unshift(laRazonGroup);
    progMsg.textContent = '⚡ DIAGNÓSTICO: Procesando La Razón primero para verificar si es saturación...';
  }

  var processingStartTime = Date.now();

  for (var gi = 0; gi < groups.length; gi++) {
    var group = groups[gi];
    var groupArticles = group.articles || [];
    var groupStartTime = Date.now();
    var groupStartTimeStr = new Date().toLocaleTimeString('es-MX');

    progMsg.textContent = 'Procesando grupo ' + (gi + 1) + ' de ' + groups.length +
                          ' (' + group.theme + ', ' + groupArticles.length + ' artículo' + (groupArticles.length > 1 ? 's' : '') + ')…';
    progBar.style.width = Math.round((gi / groups.length) * 100) + '%';

    var groupResult = {
      theme: group.theme,
      articleCount: groupArticles.length,
      attempts: 0,
      csvRows: 0,
      status: 'fallback_failed',
      startTime: groupStartTimeStr,
      startMs: groupStartTime
    };

    // Try each article in the group with fallback
    var fallbackLog = [];
    for (var ai = 0; ai < groupArticles.length; ai++) {
      var article = groupArticles[ai];
      var attemptStartTime = Date.now();
      groupResult.attempts++;

      try {
        var resp = await fetch(extractUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken(),
            'Accept': 'application/json'
          },
          body: JSON.stringify({ articles: [article] })
        });
        var data = await resp.json();
        var attemptDuration = Date.now() - attemptStartTime;

        if (data.error) {
          fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': ' + data.error);
          continue;
        }

        var result = (data.results || [])[0];
        if (!result) {
          fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': sin resultado');
          continue;
        }

        if (result.status === 'ok' && result.csv_rows && result.csv_rows.length > 0) {
          // Success with this article
          stats.ok++;
          (result.csv_rows || []).forEach(function(rawRow) {
            var v = validateRow(rawRow, result.url);
            if (v.ok) {
              allRows.push(v.cleaned);
              stats.csvRows++;
              groupResult.csvRows++;
            } else {
              fmtErrors.push({ url: result.url, row: rawRow.substring(0, 120), error: v.error });
              stats.formatErrors++;
            }
          });
          groupResult.status = 'ok';
          fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': ÉXITO (' + result.csv_rows.length + ' filas)');
          break;
        }

        // Log detailed info for "ok" without rows
        if (result.status === 'ok' && (!result.csv_rows || result.csv_rows.length === 0)) {
          var contentInfo = result.content_length ? ' [contenido: ' + result.content_length + ' chars]' : '';
          var claudeRespInfo = result.claude_response_length ? ' [respuesta Claude: ' + result.claude_response_length + ' chars]' : '';
          var invalidINEGI = result.invalid_inegi_rows ? ' [' + result.invalid_inegi_rows.length + ' filas con INEGI inválido]' : '';

          var debugMsg = '';
          if (result.debug) {
            debugMsg = '\n    DEBUG: ' + result.debug.substring(0, 200).replace(/\n/g, ' ');
          }

          fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': ok (sin filas)' + contentInfo + claudeRespInfo + invalidINEGI + debugMsg);
        }

        if (result.status === 'discarded') {
          var discardMsg = result.reason;
          if (result.fetch_error_detail) discardMsg += ' — ' + result.fetch_error_detail;
          fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': descartada (' + discardMsg + ')');
        } else if (result.status === 'error') {
          var errorMsg = result.reason;
          if (result.error_detail) errorMsg += ' — ' + result.error_detail;

          // Smart throttling: si es rate_limit_error, esperar 60 segundos y reintentar
          if (result.reason === 'claude_error' && result.error_detail && result.error_detail.includes('rate_limit')) {
            fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] ⚠️ RATE LIMIT DETECTADO - Esperando 60 segundos antes de reintentar...');
            progMsg.textContent = 'Rate limit de Claude detectado. Esperando 60s antes de reintentar...';
            await sleep(60000);
            // Reintentar el mismo artículo
            ai--;
            continue;
          }

          fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': error (' + errorMsg + ')');
        } else {
          fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': ' + result.status);
        }
      } catch (err) {
        var attemptDuration = Date.now() - attemptStartTime;
        fallbackLog.push('  [' + (attemptDuration/1000).toFixed(1) + 's] Intento ' + (ai + 1) + '/' + groupArticles.length + ': ' + err.message);
        continue;
      }

      if (ai < groupArticles.length - 1) await sleep(2000); // Delay between fallback attempts
    }
    groupResult.fallbackLog = fallbackLog;

    // Finalize group status
    if (groupResult.status === 'ok' && groupResult.csvRows === 0) {
      groupResult.status = 'ok';
    } else if (groupResult.csvRows > 0) {
      groupResult.status = 'ok';
    } else if (groupResult.attempts > 1) {
      groupResult.status = 'fallback_failed';
    }

    var groupDuration = Date.now() - groupStartTime;
    var groupEndTimeStr = new Date().toLocaleTimeString('es-MX');
    groupResult.endTime = groupEndTimeStr;
    groupResult.durationMs = groupDuration;

    groupLog.push(groupResult);
    await sleep(5000); // Large delay between groups to rule out Claude saturation (5 seconds)
  }

  // Deduplicar por contenido exacto
  var seenRows = new Set();
  var beforeDedup = allRows.length;
  allRows = allRows.filter(function(row) {
    if (seenRows.has(row)) return false;
    seenRows.add(row);
    return true;
  });
  stats.duplicatesRemoved = beforeDedup - allRows.length;
  stats.csvRows = allRows.length;

  var totalProcessingTime = Date.now() - processingStartTime;
  stats.totalProcessingTime = (totalProcessingTime / 1000).toFixed(1) + 's';

  progBar.style.width = '100%';
  progMsg.textContent = 'Extracción completada en ' + stats.totalProcessingTime + '.';

  summaryEl.innerHTML = buildSummaryHTML(stats);
  summaryEl.style.display = 'block';

  // Persist for manual URL additions
  window._csvAllRows   = allRows;
  window._logStats     = stats;
  window._logFmtErrors = fmtErrors;
  window._groupLog     = groupLog;

  offerDownloads(buildCSV(allRows), buildLog(stats, fmtErrors, null, groupLog));

  extBtn.disabled  = false;
  extBtn.innerHTML = '<i class="material-icons" style="font-size:18px;">table_chart</i> Extraer datos';
}

// ── URL manual ───────────────────────────────────────────────────────────────
function initManualUrl() {
  var btn    = document.getElementById('manual-url-btn');
  var input  = document.getElementById('manual-url-input');
  var status = document.getElementById('manual-url-status');
  if (!btn || !input) return;

  btn.addEventListener('click', async function() {
    var url = input.value.trim();
    if (!url.startsWith('http')) {
      status.textContent = 'Introduce una URL válida.';
      return;
    }

    var extractUrl = input.getAttribute('data-extract-url');
    btn.disabled       = true;
    btn.innerHTML      = '<span class="agent-spinner"></span>';
    status.textContent = 'Procesando…';

    try {
      var resp = await fetch(extractUrl, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' },
        body:    JSON.stringify({ url: url })
      });
      var data = await resp.json();
      if (data.error) { status.textContent = 'Error: ' + data.error; return; }

      var result = (data.results || [])[0];
      if (!result) { status.textContent = 'Sin respuesta del servidor.'; return; }

      if (result.status === 'discarded') {
        status.textContent = 'Descartada (' + result.reason + '). No es una detención concreta.';
        return;
      }
      if (result.status === 'error') {
        status.textContent = 'Error al procesar: ' + result.reason;
        return;
      }

      var added = 0;
      var fmtErrs = [];
      (result.csv_rows || []).forEach(function(rawRow) {
        var v = validateRow(rawRow, url);
        if (v.ok) {
          window._manualRows = window._manualRows || [];
          window._manualRows.push(v.cleaned);
          added++;
        } else {
          fmtErrs.push(v.error);
        }
      });

      if (added > 0) {
        status.style.color = '#2e7d32';
        status.textContent = '✓ ' + added + ' fila(s) añadida(s). Descarga el CSV actualizado abajo.';

        var existingRows = window._csvAllRows || [];
        window._csvAllRows = existingRows.concat(window._manualRows);
        window._manualRows = [];
        offerDownloads(
          buildCSV(window._csvAllRows),
          buildLog(window._logStats || {}, window._logFmtErrors || [], null, window._groupLog || [])
        );
        var downloadEl = document.getElementById('download-area');
        if (downloadEl) downloadEl.style.display = 'flex';
        input.value = '';
      } else {
        status.textContent = fmtErrs.length
          ? 'Filas rechazadas por formato: ' + fmtErrs.join('; ')
          : 'Claude no generó filas para esta URL.';
      }
    } catch (err) {
      status.textContent = 'Error de red: ' + err.message;
    } finally {
      btn.disabled  = false;
      btn.innerHTML = '<i class="material-icons" style="font-size:16px;">add_link</i> Agregar y extraer';
    }
  });
}

// ── Init ─────────────────────────────────────────────────────────────────────
function initAgentDetentions() {
  initSearch();
  initExtraction();
  initManualUrl();
}

document.addEventListener('DOMContentLoaded', initAgentDetentions);
