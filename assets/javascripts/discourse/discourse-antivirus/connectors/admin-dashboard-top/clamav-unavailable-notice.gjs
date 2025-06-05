import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("div")
@classNames("admin-dashboard-top-outlet", "clamav-unavailable-notice")
export default class ClamavUnavailableNotice extends Component {
  static shouldRender(args, context) {
    return context.site.clamav_unreacheable;
  }

  <template>
    <div class="alert alert-error">
      {{i18n "antivirus.clamav_unavailable"}}
    </div>
  </template>
}
