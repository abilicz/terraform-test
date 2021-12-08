data "google_project" "project" {
}

resource "google_cloud_run_service" "default" {
  name = "cloudrun-srv"
  location = "us-central1"

  template {
    spec {
      timeout_seconds = 3600
      containers {
        image = "gcr.io/planning-poker-staging-env/test-image:latest"
        env {
          name = "NODE_ENV"
          value = "staging"
        }
        env {
          name = "MONGO_URI"
          value = "mongo-uri"
        }
        env {
          name = "SECRET_ENV_VAR"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.secret.secret_id
              key = "latest"
            }
          }
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

resource "google_secret_manager_secret_iam_member" "secret-access" {
  secret_id = google_secret_manager_secret.secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  depends_on = [google_secret_manager_secret.secret]
}

# Enabling Secret Manager API
resource "google_project_service" "secretmanager" {
  project = google_cloud_run_service.default.project
  service  = "secretmanager.googleapis.com"
}

resource "google_secret_manager_secret" "secret" {
  secret_id = "secret"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "secret-version-data" {
  secret = google_secret_manager_secret.secret.name
  secret_data = "secret-data"
}
