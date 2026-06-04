# frozen_string_literal: true

class UpdateArticleForm < WellFormed::ResourceForm
  resource_alias :article

  attribute :title, :string
  attribute :body, :string
  attribute :published, :boolean, default: false

  validates :title, presence: true
  validates :body, presence: true

  private

  def perform
    assign_attributes_to(resource)
    resource.save
  end
end
