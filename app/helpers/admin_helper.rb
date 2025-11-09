module AdminHelper
  # Helper method for user role badge colors
  def role_badge_class(role)
    case role
    when 'admin'
      'bg-gray-900 text-white'
    when 'owner'
      'bg-gray-600 text-white'
    else
      'bg-gray-200 text-gray-800'
    end
  end
end
