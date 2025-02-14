class BoxesController < ApplicationController
  before_action :load_box, except: %i[index new validate create bulk_destroy]

  def index
    @can_create = has_access?(@navigation_context.institution, CREATE_INSTITUTION_BOX)

    @boxes = Box.where(institution: @navigation_context.institution)
    @boxes = @boxes.where("uuid LIKE ?", params[:uuid] + "%") if params[:uuid].present?
    @boxes = @boxes.where(purpose: params[:purpose]) if params[:purpose].present?

    @boxes = check_access(@boxes, READ_BOX).order("boxes.created_at DESC")
    @boxes = @boxes.within(@navigation_context.entity, @navigation_context.exclude_subsites)
    @boxes = perform_pagination(@boxes)
  end

  def show
    return unless authorize_resource(@box, READ_BOX)
    @can_delete = has_access?(@box, DELETE_BOX)
    @can_blind = !@box.transferred?

    @samples = load_box_samples
  end

  def inventory
    return unless authorize_resource(@box, READ_BOX)
    return head :forbidden if params[:unblind] && @box.transferred?

    @samples = load_box_samples

    respond_to do |format|
      format.csv do
        @filename = "cdx_box_inventory_#{@box.uuid}.csv"
      end
    end
  end

  def print
    return unless authorize_resource(@box, READ_BOX)

    @samples = load_box_samples

    send_data BoxLabelPdf.render(@box, @samples),
      filename: "cdx_box_#{@box.uuid}",
      type: "application/pdf",
      disposition: "inline"
  end

  def new
    return unless authorize_resource(@navigation_context.institution, CREATE_INSTITUTION_BOX)

    @box_form = BoxForm.build(@navigation_context)
  end

  def validate
    @samples_count = 0
    batch_numbers = Set.new

    # TODO: should be handled by BoxForm (& duplicates BoxForm#parse_csv)
    CSV.open(params[:csv_box].path, headers: true) do |csv|
      unique_rows = Set.new
      csv.each do |row|

        unless csv.headers == ["Batch", "Concentration", "Distractor", "Instructions", "Replicates"]
          @error_message = "Invalid columns"
          return # rubocop:disable Lint/NonLocalExitFromIterator
        end

        if unique_rows.include?([row["Batch"], row["Concentration"], row["Distractor"], row["Instructions"]])
          @error_message = "Batch, Concentration, Distractor, Instructions must be unique"
          return # rubocop:disable Lint/NonLocalExitFromIterator
        end
        unique_rows << [row["Batch"], row["Concentration"], row["Distractor"], row["Instructions"]]

        if batch_number = row["Batch"].presence&.strip
          batch_numbers << batch_number
          @samples_count += row["Replicates"].to_i
        end
      end
    end

    @found_batches = @navigation_context.institution.batches.where(batch_number: batch_numbers.to_a).pluck(:batch_number)
    @not_found_batches = (batch_numbers - @found_batches)
  end

  def create
    return unless authorize_resource(@navigation_context.institution, CREATE_INSTITUTION_BOX)

    @box_form = BoxForm.build(@navigation_context, box_params)
    @box_form.batches = check_access(load_batches, READ_BATCH)
    @box_form.samples = check_access(load_samples, READ_SAMPLE)

    if @box_form.valid?
      @box_form.build_samples

      if @box_form.save
        redirect_to boxes_path, notice: "Box was successfully created."
        return
      end
    end

    render :new, status: :unprocessable_entity
  end

  def destroy
    return unless authorize_resource(@box, DELETE_BOX)

    @box.destroy
    redirect_to boxes_path, notice: "Box was successfully deleted."
  end

  def bulk_destroy
    boxes = Box.where(id: params[:box_ids])
    return unless authorize_resources(boxes, DELETE_BOX)

    boxes.destroy_all

    redirect_to boxes_path, notice: "Boxes were successfully deleted."
  end

  def unblind
    return head :forbidden if @box.transferred?
    @box.unblind!

    redirect_to box_path(@box), notice: "Samples were successfully unblinded."
  end

  def blind
    return head :forbidden if @box.transferred?
    @box.blind!

    redirect_to box_path(@box), notice: "Samples were successfully blinded."
  end

  private

  def load_box
    begin
      @box = Box.where(institution: @navigation_context.institution).find(params.fetch(:id))
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path
    end
  end

  def load_box_samples
    samples = @box.samples.preload(:batch, :sample_identifiers)
    samples = if @box.blinded? && !params[:unblind]
      samples.scrambled
    else
      samples.order(:id)
    end
    SamplePresenter.map(samples, request.format, unblind: params[:unblind])
  end

  def load_batches
    Batch
      .within(@navigation_context.entity, @navigation_context.exclude_subsites)
      .where(uuid: @box_form.batch_uuids.values.reject(&:blank?))
  end

  def load_samples
    Sample
      .within(@navigation_context.entity, @navigation_context.exclude_subsites)
      .where(box_id: nil)
      .find_all_by_any_uuid(@box_form.sample_uuids.values.reject(&:blank?))
  end

  def box_params
    if Rails::VERSION::MAJOR == 5 && Rails::VERSION::MINOR == 0
      params.require(:box).permit(:purpose, :media, :blinded, :option, :csv_box).tap do |allowed|
        allowed[:batches] = params[:box][:batches].try(&:permit!)
        allowed[:sample_uuids] = params[:box][:sample_uuids].try(&:permit!)
        allowed[:concentrations] = params[:box][:concentrations].try(&:permit!)
      end
    else
      params.require(:box)
        .permit(:purpose, :media, :blinded, :option, :csv_box, sample_uuids: [], batches: [
          :batch_uuid, :distractor, :instruction, concentrations: [:replicate, :concentration]
        ])
    end
  end
end
