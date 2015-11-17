class Institution < ActiveRecord::Base
  include AutoUUID
  include Resource

  KINDS = %w(institution manufacturer health_organization)

  belongs_to :user

  has_many :sites, dependent: :destroy
  has_many :devices, dependent: :destroy
  has_many :device_models, dependent: :restrict_with_error, inverse_of: :institution
  has_many :encounters, dependent: :destroy
  has_many :patients, dependent: :destroy
  has_many :samples, dependent: :destroy
  has_many :test_results, dependent: :destroy

  validates_presence_of :name
  validates_presence_of :kind
  validates_inclusion_of :kind, in: KINDS

  after_create :update_owner_policies
  after_destroy :update_owner_policies

  def self.filter_by_owner(user, check_conditions)
    if check_conditions
      where(user_id: user.id)
    else
      self
    end
  end

  def filter_by_owner(user, check_conditions)
    user_id == user.id ? self : nil
  end

  def to_s
    name
  end

  KINDS.each do |kind|
    define_method "kind_#{kind}?" do
      self.kind.try(:to_s) == kind
    end
  end

  private

  def update_owner_policies
    self.user.try(:update_computed_policies)
  end

end
