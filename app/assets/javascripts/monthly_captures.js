$(document).ready(function() {
  // Link button handler
  $('.link-btn').on('click', function() {
    const url = $(this).data('url');
    if (url) {
      window.open(url, '_blank');
    }
  });

  // Edit button handler
  $('.edit-btn').on('click', function() {
    const captureId = $(this).data('id');
    const row = $(`tr[data-capture-id="${captureId}"]`);

    // Populate form with row data
    const cells = row.find('td');
    $('#captureId').val(captureId);
    $('#incident_date').val(cells.eq(1).text().split('/').reverse().join('-')); // Convert DD/MM/YYYY to YYYY-MM-DD
    $('#estado').val(cells.eq(2).text());
    $('#municipio').val(cells.eq(3).text());
    $('#organizacion').val(cells.eq(5).text());
    $('#detenidos').val(cells.eq(6).text());
    $('#nombre').val(cells.eq(7).text());

    $('#editModal').modal('show');
  });

  // Delete button handler
  $('.delete-btn').on('click', function() {
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
    $('#deleteModal').modal('show');
  });

  // Save changes
  $('#saveBtn').on('click', function() {
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
  $('#confirmDeleteBtn').on('click', function() {
    const captureId = $(this).data('capture-id');

    $.ajax({
      url: `/agent/detention_captures/${captureId}`,
      type: 'DELETE',
      dataType: 'json',
      success: function(response) {
        if (response.success) {
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
  $('#confirmExportBtn').on('click', function() {
    // This would trigger the CSV generation
    alert('Exportación no disponible aún');
  });
});
