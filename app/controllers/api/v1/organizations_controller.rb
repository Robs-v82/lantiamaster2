module Api
  module V1
    class OrganizationsController < BaseController
      def criminal
        names = Sector.where(scian2: 98).last
                      .organizations
                      .where(active: true)
                      .uniq
                      .pluck(:name)
                      .sort

        render json: { organizations: names }, status: :ok
      end
    end
  end
end
