$(document).ready(function() {
  console.log('monthly_captures.js loaded');
  console.log('Found link buttons:', $('.link-btn').length);
  console.log('Found edit buttons:', $('.edit-btn').length);
  console.log('Found delete buttons:', $('.delete-btn').length);

  // Initialize Materialize modals
  $('.modal').modal();

  // Link button handler
  $(document).on('click', '.link-btn', function() {
    console.log('Link button clicked');
    const url = $(this).data('url');
    console.log('URL:', url);
    if (url) {
      window.open(url, '_blank');
    }
  });

  // Edit button handler
  $(document).on('click', '.edit-btn', function() {
    console.log('Edit button clicked');
    const captureId = $(this).data('id');
    console.log('Capture ID:', captureId);
    const row = $(`tr[data-capture-id="${captureId}"]`);

    // Populate form with row data
    const cells = row.find('td');
    $('#captureId').val(captureId);
    $('#incident_date').val(cells.eq(1).text().split('/').reverse().join('-'));
    $('#estado').val(cells.eq(2).text());
    $('#municipio').val(cells.eq(3).text());
    $('#organizacion').val(cells.eq(5).text());
    $('#detenidos').val(cells.eq(6).text());
    $('#nombre').val(cells.eq(7).text());

    const editModalInstance = M.Modal.getInstance(document.getElementById('editModal'));
    editModalInstance.open();
  });

  // Delete button handler
  $(document).on('click', '.delete-btn', function() {
    console.log('Delete button clicked');
    const captureId = $(this).data('id');
    const row = $(`tr[data-capture-id="${captureId}"]`);
    const cells = row.find('td');

    const deleteInfo = `
      <div class="alert alert-info">
        <strong>Información a eliminar:</strong><br>
        Estado: ${cells.eq(2).text()}<br>
        Municipio: ${cells.eq(3).text()}<br>
        Organización: ${cells.eq(5).text()}<br>
        Nombre: ${cells.eq(7).text()}
      </div>
    `;

    $('#deleteInfo').html(deleteInfo);
    $('#confirmDeleteBtn').data('capture-id', captureId);

    const deleteModalInstance = M.Modal.getInstance(document.getElementById('deleteModal'));
    deleteModalInstance.open();
  });

  // Save changes
  $(document).on('click', '#saveBtn', function() {
    console.log('Save button clicked');
    const captureId = $('#captureId').val();
    const formData = new FormData($('#editForm')[0]);

    $.ajax({
      url: `/agent/detention_captures/${captureId}`,
      type: 'PATCH',
      data: formData,
      processData: false,
      contentType: false,
      success: function(response) {
        if (response.success) {
          const editModalInstance = M.Modal.getInstance(document.getElementById('editModal'));
          editModalInstance.close();
          alert('Captura actualizada exitosamente');
          location.reload();
        } else {
          alert('Error: ' + response.errors.join(', '));
        }
      },
      error: function(xhr) {
        alert('Error al actualizar la captura');
      }
    });
  });

  // Confirm delete
  $(document).on('click', '#confirmDeleteBtn', function() {
    console.log('Confirm delete button clicked');
    const captureId = $(this).data('capture-id');

    $.ajax({
      url: `/agent/detention_captures/${captureId}`,
      type: 'DELETE',
      dataType: 'json',
      success: function(response) {
        if (response.success) {
          const deleteModalInstance = M.Modal.getInstance(document.getElementById('deleteModal'));
          deleteModalInstance.close();
          alert('Captura eliminada exitosamente');
          location.reload();
        } else {
          alert('Error: ' + response.errors.join(', '));
        }
      },
      error: function(xhr) {
        alert('Error al eliminar la captura');
      }
    });
  });

  // Export button
  $(document).on('click', '#confirmExportBtn', function() {
    console.log('Export button clicked');
    alert('Exportación no disponible aún');
  });
});
