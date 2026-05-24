# frozen_string_literal: true

module Api
  class UserProfilesController < BaseController
    # PATCH /api/user_profile
    def update
      form = UpdateUserProfileForm.new(current_user, current_user, user_profile_params)

      if (user = form.submit)
        render json: user.as_json, status: :ok
      else
        render json: {errors: form.errors.messages}, status: :unprocessable_content
      end
    end

    private

    def user_profile_params
      params.require(:user_profile).permit(:name, :email)
    end
  end
end
