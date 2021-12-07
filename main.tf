resource "google_cloud_run_service" "default" {
  name = "cloudrun-srv"
  location = "us-central1"

  template {
    spec {
      timeout_seconds = 3600
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
        env {
          name = "NODE_ENV"
          value = "staging"
        }
        env {
          name = "MONGO_URI"
          value = "mongo-uri"
        }

      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "1"
        "autoscaling.knative.dev/maxScale" = "2"
      }
    }
  }

  traffic {
    percent = 100
    latest_revision = true
  }
}

resource "google_container_registry" "registry" {
  location = "US"
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.default.location
  project = google_cloud_run_service.default.project
  service = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
