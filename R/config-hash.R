config_hash <- function(config) {
  digest::digest(canonical_json(config), algo = "sha256")
}

