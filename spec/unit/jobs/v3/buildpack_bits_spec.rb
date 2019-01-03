require 'spec_helper'
require 'jobs/v3/buildpack_bits'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe BuildpackBits, job_context: :api do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:filename) { 'uploaded.zip' }
      let!(:buildpack) { Buildpack.make }
      let(:buildpack_guid) { buildpack.guid }

      subject(:job) do
        BuildpackBits.new(buildpack_guid, uploaded_path)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        let(:tmpdir) { '/tmp/special_temp' }
        let(:max_package_size) { 256 }

        it 'creates an PackagePacker and performs' do
          uploader = instance_double(UploadBuildpack)
          expect(UploadBuildpack).to receive(:new).with(instance_of(CloudController::Blobstore::Client)).and_return(uploader)
          expect(uploader).to receive(:upload_buildpack).with(buildpack, uploaded_path, filename)
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_bits)
        end
      end
    end
  end
end
