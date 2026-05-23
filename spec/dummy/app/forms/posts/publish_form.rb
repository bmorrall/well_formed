# frozen_string_literal: true

module Posts
  class PublishForm < WellFormed::ActionForm
    resource_alias :publication

    attribute :reason, :string

    validates :reason, presence: true

    private

    def perform
      publication.update!(published: true)
      true
    end
  end
end
