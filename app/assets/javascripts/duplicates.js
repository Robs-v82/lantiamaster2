// Duplicates Dashboard JavaScript

let selectedKeeperId = null;

function selectKeeper(keeperId) {
  console.log('[selectKeeper] Called with keeperId:', keeperId);
  selectedKeeperId = keeperId;
  console.log('[selectKeeper] selectedKeeperId set to:', selectedKeeperId);

  // Update UI to show selection
  document.querySelectorAll('.keeper-option').forEach(opt => {
    opt.classList.remove('selected');
  });

  const selectedOption = document.querySelector(`[data-keeper-id="${keeperId}"]`);
  if (selectedOption) {
    selectedOption.classList.add('selected');
    console.log('[selectKeeper] Visual selection applied to option:', keeperId);
  }

  // Enable confirm button
  const confirmBtn = document.getElementById('confirm-keeper-btn');
  if (confirmBtn) {
    confirmBtn.disabled = false;
    console.log('[selectKeeper] Confirm button enabled');
  }
}

function closeKeeperModal() {
  const modal = document.getElementById('keeperModal');
  const backdrop = document.getElementById('keeperModalBackdrop');

  if (modal) {
    modal.style.display = 'none';
    modal.classList.remove('show');
    modal.remove();
  }

  if (backdrop) {
    backdrop.remove();
  }

  document.body.style.overflow = 'auto';
  selectedKeeperId = null;
}

function confirmKeeper(duplicateId) {
  console.log('[confirmKeeper] Called with duplicateId:', duplicateId);
  console.log('[confirmKeeper] Current selectedKeeperId:', selectedKeeperId);

  if (selectedKeeperId) {
    // Save keeperId in local variable BEFORE closing modal
    const keeperId = selectedKeeperId;
    console.log('[confirmKeeper] Saved keeperId to local variable:', keeperId);
    console.log('[confirmKeeper] Condition passed, calling markAsDuplicate with:', {duplicateId, keeperId});

    closeKeeperModal();
    markAsDuplicate(duplicateId, keeperId);
  } else {
    console.warn('[confirmKeeper] selectedKeeperId is falsy:', selectedKeeperId);
  }
}

