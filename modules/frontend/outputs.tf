output "s3_bucket_name" {
  value = aws_s3_bucket.this.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "route53_record_fqdn" {
  value = aws_route53_record.root_a_alias.fqdn
}
