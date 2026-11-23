moved {
  from = aws_ecs_task_definition.bloom_dbinit
  to   = module.ecs_dbinit_task.aws_ecs_task_definition.bloom_dbinit
}

moved {
  from = null_resource.bloom_dbinit_run
  to   = module.ecs_dbinit_task.null_resource.bloom_dbinit_run
}
