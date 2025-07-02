class NotesController < ApplicationController
  def create
    member = Member.find(params[:member_id])
    note = Note.new(story: params[:story])
    note.members << member

    if note.save
      redirect_back fallback_location: root_path, notice: "Nota añadida correctamente."
    else
      redirect_back fallback_location: root_path, alert: "No se pudo guardar la nota."
    end
  end
end
