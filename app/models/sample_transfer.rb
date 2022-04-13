class SampleTransfer < ApplicationRecord
  belongs_to :sample
  belongs_to :sender_institution, class_name: "Institution"
  belongs_to :receiver_institution, class_name: "Institution"
  belongs_to :transfer_package

  # TODO: remove these after upgrading to Rails 5.0 (belongs_to associations are required by default):
  validates_presence_of :sample

  after_initialize do
    self.sender_institution ||= sample.try &:institution
  end

  scope :within, ->(institution) {
          joins(:transfer_package).merge(TransferPackage.within(institution))
        }

  scope :with_receiver, ->(institution) {
          joins(:transfer_package).merge(TransferPackage.with_receiver(institution))
        }

  scope :ordered_by_creation, -> {
          order(created_at: :desc)
        }

  delegate :receiver_institution, :sender_institution, to: :transfer_package

  def confirm
    if confirmed?
      false
    else
      self.confirmed_at = Time.now
      true
    end
  end

  def confirm!
    if confirm
      save!
    else
      raise ActiveRecord::RecordNotSaved.new("Sample transfer has already been confirmed.")
    end
  end

  def confirm_and_apply
    if confirm
      save!
      sample.update!(institution: receiver_institution)
      true
    else
      false
    end
  end

  def confirm_and_apply!
    confirm!
    sample.update!(institution: receiver_institution)

    nil
  end

  def confirmed?
    !!confirmed_at
  end
end
