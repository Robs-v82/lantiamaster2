require 'test_helper'

class QuartersControllerTest < ActionDispatch::IntegrationTest
  test "should get ispyv" do
    get quarters_ispyv_url
    assert_response :success
  end

end
