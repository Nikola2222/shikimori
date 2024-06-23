shared_examples :moderatable_concern do |type|
  describe 'moderatable concern' do
    subject(:model) { build type, moderation_state: }
    let(:moderation_state) { Types::Moderatable::State[:pending] }

    describe 'validations' do
      describe 'approver' do
        context 'pending' do
          it { is_expected.to_not validate_presence_of :approver }
        end

        [Types::Moderatable::State[:accepted], Types::Moderatable::State[:rejected]].each do |state|
          context state do
            let(:moderation_state) { state }
            it { is_expected.to validate_presence_of :approver }
          end
        end
      end
    end

    describe 'aasm' do
      describe 'states' do
        subject { build :collection, state }

        context 'pending' do
          let(:state) { Types::Moderatable::State[:pending] }
          before do
            allow(subject).to receive :assign_approver
            allow(subject).to receive :postprocess_rejection
          end

          it { is_expected.to have_state(state).on(:moderation_state) }
          it { is_expected.to allow_transition_to(:accepted).on(:moderation_state) }
          it do
            is_expected.to transition_from(state)
              .to(:accepted)
              .on_event(:accept, approver: user_2)
              .on(:moderation_state)
          end
          it { is_expected.to allow_transition_to(:rejected).on(:moderation_state) }
          it do
            is_expected.to transition_from(state)
              .to(:rejected)
              .on_event(:reject, approver: user_2)
              .on(:moderation_state)
          end
        end

        context 'accepted' do
          let(:state) { Types::Moderatable::State[:accepted] }

          it { is_expected.to have_state(state).on(:moderation_state) }
          it { is_expected.to allow_transition_to(:pending).on(:moderation_state) }
          it do
            is_expected.to transition_from(state)
              .to(:pending)
              .on_event(:cancel)
              .on(:moderation_state)
          end
          it { is_expected.to_not allow_transition_to(:rejected).on(:moderation_state) }
        end

        context 'rejected' do
          let(:state) { Types::Moderatable::State[:rejected] }

          it { is_expected.to have_state(state).on(:moderation_state) }
          it { is_expected.to_not allow_transition_to(:pending).on(:moderation_state) }
          it { is_expected.to_not allow_transition_to(:accepted).on(:moderation_state) }
        end
      end

      describe 'transitions' do
        subject { create type, :with_topics, state, approver: user }

        before do
          allow(subject).to receive(:assign_approver).and_call_original
          allow(subject).to receive :postprocess_rejection
        end

        context 'transition to accepted' do
          let(:state) { Types::Moderatable::State[:pending] }
          before { subject.accept! approver: user_2 }

          it do
            is_expected.to be_moderation_accepted
            is_expected.to_not be_changed
            expect(subject.approver).to eq user_2

            is_expected.to have_received(:assign_approver).with approver: user_2
            is_expected.to_not have_received :postprocess_rejection
          end
        end

        context 'transition to rejected' do
          let(:state) { Types::Moderatable::State[:pending] }
          before { subject.reject! approver: user_2 }

          it do
            is_expected.to be_moderation_rejected
            is_expected.to_not be_changed
            expect(subject.approver).to eq user_2

            is_expected.to have_received(:assign_approver).with approver: user_2
            is_expected.to have_received :postprocess_rejection
          end
        end
      end
    end

    describe 'instance methods' do
      let(:model) { create type, :with_topics }

      describe '#to_offtopic' do
        subject! { model.send :to_offtopic! }

        it do
          expect(model).to_not be_changed
          expect(model.topic.forum_id).to eq Forum::OFFTOPIC_ID
        end
      end

      describe '#assign_approver' do
        subject! { model.send :assign_approver, approver: }
        let(:approver) { user_2 }
        it do
          expect(model.approver).to eq approver
          expect(model).to be_changed
        end
      end

      describe '#postprocess_rejection' do
        before do
          allow(Messages::CreateNotification).to receive(:new).and_return notification_service
          allow(model).to receive(:to_offtopic!)
        end
        subject! { model.send :postprocess_rejection }
        let(:notification_service) { double moderatable_banned: nil }

        it do
          expect(model).to have_received :to_offtopic!
          expect(notification_service).to have_received(:moderatable_banned).with nil
        end
      end
    end
  end
end
