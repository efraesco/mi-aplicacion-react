# Proveedor de Google Cloud
provider "google" {
  project = "efraintest01"
}

# Política de seguridad de Cloud Armor
resource "google_compute_security_policy" "armor_policy" {
  project     = "efraintest01"
  name        = "block-specific-ip-policy"
  description = "Bloquea una dirección IP específica"

  # Regla para denegar el acceso desde la IP 1.2.3.4
  rule {
    action   = "deny(403)" # Devuelve un error 403 (Prohibido)
    priority = "1000"      # Prioridad de la regla
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["1.2.3.4/32"] # La IP que quieres bloquear
      }
    }
    description = "Bloquear IP de prueba"
  }

  # Regla por defecto para permitir todo el resto del tráfico
  rule {
    action   = "allow"
    priority = "2147483647" # Prioridad más baja
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Permitir todo el resto"
  }
}

# --- Recursos del Balanceador de Carga para conectar Cloud Armor ---

# Backend que apunta al servicio de Cloud Run
resource "google_compute_region_backend_service" "default" {
  project               = "efraintest01"
  name                  = "backend-for-react-app" # Nombre del backend
  region                = "us-central1"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  
  # Conexión al servicio de Cloud Run
  backend {
    group = "projects/efraintest01/locations/us-central1/services/todo-app-service"
  }
}

# Mapa de URL que dirige todo el tráfico al backend
resource "google_compute_url_map" "default" {
  project         = "efraintest01"
  name            = "url-map-for-react-app"
  default_service = google_compute_region_backend_service.default.id
}

# Proxy HTTPS que usa el mapa de URL
resource "google_compute_target_https_proxy" "default" {
  project   = "efraintest01"
  name      = "proxy-for-react-app"
  url_map   = google_compute_url_map.default.id
  # Se necesita un certificado SSL. Usamos uno autogestionado por Google.
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

# Certificado SSL autogestionado por Google
resource "google_compute_managed_ssl_certificate" "default" {
  project = "efraintest01"
  name    = "ssl-cert-for-react-app"
}

# Regla de reenvío (IP pública) del balanceador
resource "google_compute_global_forwarding_rule" "default" {
  project               = "efraintest01"
  name                  = "forwarding-rule-for-react-app"
  target                = google_compute_target_https_proxy.default.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Finalmente, se asocia la política de Cloud Armor al backend
resource "google_compute_backend_service_security_policy" "default" {
  project         = "efraintest01"
  backend_service = google_compute_region_backend_service.default.name
  security_policy = google_compute_security_policy.armor_policy.name
  region          = "us-central1"
  depends_on = [
    google_compute_region_backend_service.default,
    google_compute_security_policy.armor_policy
  ]
}
