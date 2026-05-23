# frozen_string_literal: true

class CollectionForInput < SimpleForm::Inputs::CollectionSelectInput
  def collection
    if object.respond_to?(:"collection_for_#{attribute_name}")
      @collection ||= object.public_send(:"collection_for_#{attribute_name}")
    else
      super
    end
  end
end
