moved {
  from = aws_ecs_task_definition.bloom_site_public
  to   = module.ecs_site_public_service.aws_ecs_task_definition.bloom_site_public
}

moved {
  from = aws_ecs_service.bloom_site_public
  to   = module.ecs_site_public_service.aws_ecs_service.bloom_site_public
}

moved {
  from = aws_appautoscaling_target.bloom_site_public_autoscaling_target
  to   = module.ecs_site_public_service.aws_appautoscaling_target.bloom_site_public_autoscaling_target
}

moved {
  from = aws_appautoscaling_policy.bloom_site_public_appautoscaling_policy_request_cpu
  to   = module.ecs_site_public_service.aws_appautoscaling_policy.bloom_site_public_appautoscaling_policy_request_cpu
}

moved {
  from = aws_appautoscaling_policy.bloom_site_public_appautoscaling_policy_request_memory
  to   = module.ecs_site_public_service.aws_appautoscaling_policy.bloom_site_public_appautoscaling_policy_request_memory
}
