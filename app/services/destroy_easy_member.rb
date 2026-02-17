# app/services/destroy_easy_member.rb
class DestroyEasyMember
  Result = Struct.new(:ok?, :error, keyword_init: true)

  def self.call(member:)
    new(member).call
  end

  def initialize(member)
    @member = member
  end

  def call
    if @member.all_relationships.exists?
      return Result.new(
        ok?: false,
        error: "No se puede eliminar: el miembro tiene relaciones registradas."
      )
    end

    @member.destroy

    if @member.destroyed?
      Result.new(ok?: true, error: nil)
    else
      Result.new(ok?: false, error: @member.errors.full_messages.to_sentence.presence || "No se pudo eliminar el registro.")
    end
  rescue ActiveRecord::RecordNotFound
    Result.new(ok?: false, error: "No se encontró el miembro.")
  rescue => e
    Result.new(ok?: false, error: "Error al eliminar: #{e.message}")
  end
end