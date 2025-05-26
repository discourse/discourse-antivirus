import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <section class="antivirus-stats admin-detail pull-left">
      <div class="antivirus-stats__header">
        <h3>{{i18n "antivirus.stats.title"}}</h3>
      </div>

      <table class="antivirus-stats__table">
        <thead>
          <tr>
            <th>{{i18n "antivirus.version"}}</th>
            <th>{{i18n "antivirus.database_version"}}</th>
            <th>{{i18n "antivirus.database_updated_at"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.model.versions as |version|}}
            <tr>
              <td>{{version.antivirus}}</td>
              <td>{{version.database}}</td>
              <td>{{version.updated_at}}</td>
            </tr>
          {{/each}}
        </tbody>
      </table>

      <div class="antivirus-stats__sub-header">
        <h4>{{i18n "antivirus.stats.data"}}</h4>
      </div>

      <table class="antivirus-stats__table">
        <thead>
          <tr>
            <th>{{i18n "antivirus.stats.total_scans"}}</th>
            <th>{{i18n "antivirus.stats.recently_scanned"}}</th>
            <th>{{i18n "antivirus.stats.quarantined"}}</th>
            <th>{{i18n "antivirus.stats.found"}}</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>{{@controller.model.stats.scans}}</td>
            <td>{{@controller.model.stats.recently_scanned}}</td>
            <td>{{@controller.model.stats.quarantined}}</td>
            <td>{{@controller.model.stats.found}}</td>
          </tr>
        </tbody>
      </table>

    </section>
  </template>
);
