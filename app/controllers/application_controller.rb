class ApplicationController < ActionController::Base
  include Knock::Authenticable

  protected

  def current_user
    sub = auth_token.payload["sub"]
    email = auth_token.payload["email"]

    current_user = nil

    if sub
      begin
        current_user = User.find_by(email: email)
        # current_user = User.find_or_create_by!(auth0_id: sub)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        retry
      end

      begin
        current_user.update!(email: email) if email.present? && email != current_user.email
      rescue ActiveRecord::StaleObjectError
        current_user.reload
        retry
      end
    end

    current_user
  end

  def auth_token
    Knock::AuthToken.new(token: token)
  end
end
