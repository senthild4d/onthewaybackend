class UserIdentifierGenerator
  LETTERS = ('A'..'Z').to_a.freeze

  class << self
    def generate
      100.times do
        code = "#{random_letters(4)}#{random_digits(4)}"
        return code unless User.exists?(uniq_identifier: code)
      end

      raise 'Unable to generate a unique user identifier'
    end

    private

    def random_letters(count)
      count.times.map { LETTERS.sample(random: SecureRandom) }.join
    end

    def random_digits(count)
      format("%0#{count}d", SecureRandom.random_number(10**count))
    end
  end
end
