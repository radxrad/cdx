require "spec_helper"

RSpec.describe TransferPackage, type: :model do
  let(:sender) { Institution.make }
  let(:receiver) { Institution.make }

  it ".new" do
    transfer = TransferPackage.new
    expect(transfer).not_to be_valid

    transfer = TransferPackage.new(
      receiver_institution: receiver,
      sender_institution: sender,
      box_transfers: [BoxTransfer.make],
    )
    expect(transfer).to be_valid
  end

  it "accepts nested attributes" do
    box = Box.make!
    transfer = TransferPackage.new(
      sender_institution: sender,
      receiver_institution: receiver,
      box_transfers_attributes: {
        "0" => {
          box_id: box.id
        }
      }
    )
    transfer.save!
  end

  describe ".save" do
    describe "attach QC info" do
      let(:batch) { Batch.make!(:qc_sample) }
      let(:sample1) { Sample.make(institution: sender, batch: batch) }
      let(:sample2) { Sample.make(institution: sender, batch: batch) }

      it "includes_qc_info: true" do
        transfer = TransferPackage.new(sender_institution: sender, receiver_institution: receiver, includes_qc_info: true)
        transfer.add Box.make(institution: sender, samples: [sample1])
        transfer.add Box.make(institution: sender, samples: [sample2])
        transfer.save!

        sample1.reload
        sample2.reload
        expect(sample1.qc_info).to be_a(QcInfo)
        expect(sample2.qc_info).to be_a(QcInfo)
        expect(sample1.qc_info).to eq sample2.qc_info
      end

      it "includes_qc_info: false" do
        transfer = TransferPackage.new(sender_institution: sender, receiver_institution: receiver, includes_qc_info: false)
        transfer.add Box.make(samples: [sample1])
        transfer.add Box.make(samples: [sample2])
        transfer.save!

        sample1.reload
        sample2.reload
        expect(sample1.qc_info).to be_nil
        expect(sample2.qc_info).to be_nil
      end
    end

    it "updates box and sample context" do
      site = Site.make(institution: sender)
      sample = Sample.make(institution: sender, site: site)
      transfer = TransferPackage.new(sender_institution: sender, receiver_institution: receiver)
      box = Box.make!(institution: sender, site: site, samples: [sample])
      transfer.add(box)
      transfer.save!

      box.reload
      expect(box.institution).to be_nil
      expect(box.site).to be_nil

      sample.reload
      expect(sample.institution).to be_nil
      expect(sample.site).to be_nil
    end
  end

  describe "#confirm!" do
    it "sets confirmed_at" do
      transfer = TransferPackage.make!
      expect(transfer).not_to be_confirmed

      Timecop.freeze(Time.now.change(usec: 0)) do
        expect(transfer.confirm!).to be true
        expect(transfer.confirmed_at).to eq Time.now
      end

      transfer.reload
      expect(transfer).to be_confirmed
      expect(transfer).not_to be_changed
      expect(transfer.boxes.map(&:institution)).to eq [transfer.receiver_institution]
      expect(transfer.samples.map(&:institution)).to eq [transfer.receiver_institution, transfer.receiver_institution]
    end

    it "raises if already confirmed" do
      transfer = TransferPackage.make(:confirmed)

      expect {
        expect { transfer.confirm! }.to raise_error(ActiveRecord::RecordNotSaved)
      }.not_to change { transfer.confirmed_at }
    end
  end
end
