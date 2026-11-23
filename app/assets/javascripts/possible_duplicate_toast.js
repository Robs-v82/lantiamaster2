/**
 * Toast explicativo para filas marcadas como posible duplicado (tabla provisional).
 * Se muestra al pasar el cursor sobre la fila y se cierra al salir de ella.
 */
(function () {
  'use strict';

  let activeToast = null;
  let activeRow = null;

  function escapeHtml(str) {
    return String(str || '').replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function closestDuplicateRow(target) {
    if (!target || !target.closest) return null;
    return target.closest('tr.possible-duplicate');
  }

  function dismissActiveToast() {
    if (activeToast && typeof activeToast.dismiss === 'function') {
      activeToast.dismiss();
    }
    activeToast = null;
    activeRow = null;
  }

  document.addEventListener('mouseover', function (e) {
    const row = closestDuplicateRow(e.target);
    if (!row || row === activeRow) return;

    dismissActiveToast();
    activeRow = row;

    if (!window.M || !M.toast) return;

    const note = row.getAttribute('data-dup-note') || 'Posible duplicado';
    activeToast = M.toast({
      html: escapeHtml(note),
      displayLength: Infinity,
      classes: 'amber darken-2'
    });
  });

  document.addEventListener('mouseout', function (e) {
    const row = closestDuplicateRow(e.target);
    if (!row) return;
    if (e.relatedTarget && row.contains(e.relatedTarget)) return;
    dismissActiveToast();
  });
})();
