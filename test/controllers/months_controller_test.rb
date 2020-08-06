require 'test_helper'

class MonthsControllerTest < ActionDispatch::IntegrationTest
  test "should get reports" do
    get months_reports_url
    assert_response :success
  end

end
