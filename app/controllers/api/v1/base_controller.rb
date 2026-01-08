module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_key!

      attr_reader :current_api_user

      # ✅ JSON estándar para cualquier 500 (evita páginas HTML)
      rescue_from StandardError do |e|
        Rails.logger.error("[API ERROR] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")

        render json: {
          request_id: request.request_id,
          status: 500,
          errors: [
            {
              code: "internal_error",
              message: "Ocurrió un error interno. Contacta soporte con el request_id."
            }
          ]
        }, status: :internal_server_error
      end

      private

      def authenticate_api_key!
        token = request.headers["X-API-KEY"].to_s.strip
        token = request.headers["Authorization"].to_s.sub(/^Bearer\s+/i, "").strip if token.blank?

        if token.blank?
          return render json: {
            request_id: request.request_id,
            status: 401,
            errors: [{ code: "unauthorized", message: "API key inválida o ausente." }]
          }, status: :unauthorized
        end

        @current_api_user = User.find_by(api_key: token)

        unless @current_api_user
          return render json: {
            request_id: request.request_id,
            status: 401,
            errors: [{ code: "unauthorized", message: "API key inválida o ausente." }]
          }, status: :unauthorized
        end
      end
    end
  end
end
