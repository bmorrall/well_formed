# frozen_string_literal: true

class RetractArticleForm < WellFormed::ActionForm
  update_action

  resource_alias :publication

  attribute :reason, :string

  validates :reason, presence: true

  private

  def perform
    publication.update!(published: false)
    true
  end
end
