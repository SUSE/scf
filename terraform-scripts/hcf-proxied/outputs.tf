output "api_endpoint" {
    value = "https://api.${template_file.domain.rendered}"
}
