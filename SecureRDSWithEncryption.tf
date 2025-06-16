data "aws_rds_db_instance" "sqlserver" {
  engine                     = "sqlserver-se" 
  engine_version             = "14.00.5673.2.v1" 
  storage_type               = "gp3"
  preferred_instance_classes = ["db.r5.xlarge", "db.r5.2xlarge"]
}


data "aws_kms_key" "by_id" {
  key_id = "test-1245" # KMS key
}

resource "aws_db_instance" "example" {
  allocated_storage           = 120
  custom_iam_instance_profile = "AWSRDSSQLServerInstanceProfile"
  backup_retention_period     = 7
  db_subnet_name              = local.db_subnet_name
  engine                      = data.aws_rds_orderable_db_instance.custom-sqlserver.engine
  engine_version              = data.aws_rds_orderable_db_instance.custom-sqlserver.engine_version
  identifier                  = "test-sql-instance"
  instance_class              = data.aws_rds_db_instance.sqlserver.instance_class
  kms_key_id                  = data.aws_kms_key.by_id.arn
  multi_az                    = false
  password                    = "null"
  storage_encrypted           = true
  username                    = "demo"


}
