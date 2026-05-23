# frozen_string_literal: true

module Api
  class UsersController < BaseController
    # POST /api/users
    def create
      @form = Api::CreateUserForm.new(User.new, current_user, user_params)
      if @form.save
        render json: {id: User.last.id, name: User.last.name, email: User.last.email}, status: :created
      else
        render json: Halitosis::ErrorsSerializer.new(@form), status: :unprocessable_content
      end
    end

    private

    def user_params
      params.expect(user: [:name, :email])
    end
  end
end