function openKeeperSelectionModal(duplicateId, otherRecords) {
  selectedKeeperId = null;

  // Create modal HTML without inline event handlers
  const keeperOptionsHtml = otherRecords.map(record => `
    <div class="keeper-option" data-keeper-id="${record.id}" style="
      cursor: pointer;
      padding: 15px;
      margin: 10px 0;
      border: 2px solid #ddd;
      border-radius: 4px;
      background-color: #f9f9f9;
      transition: all 0.3s ease;
    ">
      <strong style="font-size: 16px;">#${record.id}</strong> - ${record.nombre} ${record.apellido_paterno}
      <br><small style="color: #666; margin-top: 5px; display: block;">${record.municipio}, ${record.estado} | ${record.incident_date} | ${record.organizacion}</small>
    </div>
  `).join('');

  const modalHtml = `
    <div class="modal fade" id="keeperModal" tabindex="-1" role="dialog" aria-labelledby="keeperModalLabel" aria-hidden="true" style="display: none;">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header bg-info text-white">
            <h5 class="modal-title" id="keeperModalLabel">
              🔍 Selecciona el registro a conservar
            </h5>
            <button type="button" class="close" data-action="close-modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <p class="text-muted mb-3">
              Selecciona cuál de los siguientes registros es el "mejor" (el que quieres conservar).
              El registro <strong>#${duplicateId}</strong> será marcado como duplicado del que selecciones.
            </p>
            <div id="keeper-options">
              ${keeperOptionsHtml}
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-action="cancel-modal">Cancelar</button>
            <button type="button" class="btn btn-primary" id="confirm-keeper-btn" data-action="confirm-keeper" data-duplicate-id="${duplicateId}" disabled>
              Marcar como Duplicado
            </button>
          </div>
        </div>
      </div>
    </div>
  `;

  // Remove existing modal if any
  const existingModal = document.getElementById('keeperModal');
  if (existingModal) {
    existingModal.remove();
  }

  // Add new modal to DOM
  document.body.insertAdjacentHTML('beforeend', modalHtml);

  // Add CSS styles for selected state
  const style = document.createElement('style');
  style.textContent = `
    .keeper-option {
      cursor: pointer;
    }
    .keeper-option:hover:not(.selected) {
      border-color: #17a2b8 !important;
      background-color: #f0f8ff !important;
    }
    .keeper-option.selected {
      border-color: #17a2b8 !important;
      background-color: #e7f3f7 !important;
      box-shadow: 0 0 0 3px rgba(23, 162, 184, 0.1) !important;
    }
    .keeper-option.selected strong {
      color: #17a2b8;
    }
  `;
  document.head.appendChild(style);

  // Show modal backdrop
  const backdrop = document.createElement('div');
  backdrop.className = 'modal-backdrop fade show';
  backdrop.id = 'keeperModalBackdrop';
  document.body.appendChild(backdrop);

  // Show modal
  const modal = document.getElementById('keeperModal');
  modal.style.display = 'block';
  modal.classList.add('show');
  modal.setAttribute('aria-hidden', 'false');
  document.body.style.overflow = 'hidden';

  // Attach event listeners using event delegation (no setTimeout needed)
  // This is more reliable and doesn't depend on timing

  // Keeper option selection using event delegation on container
  const keeperOptionsContainer = document.getElementById('keeper-options');
  console.log('[openKeeperSelectionModal] keeperOptionsContainer:', keeperOptionsContainer);

  if (keeperOptionsContainer) {
    keeperOptionsContainer.addEventListener('click', function(e) {
      console.log('[keeperOptions.click] Event triggered on:', e.target);
      const option = e.target.closest('.keeper-option');
      console.log('[keeperOptions.click] Closest .keeper-option found:', option);

      if (option) {
        const keeperId = parseInt(option.getAttribute('data-keeper-id'));
        console.log('[keeperOptions.click] Extracted keeperId from data attribute:', keeperId);
        selectKeeper(keeperId);
      } else {
        console.log('[keeperOptions.click] No .keeper-option found in event target hierarchy');
      }
    });
  }

  // Close button
  const closeBtn = document.querySelector('[data-action="close-modal"]');
  if (closeBtn) {
    closeBtn.addEventListener('click', closeKeeperModal);
  }

  // Cancel button
  const cancelBtn = document.querySelector('[data-action="cancel-modal"]');
  if (cancelBtn) {
    cancelBtn.addEventListener('click', closeKeeperModal);
  }

  // Confirm button
  const confirmBtn = document.querySelector('[data-action="confirm-keeper"]');
  if (confirmBtn) {
    confirmBtn.addEventListener('click', function() {
      const duplicateId = parseInt(this.getAttribute('data-duplicate-id'));
      confirmKeeper(duplicateId);
    });
  }
}

function markAsDuplicate(duplicateId, keepId) {
  console.log('[markAsDuplicate] Called with:', {duplicateId, keepId});

  const payload = {
    keep_id: keepId,
    reason: 'manual_review'
  };

  console.log('[markAsDuplicate] Sending payload:', payload);
  console.log('[markAsDuplicate] JSON string:', JSON.stringify(payload));

  fetch(`/duplicates/${duplicateId}/mark_as_duplicate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
    },
    body: JSON.stringify(payload)
  })
  .then(r => {
    console.log('[markAsDuplicate] Response status:', r.status);
    return r.json();
  })
  .then(data => {
    console.log('[markAsDuplicate] Response data:', data);
    if (data.success) {
      alert(data.message);
      location.reload();
    } else {
      alert('Error: ' + (data.error || 'Unknown error'));
    }
  })
  .catch(error => {
    console.error('[markAsDuplicate] Error:', error);
    alert('Error: ' + error.message);
  });
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
      if (data.success) {
        alert(data.message);
        location.reload();
      } else {
        alert('Error: ' + (data.error || 'Unknown error'));
      }
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
      const duplicateId = parseInt(this.dataset.duplicateId);
      const otherRecordsJson = this.dataset.otherRecords;

      try {
        const otherRecords = JSON.parse(otherRecordsJson);
        openKeeperSelectionModal(duplicateId, otherRecords);
      } catch (error) {
        console.error('Error parsing other records JSON:', error);
        console.error('JSON string was:', otherRecordsJson);
        alert('Error loading duplicate options. Please try again.');
      }
    });
  });

  // Unmark duplicate buttons
  document.querySelectorAll('[data-action="unmark-duplicate"]').forEach(btn => {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      const id = parseInt(this.dataset.recordId);
      unmarkDuplicate(id);
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
