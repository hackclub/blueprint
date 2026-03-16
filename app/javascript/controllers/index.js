// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application";
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading";
eagerLoadControllersFrom("controllers", application);

// Register Marksmith controllers
import {
  MarksmithController,
  ListContinuationController,
} from "@avo-hq/marksmith";
application.register("marksmith", MarksmithController);
application.register("list-continuation", ListContinuationController);

// Manual registrations for custom controllers with non-standard names
import DemoPicturePreviewController from "controllers/demo_picture_preview_controller";
application.register("demo-picture-preview", DemoPicturePreviewController);
