require 'spec_helper'
require 'policy_spec_helper'

RSpec.describe BatchesController, type: :controller do
  setup_fixtures do
    @user = User.make!
    @institution = Institution.make! user: @user
    @other_user = Institution.make!.user
  end

  before(:each)        { sign_in user }
  let(:default_params) { {context: institution.uuid} }

  before(:each) {
    grant user, other_user, institution, READ_INSTITUTION
  }

  context "index" do
    it "should be accessible by institution owner" do
      get :index
      expect(response).to be_success
    end

    it "should list batches if can read" do
      Batch.make! institution: institution
      get :index
      expect(assigns(:batches).count).to eq(1)
    end

    it "should not list batches if can not read" do
      Batch.make! institution: institution
      sign_in other_user
      get :index
      expect(assigns(:batches).count).to eq(0)
    end

    it "can create if admin" do
      get :index
      expect(assigns(:can_create)).to be_truthy
    end

    it "can create if allowed" do
      grant user, other_user, institution, CREATE_INSTITUTION_BATCH
      sign_in other_user
      get :index
      expect(assigns(:can_create)).to be_truthy
    end

    it "can not create if not allowed" do
      sign_in other_user
      get :index
      expect(assigns(:can_create)).to be_falsy
    end

    it "should filter by Isolate Name" do
      Batch.make! institution: institution, batch_number: '123', isolate_name: 'ABC.42'
      Batch.make! institution: institution, batch_number: '456', isolate_name: 'DEF.24'
      Batch.make! institution: institution, batch_number: '789', isolate_name: 'GHI.42'

      get :index, params: { isolate_name: '42' }
      expect(response).to be_success
      expect(assigns(:batches).count).to eq(2)
    end

    it "should filter by Batch Number" do
      Batch.make! institution: institution, batch_number: '7788'
      Batch.make! institution: institution, batch_number: '8877'
      Batch.make! institution: institution, batch_number: '0123'

      get :index, params: { batch_number: '88' }
      expect(response).to be_success
      expect(assigns(:batches).count).to eq(2)
    end

    it "should filter by Sample ID" do
      batch = Batch.make! institution: institution, batch_number: '7788'
      Sample.make! batch: batch, sample_identifiers: [SampleIdentifier.make!(uuid: '01234567-8ce1-a0c8-ac1b-58bed3633e88')]

      get :index, params: { sample_id: '88' }
      expect(response).to be_success
      expect(assigns(:batches).count).to eq(1)
    end
  end

  context "autocomplete" do
    let(:batch) { Batch.make! institution: institution }

    it "should be accessible by institution owner" do
      get :autocomplete, params: { query: batch.batch_number, format: "json" }
      expect(response).to have_http_status(:ok)
      expect(response).to be_success
    end

    it "should list batches if can read" do
      grant user, other_user, batch, READ_BATCH
      sign_in other_user

      get :autocomplete, params: { query: batch.batch_number, format: "json" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it "should not list batches if can not read" do
      sign_in other_user

      get :autocomplete, params: { query: batch.batch_number, format: "json" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(0)
    end

    it "autocompletes batch number" do
      Batch.make! institution: institution, batch_number: "virus.limit"
      Batch.make! institution: institution, batch_number: "limit.virus"
      Batch.make! institution: institution, batch_number: "something else"

      get :autocomplete, params: { query: "virus", format: "json" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(2)

      get :autocomplete, params: { query: "else", format: "json" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it "in context" do
      site = Site.make! institution: institution
      batch = Batch.make! institution: institution, site: site

      get :autocomplete, params: { context: "#{site.uuid}-*", query: batch.batch_number, format: "json" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

  context "edit_or_show" do
    let!(:batch) { Batch.make! institution: institution }

    it "redirects to edit when user has UPDATE_BATCH permission" do
      get :edit_or_show, params: { id: batch.id }
      expect(response).to redirect_to(edit_batch_path(batch))
    end

    it "redirects to show when user doesn't have UPDATE_BATCH permission" do
      sign_in other_user

      get :edit_or_show, params: { id: batch.id }
      expect(response).to redirect_to(batch_path(batch))
    end
  end

  context "show" do
    let!(:batch) { Batch.make! institution: institution }

    it "should be accessible to institution owner" do
      get :show, params: { id: batch.id }
      expect(response).to be_success
    end

    it "shouldn't be accessible to anybody" do
      sign_in other_user

      get :show, params: { id: batch.id }
      expect(response).to be_forbidden
    end
  end

  context "new" do
    it "should be accessible be institution owner" do
      get :new
      expect(response).to be_success
    end

    it "should be allowed it can create" do
      grant user, other_user, institution, CREATE_INSTITUTION_BATCH
      sign_in other_user
      get :new
      expect(response).to be_success
    end

    it "should not be allowed it can not create" do
      sign_in other_user
      get :new
      expect(response).to be_forbidden
    end
  end

  context "create" do
    let(:batch_form_plan) {
      { batch_number: '123',
        isolate_name: 'ABC.42',
        date_produced: '08/08/2018',
        lab_technician: 'Tec.Foo',
        specimen_role: 'q',
        inactivation_method: 'Formaldehyde',
        volume: '100',
        samples_quantity: '1'
      }
    }

    let!(:batch) { Batch.make!(
      institution: institution,
      batch_number: '1234',
      isolate_name: 'ABC.424',
      date_produced: Time.zone.local(2021, 8, 8),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 100
    )}

    def build_batch_form_plan(options)
      batch_form_plan.dup.merge! options
    end

    it "should create new batch in context institution" do
      expect {
        post :create, params: { batch: batch_form_plan }
      }.to change(institution.batches, :count).by(1)

      expect(response).to redirect_to batches_path
    end

    it "should save fields" do
      post :create, params: { batch: batch_form_plan }
      batch = institution.batches.last

      expect(batch.batch_number).to eq(batch_form_plan[:batch_number])
      expect(batch.isolate_name).to eq(batch_form_plan[:isolate_name])
      expect(batch.date_produced).to eq(batch_form_plan[:date_produced])
      expect(batch.lab_technician).to eq(batch_form_plan[:lab_technician])
      expect(batch.specimen_role).to eq(batch_form_plan[:specimen_role])
      expect(batch.inactivation_method).to eq(batch_form_plan[:inactivation_method])
      expect(batch.volume).to eq(batch_form_plan[:volume])

      # samples created (see samples_quantity)
      expect(batch.samples.count).to eq(1)

      expect(batch.core_fields['batch_number']).to eq(batch_form_plan[:batch_number])
      expect(batch.core_fields['isolate_name']).to eq(batch_form_plan[:isolate_name])
      expect(batch.core_fields['date_produced']).to eq(batch_form_plan[:date_produced])
      expect(batch.core_fields['lab_technician']).to eq(batch_form_plan[:lab_technician])
      expect(batch.core_fields['specimen_role']).to eq(batch_form_plan[:specimen_role])
      expect(batch.core_fields['inactivation_method']).to eq(batch_form_plan[:inactivation_method])
      expect(batch.core_fields['volume']).to eq(batch_form_plan[:volume])
    end

    it "creates with optional attributes" do
      post :create, params: { batch: batch_form_plan.merge(
        virus_lineage: "B.1.1.529"
      ) }
      expect(response).to have_http_status(:redirect)

      batch = institution.batches.last
      expect(batch.virus_lineage).to eq("B.1.1.529")
    end

    it "should create new batch in context institution if allowed" do
      grant user, other_user, institution, CREATE_INSTITUTION_BATCH
      sign_in other_user

      expect {
        post :create, params: { batch: batch_form_plan }
      }.to change(institution.batches, :count).by(1)
    end

    it "should not create new batch in context institution if not allowed" do
      sign_in other_user

      expect {
        post :create, params: { batch: batch_form_plan }
      }.to change(institution.batches, :count).by(0)

      expect(response).to be_forbidden
    end

    it "should require date_produced" do
      expect {
        post :create, params: { batch: build_batch_form_plan(date_produced: '') }
      }.to change(institution.batches, :count).by(0)

      expect(assigns(:batch_form).errors).to have_key(:date_produced)
      expect(response).to render_template("batches/new")
    end

    it "should require isolate_name" do
      expect {
        post :create, params: { batch: build_batch_form_plan(isolate_name: '') }
      }.to change(institution.batches, :count).by(0)

      expect(assigns(:batch_form).errors).to have_key(:isolate_name)
      expect(response).to render_template("batches/new")
    end

    it "should require batch_number" do
      expect {
        post :create, params: { batch: build_batch_form_plan(batch_number: '') }
      }.to change(institution.batches, :count).by(0)

      expect(assigns(:batch_form).errors).to have_key(:batch_number)
      expect(response).to render_template("batches/new")
    end

    it "should validate date_produced" do
      expect {
        post :create, params: { batch: build_batch_form_plan(date_produced: '31/31/3100') }
      }.to change(institution.batches, :count).by(0)

      expect(assigns(:batch_form).errors).to have_key(:date_produced)
      expect(response).to render_template("batches/new")
    end

    it "should require lab_technician" do
      expect {
        post :create, params: { batch: build_batch_form_plan(lab_technician: '') }
      }.to change(institution.batches, :count).by(0)

      expect(assigns(:batch_form).errors).to have_key(:lab_technician)
      expect(response).to render_template("batches/new")
    end

    it "should require inactivation_method" do
      expect {
        post :create, params: { batch: build_batch_form_plan(inactivation_method: '') }
      }.to change(institution.batches, :count).by(0)

      expect(assigns(:batch_form).errors).to have_key(:inactivation_method)
      expect(response).to render_template("batches/new")
    end

    it "should require volume" do
      expect {
        post :create, params: { batch: build_batch_form_plan(volume: '') }
      }.to change(institution.batches, :count).by(0)

      expect(assigns(:batch_form).errors).to have_key(:volume)
      expect(response).to render_template("batches/new")
    end

    it "should not require specimen_role" do
      expect {
        post :create, params: { batch: build_batch_form_plan(specimen_role: '') }
      }.to change(institution.batches, :count).by(1)

      batch = institution.batches.last
      expect(batch.specimen_role).to be_nil
      expect(response).to redirect_to batches_path
    end

    it "should validate batch_number and isolate_name uniqueness" do
      expect {
        post :create, params: { batch: build_batch_form_plan(batch_number: batch.batch_number, isolate_name: batch.isolate_name) }
      }.to change(institution.batches, :count).by(0)

      expect(response).to render_template("batches/new")
    end

    it "should validate batch_number (exists) and isolate_name uniqueness" do
      expect {
        post :create, params: { batch: build_batch_form_plan(batch_number: batch.batch_number, isolate_name: 'DEF.24') }
      }.to change(institution.batches, :count).by(1)

      expect(response).to redirect_to batches_path
    end

    it "should validate batch_number (exists) and isolate_name uniqueness (case insensitive)" do
      expect {
        post :create, params: { batch: build_batch_form_plan(batch_number: batch.batch_number.upcase, isolate_name: "DEF.24") }
      }.to change(institution.batches, :count).by(1)

      expect(response).to redirect_to batches_path
    end

    it "should validate batch_number and isolate_name (exists) uniqueness" do
      expect {
        post :create, params: { batch: build_batch_form_plan(batch_number: '456', isolate_name: batch.isolate_name) }
      }.to change(institution.batches, :count).by(1)

      expect(response).to redirect_to batches_path
    end

    it "should validate batch_number and isolate_name (exists) uniqueness (case insensitive)" do
      expect {
        post :create, params: { batch: build_batch_form_plan(batch_number: "456", isolate_name: batch.isolate_name.upcase) }
      }.to change(institution.batches, :count).by(1)

      expect(response).to redirect_to batches_path
    end
  end

  context "edit" do
    let!(:batch) { Batch.make!(
      institution: institution,
      batch_number: '123',
      isolate_name: 'ABC.42',
      date_produced: Time.zone.local(2018, 1, 1),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 100
    )}

    it "should be accessible by institution owner" do
      get :edit, params: { id: batch.id }
      expect(response).to be_success
      expect(assigns(:can_delete)).to be_truthy
    end

    it "should be accessible if can edit" do
      grant user, other_user, Batch, UPDATE_BATCH
      sign_in other_user

      get :edit, params: { id: batch.id }
      expect(response).to be_success
      expect(assigns(:can_delete)).to be_falsy
    end

    it "should not be accessible if can not edit" do
      sign_in other_user

      get :edit, params: { id: batch.id }
      expect(response).to be_forbidden
    end

    it "should allow to delete if can delete" do
      grant user, other_user, Batch, UPDATE_BATCH
      grant user, other_user, Batch, DELETE_BATCH
      sign_in other_user

      get :edit, params: { id: batch.id }
      expect(response).to be_success
      expect(assigns(:can_delete)).to be_truthy
    end
  end

  context "update" do
    let!(:batch) { Batch.make!(
      institution: institution,
      batch_number: '123',
      isolate_name: 'ABC.42',
      date_produced: Time.zone.local(2021, 8, 8),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 100
    )}

    it "should update existing batch" do
      post :update, params: {
        id: batch.id,
        batch: {
          isolate_name: 'ABC.42',
          date_produced: '09/09/2021',
          lab_technician: 'TecFoo',
          specimen_role: 'p',
          inactivation_method: 'Heat',
          volume: '200'
        }
      }
      expect(response).to be_redirect

      batch.reload
      expect(batch.isolate_name).to eq('ABC.42')
      expect(batch.date_produced).to eq('09/09/2021')
      expect(batch.lab_technician).to eq('TecFoo')
      expect(batch.specimen_role).to eq('p')
      expect(batch.inactivation_method).to eq('Heat')
      expect(batch.volume).to eq('200')
    end

    it "should require date_produced" do
      post :update, params: { id: batch.id, batch: { date_produced: '' } }
      expect(assigns(:batch_form).errors).to have_key(:date_produced)
      expect(response).to render_template("batches/edit")
    end

    it "should update existing batch if allowed" do
      grant user, other_user, Batch, UPDATE_BATCH

      sign_in other_user
      post :update, params: {
        id: batch.id,
        batch: {
          isolate_name: 'ABC.42',
          date_produced: '09/09/2021',
          lab_technician: 'TecFoo',
          specimen_role: 'p',
          inactivation_method: 'Heat',
          volume: '200'
        }
      }
      expect(response).to be_redirect

      batch.reload
      expect(batch.isolate_name).to eq('ABC.42')
      expect(batch.date_produced).to eq('09/09/2021')
      expect(batch.lab_technician).to eq('TecFoo')
      expect(batch.specimen_role).to eq('p')
      expect(batch.inactivation_method).to eq('Heat')
      expect(batch.volume).to eq('200')
    end

    it "should not update existing batch if not allowed" do
      sign_in other_user
      post :update, params: { id: batch.id, batch: { date_produced: '09/09/2021' } }
      expect(response).to be_forbidden

      batch.reload
      expect(batch.date_produced).to_not eq('09/09/2021')
    end
  end

  context "destroy" do
    let!(:batch) { Batch.make!(
      institution: institution,
      batch_number: '123',
      isolate_name: 'ABC.42',
      date_produced: Time.zone.local(2021, 8, 8),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 100
    )}

    it "should be able to soft delete a batch" do
      expect {
        delete :destroy, params: { id: batch.id }
      }.to change(institution.batches, :count).by(-1)

      batch.reload
      expect(batch.deleted_at).to_not be_nil

      expect(response).to be_redirect
    end

    it "should be able to delete if can delete" do
      grant user, other_user, Batch, DELETE_BATCH
      sign_in other_user

      expect {
        delete :destroy, params: { id: batch.id }
      }.to change(institution.batches, :count).by(-1)

      batch.reload
      expect(batch.deleted_at).to_not be_nil
    end

    it "should not able to delete if can not delete" do
      sign_in other_user

      expect {
        delete :destroy, params: { id: batch.id }
      }.to change(institution.batches, :count).by(0)

      expect(response).to be_forbidden
    end
  end

  context "bulk_destroy" do
    let!(:batch1) { Batch.make!(
      institution: institution,
      batch_number: '123',
      isolate_name: 'ABC.42',
      date_produced: Time.zone.local(2021, 8, 8),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 100
    )}

    let!(:batch2) { Batch.make!(
      institution: institution,
      batch_number: '456',
      isolate_name: 'DEF.24',
      date_produced: Time.zone.local(2020, 9, 9),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 200
    )}

    let!(:institution2)   { Institution.make! }
    let!(:batch3) { Batch.make!(
      institution: institution2,
      batch_number: '789',
      isolate_name: 'GHI.4224',
      date_produced: Time.zone.local(2019, 7, 7),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 300
    )}

    it "should be able to bulk destroy batches" do

      expect {
        post :bulk_destroy, params: { batch_ids: [batch1.id, batch2.id] }
      }.to change(institution.batches, :count).by(-2)

      batch1.reload
      expect(batch1.deleted_at).to_not be_nil
      batch2.reload
      expect(batch2.deleted_at).to_not be_nil

      expect(response).to be_redirect
    end

    it "should be able to bulk destroy if can DELETE" do
      grant user, other_user, Batch, DELETE_BATCH
      sign_in other_user

      expect {
        post :bulk_destroy, params: { batch_ids: [batch1.id, batch2.id] }
      }.to change(institution.batches, :count).by(-2)

      batch1.reload
      expect(batch1.deleted_at).to_not be_nil
      batch2.reload
      expect(batch2.deleted_at).to_not be_nil
    end

    it "should not able to bulk destroy if can not DELETE" do
      sign_in other_user

      expect {
        post :bulk_destroy, params: { batch_ids: [batch1.id, batch2.id] }
      }.to change(institution.batches, :count).by(0)

      expect(response).to be_forbidden
    end

    it "should not able to bulk destroy if can not DELETE all batches" do
      expect {
        post :bulk_destroy, params: { batch_ids: [batch1.id, batch2.id, batch3.id] }
      }.to change(institution.batches, :count).by(0)

      expect(response).to be_forbidden
    end
  end

  describe "add_sample" do
    let!(:batch) { Batch.make!(
      institution: institution,
      batch_number: '1234',
      isolate_name: 'ABC.424',
      date_produced: Time.zone.local(2021, 8, 8),
      lab_technician: 'Tec.Foo',
      specimen_role: 'q',
      inactivation_method: 'Formaldehyde',
      volume: 100,
      virus_lineage: 'B.1.1.529'
    )}

    it "creates sample from batch" do
      expect do
        post :add_sample, params: { id: batch.id }
        expect(response).to redirect_to(edit_batch_path(batch))
      end.to change(batch.samples, :count).by(1)

      sample = batch.samples.last
      expect(sample.batch_id).to eq(batch.id)
      expect(sample.isolate_name).to eq(batch.isolate_name)
      expect(sample.date_produced).to eq(batch.date_produced)
      expect(sample.lab_technician).to eq(batch.lab_technician)
      expect(sample.specimen_role).to eq(batch.specimen_role)
      expect(sample.inactivation_method).to eq(batch.inactivation_method)
      expect(sample.volume).to eq(batch.volume)
      expect(sample.virus_lineage).to eq(batch.virus_lineage)
    end

    it "should be allowed if can update batch" do
      grant user, other_user, Batch, UPDATE_BATCH
      sign_in other_user

      expect do
        post :add_sample, params: { id: batch.id }
        expect(response).to redirect_to(edit_batch_path(batch))
      end.to change(batch.samples, :count).by(1)
    end

    it "should not be allowed if can't update batch" do
      sign_in other_user

      expect do
        post :add_sample, params: { id: batch.id }
        expect(response).to have_http_status(:forbidden)
      end.to change(batch.samples, :count).by(0)
    end
  end
end
