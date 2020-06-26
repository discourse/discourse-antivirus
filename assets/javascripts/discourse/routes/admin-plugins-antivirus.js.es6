import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  controllerName: "admin-plugins-antivirus",

  model() {
    return ajax("/admin/plugins/antivirus");
  },

  setupController(controller, model) {
    controller.setProperties({
      model: model.antivirus,
      background_scan_stats: model.background_scan_stats
    });
  }
});
