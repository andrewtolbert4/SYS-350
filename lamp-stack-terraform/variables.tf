variable "student_name" {
  type        = string
  description = "Your student identifier"
  validation {
    condition     = can(regex("^[a-z]{2,10}$", var.student_name))
    error_message = "Student name must be 2-10 lowercase letters."
  }
}

variable "web_port" {
  description = "Host port for the first web container"
  type        = number
  default     = 8080
}

variable "web_count" {
  description = "Number of web containers to deploy"
  type        = number
  default     = 1
}

variable "mysql_root_password" {
  type      = string
  default   = "rootpassword"
  sensitive = true
}

variable "mysql_database" {
  type    = string
  default = "myapp"
}

variable "mysql_user" {
  type    = string
  default = "appuser"
}

variable "mysql_password" {
  type      = string
  default   = "apppassword"
  sensitive = true
}
