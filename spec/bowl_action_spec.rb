describe Fastlane::Actions::BowlAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The bowl plugin is working!")

      Fastlane::Actions::BowlAction.run(nil)
    end
  end
end
