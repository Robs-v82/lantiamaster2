require 'test_helper'

class MembersControllerTest < ActionDispatch::IntegrationTest
  test "should get detentions" do
    get members_detentions_url
    assert_response :success
  end

end
