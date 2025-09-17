module UsersHelper
 
  def user_full_name(user)
    m = user.member
    [m&.firstname, m&.lastname1, m&.lastname2].reject(&:blank?).join(' ')
  end

  def user_org_name(user)
    user.member&.organization&.name
  end

  # "6 de marzo de 2025" (locale ES)
  def user_membership_expiration(user)
    d = user.current_membership_expiration
    return nil unless d.present?
    I18n.l(d.to_date, format: "%-d de %B de %Y") # requiere locale ES cargado
  end

  def email_verified_badge(user)
    if user.email_verified?
      content_tag(:span, 'Verificado', class: 'new badge green', data: { badge_caption: nil })
    else
      content_tag(:span, 'No verificado', class: 'new badge red', data: { badge_caption: nil })
    end
  end

end
