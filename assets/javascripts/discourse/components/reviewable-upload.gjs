import Component from "@ember/component";
import CookText from "discourse/components/cook-text";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewableField from "discourse/components/reviewable-field";
import ReviewableTopicLink from "discourse/components/reviewable-topic-link";
import { i18n } from "discourse-i18n";

export default class extends Component {
  <template>
    {{#if this.reviewable.topic}}
      <div class="flagged-post-header">
        <ReviewableTopicLink @reviewable={{this.reviewable}} @tagName="" />
      </div>
    {{/if}}

    <div class="reviewable-upload">
      <div class="reviewable-upload-contents">
        <div class="post-contents-wrapper">
          {{#if this.reviewable.target_created_by}}
            <ReviewableCreatedBy
              @user={{this.reviewable.target_created_by}}
              @tagName=""
            />
          {{/if}}

          <div class="post-contents">
            <div class="post-body disable-links-to-flagged-upload">
              <CookText @rawText={{this.reviewable.payload.post_raw}} />
            </div>
          </div>
        </div>

        <ReviewableField
          @classes="reviewable-upload-details scan-result"
          @name={{i18n "review.file.scan_result"}}
          @value={{this.reviewable.payload.scan_message}}
        />

        <ReviewableField
          @classes="reviewable-upload-details filename"
          @name={{i18n "review.file.filename"}}
          @value={{this.reviewable.payload.original_filename}}
        />

        <ReviewableField
          @classes="reviewable-upload-details uploaded-by"
          @name={{i18n "review.file.uploaded_by"}}
          @value={{this.reviewable.payload.uploaded_by}}
        />
      </div>

      {{yield}}
    </div>
  </template>
}
