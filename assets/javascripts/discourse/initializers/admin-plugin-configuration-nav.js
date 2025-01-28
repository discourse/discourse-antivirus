import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-antivirus-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi("1.1.0", (api) => {
      api.addAdminPluginConfigurationNav("discourse-antivirus", [
        {
          label: "antivirus.stats.title",
          route: "adminPlugins.show.discourse-antivirus-stats",
        },
      ]);
    });
  },
};
