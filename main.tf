data "google_project" "project" {
}

variable "gcp_service_list" {
  description ="The list of apis necessary for the project"
  type = list(string)
  default = [
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "containerregistry.googleapis.com"
  ]
}

resource "google_project_service" "gcp_services" {
  for_each = toset(var.gcp_service_list)
  project = "planning-poker-staging-env"
  service = each.key
}

resource "google_cloud_run_service" "default" {
  name = "cloudrun-srv"
  location = "us-central1"

  template {
    spec {
      timeout_seconds = 3600
      containers {
        image = "gcr.io/planning-poker-staging-env/test-poker:latest"
        resources {
          limits = {
            cpus = 2
            memory = 40096
          }
        }
        ports {
          container_port = "3005"
        }
        env {
          name = "NODE_ENV"
          value = "staging"
        }
          env {
          name = "APP_BASE_URL"
          value = "staging-domain"
        }
        env {
          name = "MONGO_URI"
          value = "MONGO_URI"
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

output "cloud_run_url" {
  value = "${google_cloud_run_service.default.status[0].url}"
}
