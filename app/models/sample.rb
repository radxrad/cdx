class Sample < ApplicationRecord
  def self.institution_is_required
    false
  end

  include Entity
  include Resource
  include SpecimenRole
  include InactivationMethod
  include SiteContained
  include DateProduced

  belongs_to :patient
  belongs_to :encounter
  belongs_to :batch
  belongs_to :box
  belongs_to :qc_info

  has_many :sample_identifiers, inverse_of: :sample, dependent: :destroy
  has_many :test_results, through: :sample_identifiers

  has_many :samples_reports, through: :samples_report_samples
  has_many :samples_report_samples, dependent: :destroy

  has_many :assay_attachments, dependent: :destroy
  accepts_nested_attributes_for :assay_attachments, allow_destroy: true
  validates_associated :assay_attachments, message: "are invalid"

  has_many :notes, dependent: :destroy
  accepts_nested_attributes_for :notes, allow_destroy: true
  validates_associated :notes, message: "are invalid"

  validate :validate_encounter
  validate :validate_patient

  validates_numericality_of :concentration, only_integer: true, greater_than_or_equal: 0, allow_blank: true
  validates_numericality_of :replicate, only_integer: true, greater_than_or_equal_to: 0, allow_blank: true
  validates_inclusion_of :media, in: ->(_) { Sample.media }, allow_blank: true
  validate :validate_box_context, if: -> { box.present? }

  def validate_box_context
    errors.add(:institution, "must be the same as the box it is contained in") unless institution == box.institution
    errors.add(:site, "must be the same box it is contained in") unless site == box.site
  end

  def self.entity_scope
    "sample"
  end

  attribute_field :isolate_name, copy: true
  attribute_field :specimen_role, copy: true
  attribute_field :old_batch_number, copy: true
  attribute_field :date_produced,
                  :lab_technician,
                  :inactivation_method,
                  :volume,
                  :virus_lineage,
                  :concentration,
                  :replicate,
                  :media,
                  :measured_signal,
                  :reference_gene,
                  :target_organism_taxonomy_id,
                  :pango_lineage,
                  :who_label

  def self.find_by_entity_id(entity_id, opts)
    query = joins(:sample_identifiers).where(sample_identifiers: {entity_id: entity_id.to_s}, institution_id: opts.fetch(:institution_id))
    query = query.where(sample_identifiers: {site_id: opts[:site_id]}) if opts[:site_id]
    query.first
  end

  def self.find_by_uuid(uuid)
    joins(:sample_identifiers).where(sample_identifiers: {uuid: uuid}).take
  end

  def self.find_all_by_any_uuid(uuids)
    joins(:sample_identifiers).where(sample_identifiers: {uuid: uuids})
  end

  scope :autocomplete, ->(uuid) {
          if uuid.size == 36
            # Full UUID
            find_all_by_any_uuid(uuid)
          else
            # Partial UUID
            joins(:sample_identifiers).where("sample_identifiers.uuid LIKE concat(?, '%')", uuid)
          end
        }

  # Returns of samples with a stable order that isn't the original creation date
  # or the sample's auto-incremented id.
  scope :scrambled, -> {
    joins(:sample_identifiers).order("sample_identifiers.uuid")
  }

  scope :without_qc, -> { where.not(specimen_role: "q") }

  scope :without_results, ->() {
    where("samples.core_fields NOT LIKE '%measured_signal%'")
  }
  def self.media
    entity_fields.find { |f| f.name == 'media' }.options
  end

  def merge(other_sample)
    # Adds all sample_identifiers from other_sample if they have an uuid (ie they have been persisted)
    # or if they contain a new entity_id (ie not already in this sample.sample_identifiers)
    super
    self.sample_identifiers += other_sample.sample_identifiers.reject do |other_identifier|
      other_identifier.uuid.blank? && self.sample_identifiers.any? { |identifier| identifier.entity_id == other_identifier.entity_id }
    end
    self
  end

  def uuid=(value)
    # dummy setter needed by SampleForm
  end

  def uuid
    uuids.sort.first
  end

  def partial_uuid
    uuid.to_s[0..-5]
  end

  def entity_ids
    self.sample_identifiers.map(&:entity_id)
  end

  def uuids
    self.sample_identifiers.map(&:uuid)
  end

  def empty_entity?
    super && entity_ids.compact.empty?
  end

  def has_entity_id?
    entity_ids.compact.any?
  end

  def batch_number
    old_batch_number || batch.try(&:batch_number)
  end

  def has_qc_reference?
    !!(qc_info || (batch && batch.has_qc_sample?))
  end

  # Removes sample from its context when getting transferred.
  # It's added to the destination context when confirmed.
  def detach_from_context
    assign_attributes(
      batch: nil,
      old_batch_number: batch.try(:batch_number),
      site: nil,
      institution: nil
    )
  end

  def attach_qc_info
    if qc_info = batch.try(&:qc_info)
      self.qc_info = qc_info
    end
  end

  # Attribute fields don't convert numerical types.
  %w[replicate].each do |name|
    define_method name do
      core_fields[name].presence.try(&:to_i)
    end
  end

  # Fields accepting exponenciation (e.g. 1e8) first are converted to float then to integer.
  %w[concentration].each do |name|
    define_method name do
      core_fields[name].presence.try(&:to_f).try(&:to_i)
    end
  end

  def self.sort_columns
    ['updated_at']
  end

  def self.sort_column?(attr_name)
    sort_columns.include?(attr_name)
  end
end
