variable "server_port" {
  description = "The port the server will use for HTTP request"
  type        = number
  default     = 8080
}

variable "db_remote_state_bucket" {
  type = string
}
variable "db_remote_state_key" {
  type = string
}
