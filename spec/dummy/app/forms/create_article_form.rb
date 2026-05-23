# frozen_string_literal: true

class CreateArticleForm < WellFormed::ResourceForm
  resource_alias :article

  attribute :title, :string
  attribute :body, :string
  attribute :published, :boolean, default: false

  validates :title, presence: true
  validates :body, presence: true
end
