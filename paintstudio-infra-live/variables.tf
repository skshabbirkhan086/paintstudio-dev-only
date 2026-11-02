variable "payload_file" {
  description = "The one supported Dev payload (QA and Prod are intentionally excluded)"
  type        = string
  default     = "payloads/dev.json"
  validation {
    condition     = var.payload_file == "payloads/dev.json"
    error_message = "This repository is Dev-only: use payloads/dev.json."
  }
}
