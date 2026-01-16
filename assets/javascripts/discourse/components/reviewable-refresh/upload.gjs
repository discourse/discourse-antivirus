import Component from "@ember/component";
import LegacyReviewableUpload from "../reviewable-upload";

export default class ReviewableUpload extends Component {
  <template>
    <div class="review-item__meta-content">
      <LegacyReviewableUpload @reviewable={{@reviewable}}>
        {{yield}}
      </LegacyReviewableUpload>
    </div>
  </template>
}
