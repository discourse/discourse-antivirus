export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("discourse-antivirus-stats", { path: "stats" });
  },
};
