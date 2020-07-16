class SourcesController < ApplicationController
  
  def twitter
  	@posts=Post.all
  end
  
end
