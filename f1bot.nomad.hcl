variable "image_id" {
  type        = string
  description = "ghcr.io/<owner>/<repo> URL"
}

variable "image_version" {
  type = string
}

variable "ghcr_password" {
  type        = string
  description = "Github Container Registry password (personal access token with scope read:packages)"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, staging, prod)"
}

locals {
  config_scope = "apps/f1bot_${var.environment}"
}

job "f1bot-:::INSERT_ENV_HERE:::" {
  datacenters = ["dc1"]
  type = "service"

  group "f1bot" {
    count = 1

    network {
      port "http" {
      }
    }

    task "f1bot-elixir" {
      driver = "docker"

      service {
        name = "f1bot"
      }

      template {
        data = <<EOH
          DISCORD_TOKEN="{{key "${local.config_scope}/DISCORD_TOKEN"}}"

          TWITTER_CONSUMER_KEY="{{key "${local.config_scope}/TWITTER_CONSUMER_KEY"}}"
          TWITTER_CONSUMER_SECRET="{{key "${local.config_scope}/TWITTER_CONSUMER_SECRET"}}"
          TWITTER_ACCESS_TOKEN="{{key "${local.config_scope}/TWITTER_ACCESS_TOKEN"}}"
          TWITTER_ACCESS_TOKEN_SECRET="{{key "${local.config_scope}/TWITTER_ACCESS_TOKEN_SECRET"}}"

          DISCORD_CHANNEL_IDS_MESSAGES="{{key "${local.config_scope}/DISCORD_CHANNEL_IDS_MESSAGES" | regexReplaceAll "#.*" "" | replaceAll "\n" "," }}"
          DISCORD_SERVER_IDS_COMMANDS="{{key "${local.config_scope}/DISCORD_SERVER_IDS_COMMANDS" | regexReplaceAll "#.*" "" | replaceAll "\n" "," }}"

          DATABASE_PATH="{{key "${local.config_scope}/DATABASE_PATH"}}"
          SECRET_KEY_BASE="{{key "${local.config_scope}/SECRET_KEY_BASE"}}"
          PHX_HOST="{{key "${local.config_scope}/PHX_HOST"}}"
          DEMO_MODE_URL="{{key "${local.config_scope}/DEMO_MODE_URL"}}"
        EOH

        destination = ".env"
        change_mode = "noop"
        env         = true
      }

      env {
        PORT = "${NOMAD_PORT_http}"
        PHX_SERVER = "true"
      }

      config {
        image = "${var.image_id}:${var.image_version}"
        auth {
          server_address = split("/", var.image_id)[0]
          username = split("/", var.image_id)[1]
          password = var.ghcr_password
        }
        ports = ["http"]
      }


      resources {
        cpu    = 2000 # Mhz
        memory = 4096 # MB
      }

      kill_timeout = "20s"
    }

    restart {
      # The number of attempts to run the job within the specified interval.
      attempts = 10
      interval = "2m"

      # The "delay" parameter specifies the duration to wait before restarting
      # a task after it has failed.
      delay = "3s"

      # The "mode" parameter controls what happens when a task has restarted
      # "attempts" times within the interval. "delay" mode delays the next
      # restart until the next interval. "fail" mode does not restart the task
      # if "attempts" has been hit within the interval.
      mode = "delay"
    }
  }

  update {
    # The "max_parallel" parameter specifies the maximum number of updates to
    # perform in parallel. In this case, this specifies to update a single task
    # at a time.
    max_parallel = 1
    min_healthy_time = "15s"
    healthy_deadline = "60s"
    progress_deadline = "0"
    auto_revert = true
  }
}
