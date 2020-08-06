require 'test_helper'

class DatasetsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get datasets_show_url
    assert_response :success
  end

end
