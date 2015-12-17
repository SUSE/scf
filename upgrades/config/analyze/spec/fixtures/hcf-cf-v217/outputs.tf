# © Copyright 2015 Hewlett Packard Enterprise Development LP

output "api_endpoint" {
    value = "https://api.${template_file.domain.rendered}"
}
