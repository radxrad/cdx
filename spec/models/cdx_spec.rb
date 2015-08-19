require 'spec_helper'

describe Cdx do
  it "should provide a collection of fields" do
    expect(Cdx.core_fields.map(&:scoped_name).sort).to eq([
      "device.lab_user",
      "device.name",
      "device.serial_number",
      "device.uuid",
      "institution.uuid",
      "institution.name",
      "laboratory.uuid",
      "laboratory.name",
      "location.admin_levels",
      "location.id",
      "location.lat",
      "location.lng",
      "location.parents",
      "patient.gender",
      "patient.id",
      "sample.collection_date",
      "sample.id",
      "sample.type",
      "sample.uid",
      "sample.uuid",
      "test.assays",
      "test.end_time",
      "test.error_code",
      "test.error_description",
      "test.name",
      "test.patient_age",
      "test.reported_time",
      "test.start_time",
      "test.status",
      "test.type",
      "test.updated_time",
      "test.uuid",
      "test.id",
      "encounter.id",
      "encounter.uuid",
    ].sort)
  end
end
