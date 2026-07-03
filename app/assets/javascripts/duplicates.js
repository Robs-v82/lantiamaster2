// Duplicates Dashboard JavaScript

let selectedKeeperId = null;

function selectKeeper(keeperId) {
  selectedKeeperId = keeperId;

  // Update UI to show selection
  document.querySelectorAll('.keeper-option').forEach(opt => {
    opt.classList.remove('selected');
  });

  const selectedOption = document.querySelector(`[data-keeper-id="${keeperId}"]`);
  if (selectedOption) {
    selectedOption.classList.add('selected');
  }

  // Enable confirm button
  const confirmBtn = document.getElementById('confirm-keeper-btn');
  if (confirmBtn) {
    confirmBtn.disabled = false;
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
  if (selectedKeeperId) {
    closeKeeperModal();
    markAsDuplicate(duplicateId, selectedKeeperId);
  }
}

function openKeeperSelectionModal(duplicateId, otherRecords) {
  selectedKeeperId = null;

  // Create modal HTML
  const keeperOptionsHtml = otherRecords.map(record => `
    <div class="keeper-option" data-keeper-id="${record.id}" onclick="selectKeeper(${record.id})" style="
      cursor: pointer;
      padding: 15px;
      margin: 10px 0;
      border: 2px solid #ddd;
      border-radius: 4px;
      background-color: #f9f9f9;
      transition: all 0.3s ease;
    " onmouseover="this.style.borderColor='#17a2b8'; this.style.backgroundColor='#f0f8ff';" onmouseout="if (!this.classList.contains('selected')) { this.style.borderColor='#ddd'; this.style.backgroundColor='#f9f9f9'; }">
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
            <button type="button" class="close" onclick="closeKeeperModal()" aria-label="Close">
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
            <button type="button" class="btn btn-secondary" onclick="closeKeeperModal()">Cancelar</button>
            <button type="button" class="btn btn-primary" id="confirm-keeper-btn" onclick="confirmKeeper(${duplicateId})" disabled>
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
  document.body.style.overflow = 'hidden';

  // Add event listeners to keeper options using event delegation
  setTimeout(() => {
    const keeperOptions = document.querySelectorAll('.keeper-option');
    keeperOptions.forEach(option => {
      option.addEventListener('click', function() {
        const keeperId = parseInt(this.getAttribute('data-keeper-id'));
        selectKeeper(keeperId);
      });
    });
  }, 0);
}

function markAsDuplicate(duplicateId, keepId) {
  fetch(`/duplicates/${duplicateId}/mark_as_duplicate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
    },
    body: JSON.stringify({
      keep_id: keepId,
      reason: 'manual_review'
    })
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
