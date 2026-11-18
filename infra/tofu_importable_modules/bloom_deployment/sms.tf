moved {
  from = aws_pinpointsmsvoicev2_phone_number.api_sms
  to   = module.sms.aws_pinpointsmsvoicev2_phone_number.api_sms
}
