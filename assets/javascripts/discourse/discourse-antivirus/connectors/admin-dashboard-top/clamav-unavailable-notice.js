export default {
  shouldRender(args, component) {
    return component.site.clamav_unreacheable;
  },
};
