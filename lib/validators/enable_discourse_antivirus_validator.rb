# frozen_string_literal: true

class EnableDiscourseAntivirusValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"

    DiscourseAntivirus::ClamAV.correctly_configured?
  end

  def error_message
    I18n.t("site_settings.errors.antivirus_srv_record_required")
  end
end
