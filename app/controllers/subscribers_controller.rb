class SubscribersController < ApplicationController
  include Concerns::SubscribersController

  respond_to :html, :json
  expose(:subscribers) do
    if params[:filter_id]
      current_user.filters.find(params[:filter_id]).subscribers
    else
      current_user.subscribers
    end
  end
  expose(:subscriber, attributes: :subscriber_params)
  expose(:filters) { current_user.filters }
  before_filter do
    head :forbidden unless has_access_to_test_results_index?
  end

  def index
    respond_with subscribers
  end

  def show
    respond_with subscriber
  end

  def edit
    @editing = true
  end

  def new
    subscriber.fields = []
  end

  def create
    subscriber.last_run_at = Time.now
    flash[:notice] = "Subscriber was successfully created" if subscriber.save
    respond_with subscriber, location: subscribers_path
  end

  def update
    flash[:notice] = "Subscriber was successfully updated" if subscriber.save
    respond_with subscriber, location: subscribers_path
  end

  def destroy
    subscriber.destroy
    respond_with subscriber
  end
end
