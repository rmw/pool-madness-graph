class PoolsController < ApplicationController
  before_action :authenticate_user!

  load_and_authorize_resource

  def index

  end
end