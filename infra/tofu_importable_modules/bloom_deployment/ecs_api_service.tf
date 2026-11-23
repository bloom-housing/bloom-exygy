moved {
  from = aws_ecs_task_definition.bloom_api
  to   = module.ecs_api_service.aws_ecs_task_definition.bloom_api
}

moved {
  from = aws_ecs_service.bloom_api
  to   = module.ecs_api_service.aws_ecs_service.bloom_api
}

moved {
  from = aws_appautoscaling_target.bloom_api_autoscaling_target
  to   = module.ecs_api_service.aws_appautoscaling_target.bloom_api_autoscaling_target
}

moved {
  from = aws_appautoscaling_policy.bloom_api_appautoscaling_policy_request_cpu
  to   = module.ecs_api_service.aws_appautoscaling_policy.bloom_api_appautoscaling_policy_request_cpu
}

moved {
  from = aws_appautoscaling_policy.mbloom_api_appautoscaling_policy_request_memory
  to   = module.ecs_api_service.aws_appautoscaling_policy.bloom_api_appautoscaling_policy_request_memory
}
