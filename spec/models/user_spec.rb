require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:user_deactivations).dependent(:destroy) }
    it { should have_many(:otps).dependent(:destroy) }
    it { should have_many(:devices).dependent(:destroy) }
    it { should have_many(:notifications).dependent(:destroy) }
    it { should have_one_attached(:profile_picture) }
  end

  describe 'validations' do
    context 'uniqueness validations' do
      subject { create(:user) }
      
      it { should validate_uniqueness_of(:email).case_insensitive.allow_nil }
      it { should validate_uniqueness_of(:username).case_insensitive.allow_nil }
      
      it 'validates phone uniqueness' do
        existing_user = create(:user, phone: '1234567890')
        new_user = build(:user, phone: '1234567890')
        expect(new_user).not_to be_valid
        expect(new_user.errors[:phone]).to include('has already been taken')
      end
      
      it 'allows nil phone' do
        user = build(:user, phone: nil, email: 'test@example.com')
        expect(user).to be_valid
      end
    end

    context 'email format' do
      it 'accepts valid email addresses' do
        user = build(:user, email: 'valid@example.com')
        expect(user).to be_valid
      end

      it 'rejects invalid email addresses' do
        user = build(:user, email: 'invalid-email')
        expect(user).not_to be_valid
      end
    end

    context 'phone format' do
      it 'accepts valid phone numbers' do
        user = build(:user, phone: '1234567890')
        expect(user).to be_valid
      end

      it 'rejects invalid phone numbers' do
        user = build(:user, phone: '123')
        expect(user).not_to be_valid
      end
    end

    context 'phone or email presence' do
      it 'is valid with email only' do
        user = build(:user, phone: nil, email: 'test@example.com')
        expect(user).to be_valid
      end

      it 'is valid with phone only' do
        user = build(:user, phone: '1234567890', email: nil)
        expect(user).to be_valid
      end

      it 'is invalid without both email and phone' do
        user = build(:user, phone: nil, email: nil)
        expect(user).not_to be_valid
        expect(user.errors[:base]).to include('Either phone or email must be present')
      end
    end

    context 'date of birth' do
      it 'is valid with past date' do
        user = build(:user, date_of_birth: 25.years.ago.to_date)
        expect(user).to be_valid
      end

      it 'is invalid with future date' do
        user = build(:user, date_of_birth: 1.day.from_now.to_date)
        expect(user).not_to be_valid
        expect(user.errors[:date_of_birth]).to include('cannot be in the future')
      end
    end

    context 'username format' do
      it 'accepts valid usernames' do
        user = build(:user, username: 'valid_user123')
        expect(user).to be_valid
      end

      it 'rejects usernames with special characters' do
        user = build(:user, username: 'invalid-user!')
        expect(user).not_to be_valid
      end

      it 'rejects usernames that are too short' do
        user = build(:user, username: 'ab')
        expect(user).not_to be_valid
      end
    end
  end

  describe 'enums' do
    it 'defines role enum' do
      expect(User.roles).to eq({
        'consumer' => 'consumer',
        'artist' => 'artist',
        'venue_manager' => 'venue_manager',
        'admin' => 'admin'
      })
    end

    it 'defines status enum' do
      expect(User.statuses).to eq({
        'active' => 'active',
        'disabled' => 'disabled'
      })
    end
  end

  describe 'callbacks' do
    describe 'downcase_email' do
      it 'downcases email before save' do
        user = create(:user, email: 'TEST@EXAMPLE.COM')
        expect(user.email).to eq('test@example.com')
      end
    end

    describe 'normalize_phone' do
      it 'removes non-digit characters from phone' do
        # Now that normalize_phone runs before_validation, we can test directly
        user = create(:user, phone: '+1 (234) 567-8900')
        expect(user.phone).to eq('12345678900')
      end
      
      it 'handles various phone formats' do
        user = create(:user, phone: '(555) 123-4567')
        expect(user.phone).to eq('5551234567')
      end
    end
  end

  describe '#avatar_url' do
    context 'with attached profile picture' do
      let(:user) { create(:user, :with_profile_picture) }

      it 'returns profile picture URL' do
        expect(user.avatar_url).to be_present
        expect(user.avatar_url).to include('rails/active_storage/blobs')
      end
    end

    context 'with profile_picture_url' do
      let(:user) { create(:user, profile_picture_url: 'https://example.com/avatar.jpg') }

      it 'returns profile_picture_url' do
        expect(user.avatar_url).to eq('https://example.com/avatar.jpg')
      end
    end

    context 'without any picture' do
      let(:user) { create(:user) }

      it 'returns default avatar path' do
        expect(user.avatar_url).to eq(DEFAULT_AVATAR_PATH)
      end
    end
  end

  describe 'deactivation methods' do
    let(:user) { create(:user, :active) }

    describe '#deactivate!' do
      it 'creates a deactivation record' do
        expect {
          user.deactivate!(reason: 'Privacy and security issues')
        }.to change { user.user_deactivations.count }.by(1)
      end

      it 'sets user status to disabled' do
        user.deactivate!(reason: 'Privacy and security issues')
        expect(user.reload.status).to eq('disabled')
      end

      it 'normalizes the reason' do
        user.deactivate!(reason: 'Privacy and security issues')
        deactivation = user.user_deactivations.last
        expect(deactivation.reason).to eq('privacy_security')
      end

      it 'stores additional feedback' do
        user.deactivate!(
          reason: 'other',
          additional_feedback: 'Detailed feedback here'
        )
        deactivation = user.user_deactivations.last
        expect(deactivation.additional_feedback).to eq('Detailed feedback here')
      end

      it 'sets deactivated_at timestamp' do
        user.deactivate!(reason: 'other')
        deactivation = user.user_deactivations.last
        expect(deactivation.deactivated_at).to be_present
      end
    end

    describe '#reactivate!' do
      before do
        user.deactivate!(reason: 'leaving_temporarily')
      end

      it 'sets user status to active' do
        user.reactivate!
        expect(user.reload.status).to eq('active')
      end

      it 'updates deactivation record with reactivation timestamp' do
        user.reactivate!
        deactivation = user.user_deactivations.last
        expect(deactivation.reactivated_at).to be_present
      end

      it 'stores reactivated_by' do
        user.reactivate!(reactivated_by: 'admin')
        deactivation = user.user_deactivations.last
        expect(deactivation.reactivated_by).to eq('admin')
      end

      it 'stores reactivation notes' do
        user.reactivate!(notes: 'User requested reactivation')
        deactivation = user.user_deactivations.last
        expect(deactivation.reactivation_notes).to eq('User requested reactivation')
      end
    end

    describe '#active_deactivation' do
      it 'returns nil when user is not deactivated' do
        expect(user.active_deactivation).to be_nil
      end

      it 'returns active deactivation record' do
        user.deactivate!(reason: 'other')
        expect(user.active_deactivation).to be_present
        expect(user.active_deactivation.reactivated_at).to be_nil
      end

      it 'returns nil after reactivation' do
        user.deactivate!(reason: 'other')
        user.reactivate!
        expect(user.reload.active_deactivation).to be_nil
      end
    end

    describe '#deactivation_history' do
      it 'returns all deactivations ordered by most recent' do
        user.deactivate!(reason: 'leaving_temporarily')
        user.reactivate!
        user.deactivate!(reason: 'privacy_security')

        history = user.deactivation_history
        expect(history.count).to eq(2)
        expect(history.first.reason).to eq('privacy_security')
      end
    end

    describe '#times_deactivated' do
      it 'returns count of deactivations' do
        expect(user.times_deactivated).to eq(0)
        
        user.deactivate!(reason: 'other')
        expect(user.times_deactivated).to eq(1)
        
        user.reactivate!
        user.deactivate!(reason: 'other')
        expect(user.times_deactivated).to eq(2)
      end
    end
  end

  describe 'follow methods' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    describe '#follow!' do
      it 'creates a follow relationship' do
        expect {
          user1.follow!(user2)
        }.to change { user1.following.count }.by(1)
      end

      it 'does not allow self-follow' do
        expect(user1.follow!(user1)).to be false
      end

      it 'does not create duplicate follows' do
        user1.follow!(user2)
        expect(user1.follow!(user2)).to be false
      end
    end

    describe '#unfollow!' do
      before { user1.follow!(user2) }

      it 'removes follow relationship' do
        expect {
          user1.unfollow!(user2)
        }.to change { user1.following.count }.by(-1)
      end
    end

    describe '#following?' do
      it 'returns true when following' do
        user1.follow!(user2)
        expect(user1.following?(user2)).to be true
      end

      it 'returns false when not following' do
        expect(user1.following?(user2)).to be false
      end
    end

    describe '#followed_by?' do
      it 'returns true when followed by user' do
        user1.follow!(user2)
        expect(user2.followed_by?(user1)).to be true
      end

      it 'returns false when not followed by user' do
        expect(user2.followed_by?(user1)).to be false
      end
    end

    describe '#followers_count' do
      it 'returns correct count' do
        user1.follow!(user2)
        expect(user2.followers_count).to eq(1)
      end
    end

    describe '#following_count' do
      it 'returns correct count' do
        user1.follow!(user2)
        expect(user1.following_count).to eq(1)
      end
    end
  end
end

