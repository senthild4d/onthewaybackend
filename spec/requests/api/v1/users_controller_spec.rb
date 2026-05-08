require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :request do
  let(:user) { create(:user, :active) }
  let(:headers) { auth_headers(user) }
  let(:json) { json_response }

  describe 'GET /api/v1/users/me' do
    context 'when authenticated' do
      before { get '/api/v1/users/me', headers: headers }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns current user data' do
        expect(json[:data][:user][:id]).to eq(user.id)
        expect(json[:data][:user][:email]).to eq(user.email)
        expect(json[:data][:user][:username]).to eq(user.username)
      end

      it 'includes avatar_url and bio' do
        expect(json[:data][:user]).to have_key(:avatar_url)
        expect(json[:data][:user]).to have_key(:bio)
      end
    end

    context 'when not authenticated' do
      before { get '/api/v1/users/me' }

      it 'returns unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/users/:id' do
    let(:target_user) { create(:user, :active) }

    context 'when authenticated' do
      before { get "/api/v1/users/#{target_user.id}", headers: headers }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns user profile data' do
        expect(json[:data][:user][:id]).to eq(target_user.id)
        expect(json[:data][:user][:username]).to eq(target_user.username)
      end

      it 'includes profile stats' do
        expect(json[:data][:user]).to have_key(:stats)
      end
    end

    context 'when user not found' do
      before { get "/api/v1/users/invalid-id", headers: headers }

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/users/me' do
    let(:valid_params) do
      {
        user: {
          name: 'Updated Name',
          username: 'newusername',
          bio: 'Updated bio'
        }
      }
    end

    context 'with valid params' do
      before { patch '/api/v1/users/me', params: valid_params, headers: headers, as: :json }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'updates user profile' do
        expect(json[:data][:user][:name]).to eq('Updated Name')
        expect(json[:data][:user][:username]).to eq('newusername')
        expect(json[:data][:user][:bio]).to eq('Updated bio')
      end

      it 'returns success message' do
        expect(json[:message]).to eq('Profile updated successfully')
      end
    end

    context 'when trying to update email directly' do
      let(:params) do
        {
          user: {
            email: 'newemail@example.com'
          }
        }
      end

      before { patch '/api/v1/users/me', params: params, headers: headers, as: :json }

      it 'does not update email' do
        user.reload
        expect(user.email).not_to eq('newemail@example.com')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          user: {
            username: 'ab'  # too short
          }
        }
      end

      before { patch '/api/v1/users/me', params: invalid_params, headers: headers, as: :json }

      it 'returns validation error' do
        expect(response.status).to be >= 400
        expect(response.status).to be < 500
      end
    end
  end

  describe 'POST /api/v1/users/me/upload_profile_picture' do
    let(:image_file) do
      fixture_file_upload(
        Rails.root.join('spec', 'fixtures', 'files', 'test_image.png'),
        'image/png'
      )
    end

    context 'with valid image' do
      before do
        post '/api/v1/users/me/upload_profile_picture',
             params: { profile_picture: image_file },
             headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'attaches profile picture' do
        user.reload
        expect(user.profile_picture.attached?).to be true
      end

      it 'returns profile picture URL' do
        expect(json[:data][:profile_picture_url]).to be_present
        expect(json[:data][:avatar_url]).to be_present
      end

      it 'returns success message' do
        expect(json[:message]).to eq('Profile picture uploaded successfully')
      end
    end

    context 'without file' do
      before do
        post '/api/v1/users/me/upload_profile_picture',
             params: {},
             headers: headers
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        expect(json[:message]).to eq('Profile picture file is required')
      end
    end

    context 'with invalid file type' do
      let(:invalid_file) do
        fixture_file_upload(
          Rails.root.join('spec', 'fixtures', 'files', 'test_document.pdf'),
          'application/pdf'
        )
      end

      before do
        post '/api/v1/users/me/upload_profile_picture',
             params: { profile_picture: invalid_file },
             headers: headers
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        expect(json[:message]).to include('Invalid file type')
      end
    end
  end

  describe 'POST /api/v1/users/me/change_email' do
    let(:new_email) { 'newemail@example.com' }
    let(:params) { { email: new_email } }

    context 'with valid email' do
      before do
        allow(EmailService).to receive(:send_otp)
        post '/api/v1/users/me/change_email', params: params, headers: headers, as: :json
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns verification token' do
        expect(json[:data][:verification_token]).to be_present
      end

      it 'creates OTP record' do
        expect(Otp.where(email: new_email).exists?).to be true
      end
    end

    context 'with already taken email' do
      let!(:existing_user) { create(:user, email: 'taken@example.com') }
      let(:params) { { email: 'taken@example.com' } }

      before do
        post '/api/v1/users/me/change_email', params: params, headers: headers, as: :json
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        expect(json[:message]).to eq('Email is already taken')
      end
    end

    context 'with invalid email' do
      let(:params) { { email: 'invalid-email' } }

      before do
        post '/api/v1/users/me/change_email', params: params, headers: headers, as: :json
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/users/me/verify_email_change' do
    let(:new_email) { 'newemail@example.com' }
    let!(:otp) { create(:otp, email: new_email, code: '123456') }
    let(:token) do
      JsonWebToken.encode(
        user_id: user.id,
        pending_email: new_email,
        otp_id: otp.id,
        exp: 15.minutes.from_now.to_i
      )
    end
    let(:params) do
      {
        verification_token: token,
        otp_code: '123456'
      }
    end

    context 'with valid OTP' do
      before do
        post '/api/v1/users/me/verify_email_change', params: params, headers: headers, as: :json
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'updates user email' do
        user.reload
        expect(user.email).to eq(new_email)
      end

      it 'marks OTP as verified' do
        otp.reload
        expect(otp.verified).to be true
      end
    end

    context 'with invalid OTP' do
      let(:params) do
        {
          verification_token: token,
          otp_code: 'wrong'
        }
      end

      before do
        post '/api/v1/users/me/verify_email_change', params: params, headers: headers, as: :json
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'does not update email' do
        user.reload
        expect(user.email).not_to eq(new_email)
      end
    end
  end

  describe 'POST /api/v1/users/me/change_phone' do
    let(:new_phone) { '9876543210' }
    let(:params) { { phone: new_phone } }

    context 'with valid phone' do
      before do
        allow(SmsService).to receive(:send_otp)
        post '/api/v1/users/me/change_phone', params: params, headers: headers, as: :json
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns verification token' do
        expect(json[:data][:verification_token]).to be_present
      end

      it 'creates OTP record' do
        expect(Otp.where(phone: new_phone).exists?).to be true
      end
    end

    context 'with already taken phone' do
      let!(:existing_user) { create(:user, phone: '9999999999') }
      let(:params) { { phone: '9999999999' } }

      before do
        post '/api/v1/users/me/change_phone', params: params, headers: headers, as: :json
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/users/me/unlink_email' do
    context 'when user has phone number' do
      before do
        user.update(phone: '1234567890', email: 'test@example.com')
        post '/api/v1/users/me/unlink_email', headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'removes email from user' do
        user.reload
        expect(user.email).to be_nil
      end

      it 'returns success message' do
        expect(json[:message]).to eq('Email address unlinked successfully')
      end
    end

    context 'when user does not have phone number' do
      before do
        user.update(phone: nil, email: 'test@example.com')
        post '/api/v1/users/me/unlink_email', headers: headers
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'does not remove email' do
        user.reload
        expect(user.email).to be_present
      end

      it 'returns error message' do
        expect(json[:message]).to include('phone number')
      end
    end

    context 'when email is not linked' do
      before do
        user.update(phone: '1234567890', email: nil)
        post '/api/v1/users/me/unlink_email', headers: headers
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/users/me/unlink_phone' do
    context 'when user has email address' do
      before do
        user.update(phone: '1234567890', email: 'test@example.com')
        post '/api/v1/users/me/unlink_phone', headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'removes phone from user' do
        user.reload
        expect(user.phone).to be_nil
      end

      it 'returns success message' do
        expect(json[:message]).to eq('Phone number unlinked successfully')
      end
    end

    context 'when user does not have email address' do
      before do
        user.update(phone: '1234567890', email: nil)
        post '/api/v1/users/me/unlink_phone', headers: headers
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'does not remove phone' do
        user.reload
        expect(user.phone).to be_present
      end

      it 'returns error message' do
        expect(json[:message]).to include('email')
      end
    end
  end

  describe 'POST /api/v1/users/me/deactivate' do
    let(:params) do
      {
        reason: 'Privacy and security issues',
        additional_feedback: 'More details here'
      }
    end

    context 'with valid params' do
      before do
        post '/api/v1/users/me/deactivate', params: params, headers: headers, as: :json
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'deactivates user account' do
        user.reload
        expect(user.status).to eq('disabled')
      end

      it 'creates deactivation record' do
        expect(user.user_deactivations.count).to eq(1)
      end

      it 'stores reason in deactivation record' do
        deactivation = user.user_deactivations.last
        expect(deactivation.reason).to eq('privacy_security')
        expect(deactivation.additional_feedback).to eq('More details here')
      end

      it 'returns deactivation data' do
        expect(json[:data][:deactivation][:reason]).to be_present
        expect(json[:data][:deactivation][:deactivated_at]).to be_present
      end

      it 'returns success message' do
        expect(json[:message]).to eq('Account deactivated successfully')
      end
    end

    context 'without reason' do
      before do
        post '/api/v1/users/me/deactivate', params: {}, headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'deactivates account' do
        user.reload
        expect(user.status).to eq('disabled')
      end

      it 'creates deactivation without reason' do
        deactivation = user.user_deactivations.last
        expect(deactivation.reason).to be_nil
      end
    end

    context 'with normalized reason' do
      let(:params) { { reason: 'I am leaving temporarily' } }

      before do
        post '/api/v1/users/me/deactivate', params: params, headers: headers, as: :json
      end

      it 'normalizes reason to database format' do
        deactivation = user.user_deactivations.last
        expect(deactivation.reason).to eq('leaving_temporarily')
      end
    end
  end

  describe 'POST /api/v1/users/me/reactivate' do
    context 'when user is deactivated' do
      before do
        user.deactivate!(reason: 'privacy_security')
        post '/api/v1/users/me/reactivate', headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'reactivates user account' do
        user.reload
        expect(user.status).to eq('active')
      end

      it 'updates deactivation record' do
        deactivation = user.user_deactivations.last
        expect(deactivation.reactivated_at).to be_present
      end

      it 'returns success message' do
        expect(json[:message]).to eq('Account reactivated successfully')
      end
    end

    context 'when user is not deactivated' do
      before do
        post '/api/v1/users/me/reactivate', headers: headers
      end

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        expect(json[:message]).to eq('Account is not deactivated')
      end
    end

    context 'with reactivation notes' do
      let(:params) do
        {
          reactivated_by: 'user',
          notes: 'Changed my mind'
        }
      end

      before do
        user.deactivate!(reason: 'privacy_security')
        post '/api/v1/users/me/reactivate', params: params, headers: headers, as: :json
      end

      it 'stores reactivation notes' do
        deactivation = user.user_deactivations.last
        expect(deactivation.reactivation_notes).to eq('Changed my mind')
        expect(deactivation.reactivated_by).to eq('user')
      end
    end
  end

  describe 'GET /api/v1/users/search' do
    let!(:john) { create(:user, name: 'John Doe', username: 'johndoe') }
    let!(:jane) { create(:user, name: 'Jane Smith', username: 'janesmith') }

    context 'with search query' do
      before { get '/api/v1/users/search', params: { q: 'john' }, headers: headers }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns matching users' do
        expect(json[:data][:users].length).to be >= 1
      end

      it 'includes pagination data' do
        expect(json[:data][:pagination]).to be_present
      end
    end

    context 'without search query' do
      before { get '/api/v1/users/search', headers: headers }

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with limit and offset' do
      before do
        get '/api/v1/users/search', params: { q: 'user', limit: 5, offset: 0 }, headers: headers
      end

      it 'respects limit' do
        expect(json[:data][:users].length).to be <= 5
      end
    end
  end
end

