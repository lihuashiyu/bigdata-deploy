-- 登录 mysql，切换到 hive 数据库
use ${hive_database};

-- 修改字段注释字符集
alter table ${hive_database}.columns_v2       modify column comment             varchar(2048)  character set utf8mb4;

-- 修改表注释字符集
alter table ${hive_database}.table_params     modify column param_value         varchar(4096)  character set utf8mb4;

-- 修改分区参数，支持分区建用中文表示
alter table ${hive_database}.partition_params modify column param_value         varchar(4096)  character set utf8mb4;
alter table ${hive_database}.partition_keys   modify column pkey_comment        varchar(4096)  character set utf8mb4;

-- 修改索引名注释，支持中文表示
alter table ${hive_database}.index_params     modify column param_value         varchar(4096)  character set utf8mb4;

-- 修改视图，支持视图中文
alter table ${hive_database}.tbls             modify column view_expanded_text  mediumtext     character set utf8mb4;
alter table ${hive_database}.tbls             modify column view_original_text  mediumtext     character set utf8mb4;
