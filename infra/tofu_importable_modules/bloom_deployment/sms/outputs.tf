output "sms_phone_number" {
  value       = one(aws_pinpointsmsvoicev2_phone_number.api_sms[*].phone_number)
  description = "Phone number provisioned for sending SMS (E.164 format). Null if SMS is not configured."
}