// Duplicates Dashboard JavaScript

function markAsDuplicate(duplicateId, keepId) {
  if (confirm(`¿Marcar registro #${duplicateId} como duplicado de #${keepId}?`)) {
    fetch(`/duplicates/${duplicateId}/mark_as_duplicate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        keep_id: keepId,
        reason: 'confirmed_duplicate'
      })
    })
    .then(r => r.json())
    .then(data => {
      alert(data.message || data.error);
      location.reload();
    })
    .catch(error => {
      alert('Error: ' + error.message);
    });
  }
}

function unmarkDuplicate(id) {
  if (confirm(`¿Desmarcar registro #${id} como duplicado?`)) {
    fetch(`/duplicates/${id}/unmark`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(r => r.json())
    .then(data => {
      alert(data.message || data.error);
      location.reload();
    })
    .catch(error => {
      alert('Error: ' + error.message);
    });
  }
}

function reviewDuplicate(id) {
  alert('Revisión manual para registro #' + id);
}

// Initialize event listeners when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Mark as duplicate buttons
  document.querySelectorAll('[data-action="mark-duplicate"]').forEach(btn => {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      const duplicateId = this.dataset.duplicateId;
      const keepId = this.dataset.keepId;
      markAsDuplicate(parseInt(duplicateId), parseInt(keepId));
    });
  });

  // Unmark duplicate buttons
  document.querySelectorAll('[data-action="unmark-duplicate"]').forEach(btn => {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      const id = this.dataset.recordId;
      unmarkDuplicate(parseInt(id));
    });
  });

  // Review duplicate buttons
  document.querySelectorAll('[data-action="review-duplicate"]').forEach(btn => {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      const id = this.dataset.recordId;
      reviewDuplicate(parseInt(id));
    });
  });

  // Refresh button
  const refreshBtn = document.querySelector('[data-action="refresh-analysis"]');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', function(e) {
      e.preventDefault();
      location.reload();
    });
  }
});
