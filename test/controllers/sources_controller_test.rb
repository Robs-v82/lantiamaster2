require 'test_helper'

class SourcesControllerTest < ActionDispatch::IntegrationTest
  test "should get twitter" do
    get sources_twitter_url
    assert_response :success
  end

end
