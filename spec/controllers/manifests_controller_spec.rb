require 'spec_helper'

describe ManifestsController do
  let(:user) {User.make}
  before(:each) {sign_in user}

  context "Creation" do

    it "shouldn't create if JSON is not valid" do
      json = {"definition" => %{
        { , , }
      } }
      Manifest.count.should eq(0)
      post :create, manifest: json
      Manifest.count.should eq(0)
    end

    it "should create if is a valid manifest" do
      json = {"definition" => %{{
        "metadata": {
          "version" : "1.0.0",
          "api_version" : "1.0.0",
          "device_models" : ["GX4001"],
          "source_data_type" : "json"
        },
        "field_mapping": [
          {
            "target_field": "assay_name",
            "source" : {"path" : "Test.assay_name"},
            "core" : true,
            "type" : "string"
          },
          {
            "target_field" : "test_type",
            "source" : {
              "mapping" : [
                {"path" : "Test.test_type"},
                [
                  {"match" : "*QC*", "output" : "qc"},
                  {"match" : "*Specimen*", "output" : "specimen"}
                ]
              ]
            },
            "core" : true,
            "type" : "enum",
            "options" : [
              "qc",
              "specimen"
            ]
          }
        ]
      }} }
      Manifest.count.should eq(0)
      post :create, manifest: json
      Manifest.count.should eq(1)
    end
  end
end


