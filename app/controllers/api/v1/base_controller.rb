module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_key!

      attr_reader :current_api_user

      # ✅ JSON estándar para cualquier 500 (evita páginas HTML)
      rescue_from StandardError do |e|
        Rails.logger.error("[API ERROR] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
        render_api_error(
          status: :internal_server_error,
          code: "internal_error",
          message: "Ocurrió un error interno. Contacta soporte con el request_id."
        )
      end

      private

      def api_version
        "v1"
      end

      def render_api_error(status:, code:, message:, meta: nil)
        payload = {
          request_id: request.request_id,
          status: Rack::Utils.status_code(status),
          errors: [{ code: code, message: message }],
          meta: (meta || {}).merge(api_version: api_version)
        }
        render json: payload, status: status
      end

      def authenticate_api_key!
        token = request.headers["X-API-KEY"].to_s.strip
        token = request.headers["Authorization"].to_s.sub(/^Bearer\s+/i, "").strip if token.blank?

        if token.blank?
          return render_api_error(
            status: :unauthorized,
            code: "unauthorized",
            message: "API key inválida o ausente."
          )
        end

        @current_api_user = User.find_by(api_key: token)
        if @current_api_user.nil? || @current_api_user.member.nil? || @current_api_user.member.organization.nil?
          return render_api_error(
            status: :unauthorized,
            code: "unauthorized",
            message: "API key inválida o usuario no autorizado."
          )
        end

        org = @current_api_user.member.organization
        if org.search_level.to_i <= 0
          return render_api_error(
            status: :forbidden,
            code: "forbidden",
            message: "Tu organización no tiene acceso activo a la API."
          )
        end
      end
    end
  end
end

