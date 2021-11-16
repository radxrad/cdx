class BatchForm
  include ActiveModel::Model

  # shared editable attributes with model
  def self.shared_attributes
    [ :institution,
      :site,
      :batch_number,
      :date_produced,
      :lab_technician,
      :specimen_role,
      :isolate_name,
      :inactivation_method,
      :volume ]
  end

  def self.model_name
    Batch.model_name
  end

  def model_name
    self.class.model_name
  end

  def self.human_attribute_name(*args)
    # required to bind validations to active record i18n
    Batch.human_attribute_name(*args)
  end

  attr_accessor *shared_attributes
  attr_accessor :samples_quantity
  delegate :id, :new_record?, :persisted?, to: :batch

  def self.for(batch)
    new.tap do |form|
      form.batch = batch
    end
  end

  def batch
    @batch
  end

  def batch=(value)
    @batch = value
    self.class.assign_attributes(self, @batch)

    self.date_produced = if @batch.date_produced.is_a?(Time)
                           @batch.date_produced
                         else
                           Time.strptime(@batch.date_produced, date_format[:pattern]) rescue @batch.date_produced
                         end
  end

  def create
    batch.samples = self.samples_quantity.times.map { create_sample }
    save
  end

  def add_sample
    batch.samples.push create_sample
    save
  end

  def create_sample
    Sample.new({
      institution: self.institution,
      site: self.site,
      sample_identifiers: [SampleIdentifier.new],
      date_produced: self.date_produced,
      lab_technician: self.lab_technician,
      specimen_role: self.specimen_role,
      isolate_name: self.isolate_name,
      inactivation_method: self.inactivation_method,
      volume: self.volume
    })
  end

  def update(attributes, remove_sample_ids)
    attributes.each do |attr, value|
      self.send("#{attr}=", value)
    end

    @batch.samples.each do |sample|
      sample.mark_for_destruction if remove_sample_ids.include? sample.id
    end

    save
  end

  def save
    self.class.assign_attributes(batch, self)
    # we need to set a Time in batch instead of self.date_produced :: String
    batch.date_produced = @date_produced

    # validate forms. stop if invalid
    form_valid = self.valid?
    return false unless form_valid

    # validate/save. All done if succeeded
    is_valid = batch.save
    return true if is_valid

    # copy validations from model to form (form is valid, but model is not)
    batch.errors.each do |key, error|
      errors.add(key, error) if self.class.shared_attributes.include?(key)
    end
    return false
  end

  validates_numericality_of :samples_quantity, greater_than: 0, message: "value must be greater than 0", if: :creating_batch?

  def creating_batch?
    self.batch.id.nil?
  end

  # begin date_produced
  # @date_produced is Time | Nil | String.
  # BatchForm#date_produced will return always a string ready to be used by the user input with the user locale
  # BatchForm#date_produced= will accept either String or Time. The String will be converted if possible to a Time using the user locale

  def date_format
    { pattern: I18n.t('date.input_format.pattern'), placeholder: I18n.t('date.input_format.placeholder') }
  end

  def date_produced
    value = @date_produced

    if value.is_a?(Time)
      return value.strftime(date_format[:pattern])
    end

    value
  end

  def date_produced=(value)
    value = nil if value.blank?

    @date_produced = if value.is_a?(String)
      Time.strptime(value, date_format[:pattern]) rescue value
    else
      value
    end
  end

  def date_produced_placeholder
    date_format[:placeholder]
  end

  # end date_produced
  #

  private

  def self.assign_attributes(target, source)
    shared_attributes.each do |attr|
      target.send("#{attr}=", source.send(attr))
    end
  end
end
