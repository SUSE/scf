#!/bin/bash
set -o errexit -o xtrace
DIR=/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/db/migrations/
SQUASHED_MIGRATIONS=(
    20130131184954_new_initial_schema.rb
    20130219194917_create_stacks_table.rb
    20130313210735_add_extra_to_service.rb
    20130314221003_add_extra_to_service_plans.rb
    20130318175647_convert_mysql_text_types_for_services.rb
    20130323005501_remove_framework_and_runtime.rb
    20130328225143_add_unique_id_to_services.rb
    20130329165619_add_unique_id_to_service_plans.rb
    20130405004709_add_detected_buildpack_to_app.rb
    20130408215903_add_staging_task_id.rb
    20130425230435_add_crash_events.rb
    20130426001853_add_public_to_service_plans.rb
    20130426175420_add_can_access_non_public_plans_to_orgs.rb
    20130429225754_add_salt_to_service_bindings.rb
    20130430184538_add_salt_to_service_auth_tokens.rb
    20130430205654_add_salt_to_service_instances.rb
    20130501002952_use_text_fields_for_service_credentials.rb
    20130501224802_rename_crash_events_to_app_events.rb
    20130503211948_add_rds_column_to_quota.rb
    20130508214259_rename_free_rds_to_trial_db_allowed_in_quota_definition.rb
    20130508220251_add_dashboard_url_to_service_instances.rb
    20130509212940_convert_mysql_type_for_environment_json.rb
    20130515213335_add_kill_after_multiple_restarts_to_apps.rb
    20130522233916_add_deleted_column_to_apps.rb
    20130529183520_add_not_deleted_column.rb
    20130530173342_fix_permission_fk_problems.rb
    20130530210927_add_status_to_organization.rb
    20130603223751_convert_latin1_to_utf8_for_mysql.rb
    20130611175239_create_service_plan_visibilities_table.rb
    20130611235653_drop_organizations_can_access_non_public_plans.rb
    20130621222741_allow_null_service_plan_and_add_kind_on_service_instances.rb
    20130628184803_delete_kind_from_service_instances.rb
    20130628233316_add_is_gateway_service_to_service_instances.rb
    20130712215250_limit_service_instance_name_to_50_chars.rb
    20130718003848_add_index_to_service_instances_on_gateway_name.rb
    20130718210849_add_tasks.rb
    20130718234910_add_bindable_to_services.rb
    20130719002215_remove_not_null_from_unique_id.rb
    20130719214629_add_salt_and_encrypted_env_json_to_app_table.rb
    20130725213922_create_events_table.rb
    20130730000217_create_service_brokers_table.rb
    20130730000318_add_tags_to_service.rb
    20130730214030_lengthen_encrypted_environment_variables.rb
    20130806175100_support_30char_identifiers_for_oracle.rb
    20130814211636_add_secure_token_to_tasks.rb
    20130815225217_add_documentation_url_to_services.rb
    20130821333222_create_buildpacks_table.rb
    20130823211228_add_indices_to_events.rb
    20130824002024_add_broker_id_to_services_and_nullable_provider_version_url.rb
    20130826210728_add_salt_to_service_brokers.rb
    20130829221542_add_unique_index_on_service_plans_unique_id.rb
    20130910221313_add_syslog_drain_url_to_bindings.rb
    20130911111938_encrypt_app_env_json.rb
    20130911220131_add_long_description_to_services.rb
    20130913165030_add_requires_to_services.rb
    20130919164043_denormalize_space_and_add_org_guid_to_events.rb
    20130919211247_add_sequel_delayed_job.rb
    20130927215822_add_admin_buildpack_id_to_apps.rb
    20131002170606_create_droplets.rb
    20131003173318_service_brokers_have_usernames_and_passwords.rb
    20131016215721_rename_priority_to_position.rb
    20131018002858_add_syslog_to_service_instances.rb
    20131018171757_add_active_to_service_plans.rb
    20131022223542_service_instance_credentials_are_optional.rb
    20131024203451_use_text_for_metadata_in_events.rb
    20131104223608_fix_events_timestamps_and_truncate.rb
    20131107223211_add_enabled_to_buildpack.rb
    20131111155640_add_health_check_timeout_to_apps.rb
    20131114185320_add_total_routes_to_quota_definitions.rb
    20131119225844_move_organization_managers_into_organization.rb
    20131212222630_drop_domains_spaces_table.rb
    20131213232039_remove_app_memory_default.rb
    20131217175551_create_app_usage_events.rb
    20140114175047_add_locked_to_buildpack.rb
    20140115094157_add_filename_to_buildpacks.rb
    20140130215438_change_services_provider_default.rb
    20140204221153_add_purging_to_services.rb
    20140206190102_add_dashboard_client_id_to_services.rb
    20140208001107_reset_service_provider_default_value_for_mysql.rb
    20140211223904_drop_domains_organizations.rb
    20140218201113_add_cf_api_error_to_delayed_jobs.rb
    20140220184651_remove_trial_db_allowed.rb
    20140227191931_add_actor_actee_names_to_events.rb
    20140305230940_create_service_dashboard_client.rb
    20140306000008_remove_sso_client_id_from_services.rb
    20140307201639_replace_service_id_on_broker_with_service_broker_id.rb
    20140319191826_add_buildpack_info_to_app_usage_events.rb
    20140324172951_add_detected_buildpack_guid_to_app.rb
    20140325171355_add_service_broker_id_index_to_service_dashboard_clients.rb
    20140402183459_change_app_instances_default.rb
    20140407230239_add_detected_buildpack_name_to_apps.rb
    20140512175050_add_service_usage_event.rb
    20140514210916_add_detected_command_to_droplet.rb
    20140515155207_add_staging_failed_reason_to_apps.rb
    20140528174243_add_app_security_groups.rb
    20140603184619_add_app_security_group_spaces_join_table.rb
    20140609180716_add_staging_default_to_app_security_groups.rb
    20140609234412_add_running_default_to_app_security_groups.rb
    20140623205358_make_name_unique_for_app_security_groups.rb
    20140624232412_change_app_security_groups_to_security_groups.rb
    20140707180618_truncate_securitygroups.rb
    20140708223526_drop_tasks.rb
    20140716213753_add_actee_index_to_events.rb
    20140721225153_add_diego_flag_to_apps.rb
    20140723172206_add_instance_memory_limit_to_quota_definitions.rb
    20140723212942_add_space_quota_definitions.rb
    20140724185938_add_space_quota_definition_to_space.rb
    20140724215343_add_feature_flags.rb
    20140805223232_add_docker_image.rb
    20140811174704_add_error_message_to_feature_flags.rb
    20140819094032_add_environment_variable_groups.rb
    20140826170851_add_salt_and_encrypt_env_group_vars.rb
    20140827202612_add_package_updated_at_to_apps.rb
    20140908220352_add_execution_data_to_droplets.rb
    20140929212559_change_droplet_cols_to_text.rb
    20141008205150_create_lockings.rb
    20141022211551_add_updateable_column_to_services.rb
    20141029182220_create_apps_v3.rb
    20141030213445_add_app_guid_to_processes.rb
    20141105173044_add_package_pending_since_to_apps.rb
    20141120182308_reprocess_diego_apps.rb
    20141120193405_add_type_to_apps.rb
    20141204175821_add_package_state_to_app_usage_events.rb
    20141204180212_add_package_state_to_app_usage_events.rb
    20141210194308_add_name_col_v3_apps.rb
    20141212001210_update_delayed_jobs_indexes.rb
    20141215184824_add_locked_by_to_delayed_jobs_index.rb
    20141216183550_add_health_check_type_to_apps.rb
    20141226222846_create_packages.rb
    20150113000312_add_state_and_state_description_to_service_instances.rb
    20150113201824_fix_created_at_column.rb
    20150122183634_create_v3_droplets.rb
    20150122222844_add_app_guid_to_package.rb
    20150124164257_add_organizations_private_domains.rb
    20150127013821_add_events_index.rb
    20150127194942_create_service_instance_operations.rb
    20150130181135_grow_metadata_column.rb
    20150202222406_revert_accidental_migration_on_service_instances.rb
    20150202222559_make_metadata_column_long_varchar_on_apps.rb
    20150202222600_add_command_to_processes.rb
    20150204012903_drop_state_and_state_description.rb
    20150204222823_add_proposed_changes_to_service_instance_operations.rb
    20150211002332_add_desired_droplet_guid_to_v3_apps.rb
    20150211010713_add_app_guid_to_v3_droplets.rb
    20150211182540_add_failure_reason_to_droplet.rb
    20150211190122_add_detected_start_command_to_droplet.rb
    20150213001251_add_index_to_diego_app_flag.rb
    20150218192154_remove_space_guid_from_v3_packages.rb
    20150220010146_remove_kill_after_multiple_restarts_from_apps.rb
    20150306233007_increase_size_of_delayed_job_handler.rb
    20150311204445_add_desired_state_to_v3_apps.rb
    20150313233039_create_apps_v3_routes.rb
    20150316184259_create_service_key_table.rb
    20150318185941_add_encrypted_environment_variables_to_apps_v3.rb
    20150319150641_add_encrypted_environment_variables_to_v3_droplets.rb
    20150323170053_change_service_instance_description_to_text.rb
    20150323234355_recreate_apps_v3_routes.rb
    20150324232809_add_fk_v3_apps_packages_droplets_processes.rb
    20150325224808_add_v3_attrs_to_app_usage_events.rb
    20150327080540_add_cached_docker_image_to_droplets.rb
    20150403175058_add_index_to_droplets_droplet_hash.rb
    20150403190653_add_procfile_to_droplets.rb
    20150407213536_add_index_to_stack_id.rb
    20150414113235_remove_space_id.rb
    20150421190248_add_allow_ssh_to_app.rb
    20150422000255_route_path_field.rb
    20150430214950_add_allow_ssh_to_spaces.rb
    20150501181106_rename_apps_allow_ssh_to_enable_ssh.rb
    20150511134747_add_docker_image_credentials.rb
    20150514190458_fix_mysql_collations.rb
    20150515230939_add_case_insensitive_to_route_path.rb
    20150521205906_add_tags_to_service_instance.rb
    20150528183140_increase_service_instance_tags_column_length.rb
    20150618190133_add_staging_failed_description_to_app.rb
    20150623175237_add_total_private_domains_to_quota_definitions.rb
    20150625171651_change_stack_description_to_allow_null.rb
    20150625213234_create_service_instance_dashboard_clients.rb
    20150626000000_add_buildpack_to_v3_app.rb
    20150626231641_v3_droplets_generalize_buildpack_field.rb
    20150702004354_add_service_broker_id_to_space.rb
    20150707202136_rename_desired_droplet_guid_to_droplet_guid.rb
    20150709165719_truncate_billing_events_table.rb
    20150710171553_add_app_instance_limit_to_quota_definition.rb
    20150713133551_enlarge_service_keys_credentials.rb
    20150720182530_v3_droplets_error_field.rb
    20150817175317_add_route_service_url_to_service_instance.rb
    20150819230845_add_service_instance_id_to_route.rb
    20150821153140_remove_service_instance_dashboard.rb
    20150827235417_remove_route_service_url_from_service_instances.rb
    20150904215710_create_route_binding_table.rb
    20150910221617_drop_routes_service_instance_id_column.rb
    20150910221699_add_events_index.rb
    20150916213812_add_route_service_url_to_route_binding.rb
    20150928221442_add_router_group_guid_to_shared_domains.rb
    20150928231352_add_app_instance_limit_to_space_quota_definition.rb
    20151006170705_add_port_column_to_routes_table.rb
    20151006224020_add_route_service_url_to_user_provided_service_instances.rb
    20151008211628_add_lifecycle_info_to_droplet.rb
    20151013004418_add_lifecycle_info_to_v3_app.rb
    20151016173720_drop_app_lifecycle_json.rb
    20151016173728_drop_droplet_lifecycle_json.rb
    20151016173751_create_buildpack_lifecycle_data.rb
    20151026231841_add_ports_to_v2_app.rb
    20151028210802_drop_buildpack_from_v3_app_model.rb
    20151102175640_create_package_docker_data.rb
    20151110215644_rename_buildpack_and_stack_in_droplet_model.rb
    20151119192340_add_docker_receipt_to_droplet.rb
    20151123232837_use_text_fields_for_service_tags.rb
    20151124013630_increase_text_size_for_service_instances_tags.rb
    20151217235335_remove_unused_package_cols.rb
    20151222182812_create_v3_service_bindings.rb
    20151231224207_increase_security_group_rules_length.rb
    20160113223027_alter_apps_routes_table.rb
    20160114182148_create_tasks.rb
    20160127192643_add_result_to_tasks.rb
    20160127195206_add_environment_variables_to_tasks.rb
    20160129195310_add_memory_in_mb_to_tasks.rb
    20160203011824_create_route_mappings_table.rb
    20160203013305_add_salt_to_tasks.rb
    20160203223853_add_task_info_to_app_usage_event.rb
    20160210184012_add_app_task_limit_to_quota_definitions.rb
    20160210191133_add_app_task_limit_to_space_quota_definitions.rb
    20160221152904_add_total_service_keys_to_quota_definitions.rb
    20160221153023_add_total_service_keys_to_space_quota_definitions.rb
    20160301215655_add_unique_constraint_on_apps_routes_table.rb
    20160303002319_add_indices_for_filtered_task_columns.rb
    20160303231742_add_package_guid_to_usage_events.rb
    20160322184040_update_app_port.rb
    20160328074419_add_previous_values_in_app_usage_events.rb
    20160411172037_add_total_reserved_route_ports_to_quota_definitions.rb
    20160416005940_add_total_reserved_route_ports_to_space_quota_definitions.rb
    20160502214345_add_volume_mounts_to_service_binding.rb
    20160502225745_add_volume_mounts_salt_to_service_binding.rb
    20160504182904_increase_task_command_size.rb
    20160504214134_increase_volume_mounts_size.rb
    20160504232502_add_volume_mounts_to_v3_service_bindings.rb
    20160510172035_increase_task_environment_variables_size.rb
    20160517190429_rename_memory_limit_to_staging_memory_in_mb_for_v3_droplets.rb
    20160523172247_rename_disk_limit_to_staging_disk_in_mb_for_v3_droplets.rb
    20160601165902_add_broker_provided_operation_to_instance_last_operation.rb
    20160601173727_add_port_to_route_mappings.rb
    20160621182906_remove_space_id_from_events.rb
    20160802210551_add_salt_and_encrypt_buildpack.rb
    20160808182741_isolation_segment.rb
    20160817214144_space_isolation_segment_association.rb
    20160914165525_migrate_v2_app_data_to_v3.rb
    20160919172325_remove_droplet_fk_constraint_for_tasks.rb
    20160920170627_add_task_sequence_id.rb
    20160920175805_add_app_model_max_task_sequence_id.rb
    20160922164519_default_task_sequence_id_to_one.rb
    20160922213611_organization_isolation_segments.rb
    20160926221309_change_service_instance_dashboard_url_to_have_max_length.rb
    20161005205815_fix_droplets_process_types_json.rb
    20161006184718_create_request_counts.rb
    20161006221433_add_valid_until_to_request_counts.rb
    20161011141422_service_binding_volume_mounts_convert_to_2_10_format.rb
    20161024221405_add_disk_in_mb_to_tasks.rb
    20161028210215_add_default_updated_at.rb
    20161104184720_create_staging_security_groups_spaces.rb
    20161114113512_add_bindable_to_service_plans.rb
    20161206005057_add_health_check_http_endpoint_to_processes.rb
    20161215190126_add_sha56_checksum_to_droplet_model.rb
    20170109174921_builpack_cache_sha256_checksum.rb
    20170110195809_builpack_sha256_checksum.rb
    20170111005234_packages_sha256_checksum.rb
    20170201224823_add_username_to_events.rb
    20170214000310_create_clock_jobs.rb
    20170221232946_add_last_completed_at_to_clock_jobs.rb
    20170303011654_add_app_guid_index_to_droplets.rb
    20170303012525_add_app_guid_index_to_packages.rb
    20170321205040_create_build_model.rb
    20170411172945_add_error_description_to_builds.rb
    20170412173354_add_docker_receipt_image_to_builds.rb
    20170413213539_remove_service_instance_id_from_routes.rb
    20170418185436_add_app_guid_to_builds.rb
    20170420184502_add_error_id_to_build.rb
    20170425173340_add_docker_credentials_to_packages.rb
    20170502171127_remove_orphaned_apps.rb
    20170502181209_add_fk_apps_space_guid.rb
    20170504210922_add_docker_creds_to_droplet.rb
    20170505163434_remove_unused_columns_from_builds.rb
    20170505205924_add_app_guid_foreign_key_to_builds.rb
    20170522233826_remove_duplicate_route_mapping_entries.rb
    20170524214613_add_created_by_to_builds.rb
    20170524232621_create_orphaned_blobs.rb
    20170526225825_add_directory_key_to_orphaned_blobs.rb
    20170601205215_add_tasks_app_guid_index.rb
    20170602113045_add_instance_create_schema_to_service_plans.rb
    20170605182822_create_jobs.rb
    20170609172743_add_delayed_job_guid_to_job.rb
    20170609220018_orphaned_blob_index_on_key_and_type.rb
    20170620171034_add_index_for_buildpack_key.rb
    20170620171244_add_compound_index_on_droplet_guid_and_droplet_hash.rb
    20170630224921_create_buildpack_lifecycle_buildpacks.rb
    20170712153045_add_instance_update_schema_to_service_plans.rb
    20170717211406_add_cf_api_error_to_jobs.rb
    20170719182326_add_app_guid_index_to_builds.rb
    20170719182821_add_indices_to_service_bindings.rb
    20170719183350_add_indices_to_service_usage_events.rb
    20170720233439_change_encrypted_docker_password_on_packages.rb
    20170721205940_add_missing_task_stopped_usage_events.rb
    20170724090255_add_binding_create_schema_to_service_plans.rb
    20170724170303_grow_service_instances_syslog_drain_url.rb
    20170724173748_grow_service_bindings_syslog_drain_url.rb
    20170802230125_add_missing_task_stopped_usage_events_second_attempt.rb
    20170814212845_delete_unused_tables.rb
    20170815190541_add_enable_ssh_to_apps.rb
    20170815233431_migrate_enable_ssh_from_processes_to_apps.rb
    20170920143711_create_service_instance_shares.rb
    20171013223336_remove_deprecated_v1_service_fields.rb
    20171103163351_add_name_to_service_bindings.rb
    20171106202032_change_processes_with_health_check_timeout_0_to_nil.rb
    20171120214253_remove_buildpack_receipt_stack_name_from_droplets.rb
    20171123191651_add_index_to_service_binding_on_name.rb
    20171220183100_add_encryption_key_label_column_to_tables_with_encrypted_columns.rb
    20180115151922_add_instances_and_bindings_retrievable_to_services.rb
    20180125181819_add_internal_to_domains.rb
    20180220224558_add_missing_primary_keys.rb
    20180315195737_add_index_to_builds_state.rb
    20180319143620_create_service_binding_operations.rb
    20180419180706_add_process_healthcheck_invocation_timeout.rb
    20180420185709_add_version_bpname_to_buildpack_lifecycle_buildpacks.rb
    20180424202908_create_deployments_table.rb
    20180501171507_add_droplet_guid_to_deployments.rb
    20180502232322_add_stack_to_buildpack.rb
    20180502234947_add_index_to_packages_state.rb
    20180515220732_create_primary_key_for_organizations_auditors.rb
    20180515221609_create_primary_key_for_organizations_billing_managers.rb
    20180515221623_create_primary_key_for_organizations_managers.rb
    20180515221638_create_primary_key_for_organizations_private_domains.rb
    20180515221652_create_primary_key_for_organizations_users.rb
    20180515221706_create_primary_key_for_security_groups_spaces.rb
    20180515221720_create_primary_key_for_spaces_auditors.rb
    20180515221734_create_primary_key_for_spaces_developers.rb
    20180515221748_create_primary_key_for_spaces_managers.rb
    20180515221803_create_primary_key_for_staging_security_groups_spaces.rb
    20180522211345_add_webish_process_to_deployments.rb
    20180523205142_backfill_web_processes_for_v3_apps.rb
    20180628223056_rename_webish_process_guid_on_deployments.rb
    20180703233121_set_missing_fields_for_backfilled_web_processes.rb
    20180710115626_change_broker_catalog_descriptions_to_type_text.rb
    20180726120275_clear_process_command_for_buildpacks.rb
    20180813181554_add_route_weight_to_route_mappings.rb
    20180813221823_clear_process_command_and_metadata_command.rb
    20180814184641_change_encrypted_docker_password_on_droplets.rb
    20180828172307_add_previous_droplet_to_deployments.rb
    20180904174127_add_original_web_process_instance_count_to_deployments.rb
    20180904210247_add_index_to_deployments_on_state.rb
    20180917222717_create_encryption_key_sentinels_table.rb
    20180921102908_remove_uniqueness_on_index_broker_url_from_service_brokers.rb
    20180924142348_remove_uniqueness_on_index_unique_id_from_services.rb
    20180924142407_remove_uniqueness_on_index_unique_id_from_service_plans.rb
    20180925150440_remove_services_label_provider_index.rb
    20180927105539_add_broker_name_and_guid_to_service_usage_event.rb
    20181002165615_create_deployment_processes_table.rb
    20181015223531_create_app_labels.rb
    20181030175334_create_org_labels.rb
    20181031232313_create_space_labels.rb
    20181101211039_drop_and_recreate_app_space_org_labels.rb
    20181107191728_add_revisions.rb
    20181109191715_add_revision_guid_to_deployments.rb
    20181112143236_add_plan_updateable_to_service_plans.rb
    20181112220156_create_app_annotations.rb
    20181112222754_add_version_to_revisions.rb
    20181120230039_increase_app_annotations_resource_guid_column_length.rb
    20181120231620_create_organization_annotations_table.rb
    20181127224109_add_vip_to_routes.rb
    20181129180059_populate_vips.rb
    20181204184506_create_space_annotations_table.rb
    20181207184247_create_droplet_labels_table.rb
    20181211230616_create_droplet_annotations_table.rb
    20181219235732_create_package_labels_table.rb
    20181219235744_create_package_annotations_table.rb
    20181220234322_add_revisions_enabled_to_apps.rb
    20190102192213_add_droplet_guid_to_revision.rb
    20190109223722_create_stack_labels_table.rb
    20190109223733_create_stack_annotations_table.rb
    20190110224601_create_isolation_segment_metadata_tables.rb
    20190110225015_create_task_annotations_table.rb
    20190110225031_create_task_labels_table.rb
    20190116193201_create_process_metadata_tables.rb
    20190116220853_create_revision_labels_table.rb
    20190116220909_create_revision_annotations_table.rb
    20190116225537_create_deployment_metadata_tables.rb
    20190123184851_add_environment_variables_to_revisions.rb
    20190128183942_create_build_labels_table.rb
    20190128183957_create_build_annotations_table.rb
    20190128233032_create_buildpack_metadata_tables.rb
    20190206191247_add_custom_commands_to_revisions.rb
    20190219161111_add_maximum_polling_duration_to_service_plans.rb
    20190220001829_add_encryption_iteration_count_to_apps.rb
    20190220003558_add_encryption_iteration_count_to_buildpack_lifecycle_buildpacks.rb
    20190220003646_add_encryption_iteration_count_to_buildpack_lifecycle_data.rb
    20190220003740_add_encryption_iteration_count_to_droplets.rb
    20190220003808_add_encryption_iteration_count_to_env_groups.rb
    20190220003847_add_encryption_iteration_count_to_packages.rb
    20190220003903_add_encryption_iteration_count_to_revisions.rb
    20190220003916_add_encryption_iteration_count_to_tasks.rb
    20190220004407_add_encryption_iteration_count_to_service_bindings.rb
    20190220004428_add_encryption_iteration_count_to_service_brokers.rb
    20190220004441_add_encryption_iteration_count_to_service_instances.rb
    20190220004454_add_encryption_iteration_count_to_service_keys.rb
    20190221221532_create_revision_process_commands_table.rb
    20190222004908_remove_revisions_encrypted_commands_by_process_type.rb
    20190222190051_add_encryption_iteration_count_to_encryption_key_sentinels.rb
    20190223002950_remove_encryption_iteration_defaults.rb
    20190227175600_add_allow_context_updates_to_services.rb
    20190302003850_add_revision_description_column.rb
    20190319220026_create_sidecars.rb
    20190320234126_create_service_instance_labels_table.rb
    20190320234146_create_service_instance_annotations_table.rb
    20190321214408_change_sidecar_process_type_name_to_type.rb
    20190326212736_add_app_guid_to_sidecar_process_types.rb
)
for f in "${SQUASHED_MIGRATIONS[@]}" ; do
    echo 'Sequel.migration { up {} }' > "${DIR}/${f}"
done
cat > "${DIR}/20190327000000_squashed_migrations.rb" <<"EOF"
Sequel.migration do
  up do
    # Skip the squash-migration if we already have a users table
    # (which probably means this has data from before we did the
    # squashing).
    break if tables.find { |t| t =~ /^users$/ }
    run 'ALTER DATABASE DEFAULT CHARACTER SET utf8;'
    create_table! :app_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :app_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :app_annotations_created_at_index
      index :updated_at, name: :app_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_app_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :app_events, charset: :utf8 do
      String :guid, null: false
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      Integer :app_id, null: false
      String :instance_guid, null: false
      Integer :instance_index, null: false
      Integer :exit_status, null: false
      DateTime :timestamp, null: false
      String :exit_description
      index :app_id, name: :app_events_app_id_index
      index :created_at, name: :app_events_created_at_index
      index :updated_at, name: :app_events_updated_at_index
      index :guid, name: :app_events_guid_index, unique: true
      primary_key :id
    end
    create_table! :app_labels do
      String :guid, null: false
      index :guid, unique: true, name: :app_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :app_labels_created_at_index
      index :updated_at, name: :app_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_app_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :app_labels_compound_index
      primary_key :id
    end
    create_table! :app_usage_events do
      String :guid, null: false
      index :guid, unique: true, name: :app_usage_events_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      index :created_at, name: :usage_events_created_at_index
      Integer :instance_count, null: false
      Integer :memory_in_mb_per_instance, null: false
      String :state, null: false
      String :app_guid, null: false
      String :app_name, null: false
      String :space_guid, null: false
      String :space_name, null: false
      String :org_guid, null: false
      String :buildpack_guid
      String :buildpack_name
      String :package_state
      String :parent_app_name
      String :parent_app_guid
      String :process_type
      String :task_guid, null: true
      String :task_name, null: true
      String :package_guid, default: nil
      String :previous_state, default: nil
      String :previous_package_state, default: nil
      Integer :previous_memory_in_mb_per_instance, default: nil
      Integer :previous_instance_count, default: nil
      primary_key :id
    end
    create_table! :apps, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :apps_v3_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :apps_v3_created_at_index
      index :updated_at, name: :apps_v3_updated_at_index
      String :space_guid
      index :space_guid, name: :apps_v3_space_guid_index
      String :name, case_insensitive: true
      index :name, name: :apps_v3_name_index
      index [:space_guid, :name], unique: true, name: :apps_v3_space_guid_name_index
      String :droplet_guid
      index :droplet_guid, name: :apps_desired_droplet_guid
      String :desired_state, default: "STOPPED"
      String :encrypted_environment_variables, text: true
      String :salt
      Integer :max_task_sequence_id, default: 1
      String :buildpack_cache_sha256_checksum, null: true
      column :enable_ssh, "Boolean", null: true
      String :encryption_key_label, size: 255
      column :revisions_enabled, "Boolean", default: false
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :build_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :build_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :build_annotations_created_at_index
      index :updated_at, name: :build_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_build_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :build_labels do
      String :guid, null: false
      index :guid, unique: true, name: :build_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :build_labels_created_at_index
      index :updated_at, name: :build_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_build_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :build_labels_compound_index
      primary_key :id
    end
    create_table! :buildpack_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :buildpack_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :buildpack_annotations_created_at_index
      index :updated_at, name: :buildpack_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_buildpack_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :buildpack_labels do
      String :guid, null: false
      index :guid, unique: true, name: :buildpack_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :buildpack_labels_created_at_index
      index :updated_at, name: :buildpack_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_buildpack_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :buildpack_labels_compound_index
      primary_key :id
    end
    create_table! :buildpack_lifecycle_buildpacks do
      String :guid, null: false
      index :guid, unique: true, name: :buildpack_lifecycle_buildpacks_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :buildpack_lifecycle_buildpacks_created_at_index
      index :updated_at, name: :buildpack_lifecycle_buildpacks_updated_at_index
      String :admin_buildpack_name
      String :encrypted_buildpack_url, size: 16000
      String :encrypted_buildpack_url_salt
      String :buildpack_lifecycle_data_guid
      index :buildpack_lifecycle_data_guid, name: :bl_buildpack_bldata_guid_index
      String :encryption_key_label, size: 255
      String :version, size: 255
      String :buildpack_name, size: 2047
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :buildpack_lifecycle_data do
      String :guid, null: false
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :buildpack_lifecycle_data_created_at_index
      index :updated_at, name: :buildpack_lifecycle_data_updated_at_index
      String :app_guid
      index :app_guid, name: :buildpack_lifecycle_data_app_guid
      String :droplet_guid
      index :droplet_guid, name: :bp_lifecycle_data_droplet_guid
      String :stack
      String :encrypted_buildpack_url
      String :encrypted_buildpack_url_salt
      String :admin_buildpack_name
      index :admin_buildpack_name, name: :buildpack_lifecycle_data_admin_buildpack_name_index
      index :guid, unique: true, name: :buildpack_lifecycle_data_guid_index
      String :build_guid
      index :build_guid, name: :buildpack_lifecycle_data_build_guid_index
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :buildpacks do
      String :guid, null: false
      index :guid, unique: true, name: :buildpacks_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :buildpacks_created_at_index
      index :updated_at, name: :buildpacks_updated_at_index
      String :name, null: false
      String :key
      Integer :position, null: false
      column :enabled, "Boolean", default: true
      column :locked, "Boolean", default: false
      String :filename
      String :sha256_checksum, null: true
      index :key, name: :buildpacks_key_index
      String :stack, size: 255, null: true
      index [:name, :stack], unique: true, name: :unique_name_and_stack
      primary_key :id
    end
    create_table! :builds do
      String :guid, null: false
      index :guid, unique: true, name: :builds_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :builds_created_at_index
      index :updated_at, name: :builds_updated_at_index
      String :state
      String :package_guid
      String :error_description
      String :app_guid
      String :error_id
      column :created_by_user_guid, :text, null: true
      column :created_by_user_name, :text, null: true
      column :created_by_user_email, :text, null: true
      index :app_guid, name: :builds_app_guid_index
      index :state, name: :builds_state_index
      primary_key :id
    end
    create_table! :clock_jobs do
      String :name, null: false
      index :name, unique: true, name: :clock_jobs_name_unique
      DateTime :last_started_at
      DateTime :last_completed_at
      primary_key :id
    end
    create_table! :delayed_jobs do
      String :guid, null: false
      index :guid, unique: true, name: :dj_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :dj_created_at_index
      index :updated_at, name: :dj_updated_at_index
      Integer :priority, default: 0
      Integer :attempts, default: 0
      column :handler, :longtext, text: true
      String :last_error, text: true
      Time :run_at
      Time :locked_at
      Time :failed_at
      String :locked_by
      String :queue
      String :cf_api_error, text: true
      index [:queue, :locked_at, :locked_by, :failed_at, :run_at], name: :delayed_jobs_reserve
      primary_key :id
    end
    create_table! :deployment_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :deployment_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :deployment_annotations_created_at_index
      index :updated_at, name: :deployment_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_deployment_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :deployment_labels do
      String :guid, null: false
      index :guid, unique: true, name: :deployment_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :deployment_labels_created_at_index
      index :updated_at, name: :deployment_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_deployment_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :deployment_labels_compound_index
      primary_key :id
    end
    create_table! :deployment_processes do
      String :guid, null: false
      index :guid, unique: true, name: :deployment_processes_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :deployment_processes_created_at_index
      index :updated_at, name: :deployment_processes_updated_at_index
      String :process_guid, size: 255
      String :process_type, size: 255
      String :deployment_guid, size: 255
      index :deployment_guid, name: :deployment_processes_deployment_guid_index
      primary_key :id
    end
    create_table! :deployments do
      String :guid, null: false
      index :guid, unique: true, name: :deployments_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :deployments_created_at_index
      index :updated_at, name: :deployments_updated_at_index
      String :state, size: 255
      String :app_guid, size: 255
      index :app_guid, name: :deployments_app_guid_index
      String :droplet_guid, size: 255
      String :deploying_web_process_guid, size: 255
      String :previous_droplet_guid, size: 255
      column :original_web_process_instance_count, :integer, null: false
      index :state, name: :deployments_state_index
      String :revision_guid, size: 255
      Integer :revision_version
      primary_key :id
    end
    create_table! :domains, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :domains_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :domains_created_at_index
      index :updated_at, name: :domains_updated_at_index
      String :name, null: false, case_insensitive: true
      TrueClass :wildcard, default: true, null: false
      Integer :owning_organization_id
      index :name, unique: true, name: :domains_name_index
      String :router_group_guid, default: nil
      column :internal, :boolean, default: false
      primary_key :id
    end
    create_table! :droplet_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :droplet_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :droplet_annotations_created_at_index
      index :updated_at, name: :droplet_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_droplet_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :droplet_labels do
      String :guid, null: false
      index :guid, unique: true, name: :droplet_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :droplet_labels_created_at_index
      index :updated_at, name: :droplet_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_droplet_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :droplet_labels_compound_index
      primary_key :id
    end
    create_table! :droplets do
      String :guid, null: false
      index :guid, unique: true, name: :droplets_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :droplets_created_at_index
      index :updated_at, name: :droplets_updated_at_index
      String :droplet_hash, null: true
      column :execution_metadata, :text
      index :droplet_hash, name: :droplets_droplet_hash_index
      String :state, null: false
      index :state, name: :droplets_state_index
      String :process_types, type: :text
      String :error_id
      String :error_description, type: :text
      String :encrypted_environment_variables, text: true
      String :salt
      Integer :staging_memory_in_mb
      Integer :staging_disk_in_mb
      String :buildpack_receipt_buildpack
      String :buildpack_receipt_buildpack_guid
      String :buildpack_receipt_detect_output
      String :docker_receipt_image
      String :package_guid
      index :package_guid, name: :package_guid_index
      String :app_guid
      String :sha256_checksum, null: true
      index :sha256_checksum, name: :droplets_sha256_checksum_index
      index :app_guid, name: :droplet_app_guid_index
      String :build_guid
      index :build_guid, name: :droplet_build_guid_index
      String :docker_receipt_username
      String :docker_receipt_password_salt
      String :encrypted_docker_receipt_password, size: 16000
      index [:guid, :droplet_hash], name: :droplets_guid_droplet_hash_index
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :encryption_key_sentinels do
      String :guid, null: false
      index :guid, unique: true, name: :encryption_key_sentinels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :encryption_key_sentinels_created_at_index
      index :updated_at, name: :encryption_key_sentinels_updated_at_index
      String :expected_value, size: 255
      String :encrypted_value, size: 255
      String :encryption_key_label, size: 255, unique: true, unique_constraint_name: :encryption_key_sentinels_label_index
      String :salt, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :env_groups do
      String :guid, null: false
      index :guid, unique: true, name: :evg_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :evg_created_at_index
      index :updated_at, name: :evg_updated_at_index
      String :name, null: false
      column :environment_json, :text, default: nil, null: true
      index :name, unique: true, name: :env_groups_name_index
      String :salt
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :events do
      String :guid, null: false
      index :guid, unique: true, name: :events_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at, default: nil, null: true
      index :created_at, name: :events_created_at_index
      index :updated_at, name: :events_updated_at_index
      DateTime :timestamp, null: false
      String :type, null: false
      String :actor, null: false
      String :actor_type, null: false
      String :actee, null: false
      String :actee_type, null: false
      String :metadata, null: true, default: nil, text: "true"
      index :type, name: :events_type_index
      String :organization_guid, null: false, default: ""
      String :space_guid, null: false, default: ""
      String :actor_name
      String :actee_name
      index :actee, name: :events_actee_index
      index :space_guid, name: :events_space_guid_index
      index :organization_guid, name: :events_organization_guid_index
      index :actee_type, name: :events_actee_type_index
      index [:timestamp, :id], name: :events_timestamp_id_index
      String :actor_username
      primary_key :id
    end
    create_table! :feature_flags do
      String :guid, null: false
      index :guid, unique: true, name: :feature_flag_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :feature_flag_created_at_index
      index :updated_at, name: :feature_flag_updated_at_index
      String :name, null: false
      Boolean :enabled, null: false
      index :name, unique: true, name: :feature_flags_name_index
      String :error_message, text: true, default: nil
      primary_key :id
    end
    create_table! :isolation_segment_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :isolation_segment_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :isolation_segment_annotations_created_at_index
      index :updated_at, name: :isolation_segment_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_isolation_segment_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :isolation_segment_labels do
      String :guid, null: false
      index :guid, unique: true, name: :isolation_segment_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :isolation_segment_labels_created_at_index
      index :updated_at, name: :isolation_segment_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_isolation_segment_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :isolation_segment_labels_compound_index
      primary_key :id
    end
    create_table! :isolation_segments do
      String :guid, null: false
      index :guid, unique: true, name: :isolation_segments_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :isolation_segments_created_at_index
      index :updated_at, name: :isolation_segments_updated_at_index
      String :name, null: false, case_insensitive: :true
      index :name, name: :isolation_segments_name_index
      unique :name, name: :isolation_segment_name_unique_constraint
      primary_key :id
    end
    create_table! :jobs do
      String :guid, null: false
      index :guid, unique: true, name: :jobs_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :jobs_created_at_index
      index :updated_at, name: :jobs_updated_at_index
      String :state
      String :operation
      String :resource_guid
      String :resource_type
      String :delayed_job_guid
      String :cf_api_error, size: 16000, null: true
      primary_key :id
    end
    create_table! :lockings do
      String :name, null: false, case_insenstive: true
      index :name, unique: true, name: :lockings_name_index
      primary_key :id
    end
    create_table! :organization_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :organization_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :organization_annotations_created_at_index
      index :updated_at, name: :organization_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_organization_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :organization_labels do
      String :guid, null: false
      index :guid, unique: true, name: :organization_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :organization_labels_created_at_index
      index :updated_at, name: :organization_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_organization_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :organization_labels_compound_index
      primary_key :id
    end
    create_table! :organizations, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :organizations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :organizations_created_at_index
      index :updated_at, name: :organizations_updated_at_index
      String :name, null: false, case_insensitive: true
      TrueClass :billing_enabled, null: false, default: false
      Integer :quota_definition_id, null: false
      index :name, unique: true, name: :organizations_name_index
      String :status, default: "active"
      String :default_isolation_segment_guid, collate: :utf8_bin
      primary_key :id
    end
    create_table! :organizations_auditors, charset: :utf8 do
      Integer :organization_id, null: false
      Integer :user_id, null: false
      index [:organization_id, :user_id], unique: true, name: :org_auditors_idx
      primary_key :id, name: :organizations_auditors_pk
    end
    create_table! :organizations_billing_managers, charset: :utf8 do
      Integer :organization_id, null: false
      Integer :user_id, null: false
      index [:organization_id, :user_id], unique: true, name: :org_billing_managers_idx
      primary_key :id, name: :organizations_billing_managers_pk
    end
    create_table! :organizations_isolation_segments do
      String :organization_guid, null: false
      String :isolation_segment_guid, null: false
      primary_key [:organization_guid, :isolation_segment_guid], name: :organizations_isolation_segments_pk
    end
    create_table! :organizations_managers, charset: :utf8 do
      Integer :organization_id, null: false
      Integer :user_id, null: false
      index [:organization_id, :user_id], unique: true, name: :org_managers_idx
      primary_key :id, name: :organizations_managers_pk
    end
    create_table! :organizations_private_domains do
      Integer :organization_id, null: false
      Integer :private_domain_id, null: false
      index [:organization_id, :private_domain_id], unique: true, name: :orgs_pd_ids
      primary_key :id, name: :organizations_private_domains_pk
    end
    create_table! :organizations_users, charset: :utf8 do
      Integer :organization_id, null: false
      Integer :user_id, null: false
      index [:organization_id, :user_id], unique: true, name: :org_users_idx
      primary_key :id, name: :organizations_users_pk
    end
    create_table! :orphaned_blobs do
      String :guid, null: false
      index :guid, unique: true, name: :orphaned_blobs_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :orphaned_blobs_created_at_index
      index :updated_at, name: :orphaned_blobs_updated_at_index
      String :blob_key
      Integer :dirty_count
      String :blobstore_type
      index [:blob_key, :blobstore_type], name: :orphaned_blobs_unique_blob_index, unique: true
      primary_key :id
    end
    create_table! :package_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :package_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :package_annotations_created_at_index
      index :updated_at, name: :package_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_package_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :package_labels do
      String :guid, null: false
      index :guid, unique: true, name: :package_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :package_labels_created_at_index
      index :updated_at, name: :package_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_package_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :package_labels_compound_index
      primary_key :id
    end
    create_table! :packages, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :packages_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :packages_created_at_index
      index :updated_at, name: :packages_updated_at_index
      String :type
      index :type, name: :packages_type_index
      String :package_hash
      String :state, null: false
      String :error, text: true
      String :app_guid
      String :docker_image, type: :text
      String :sha256_checksum, null: true
      index :app_guid, name: :package_app_guid_index
      String :docker_username
      String :docker_password_salt
      String :encrypted_docker_password, size: 16000
      String :encryption_key_label, size: 255
      index :state, name: :packages_state_index
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :process_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :process_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :process_annotations_created_at_index
      index :updated_at, name: :process_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_process_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :process_labels do
      String :guid, null: false
      index :guid, unique: true, name: :process_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :process_labels_created_at_index
      index :updated_at, name: :process_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_process_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :process_labels_compound_index
      primary_key :id
    end
    create_table! :processes, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :apps_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :apps_created_at_index
      index :updated_at, name: :apps_updated_at_index
      Boolean :production, default: false
      Integer :memory, default: nil
      Integer :instances, default: 1
      Integer :file_descriptors, default: 16384
      Integer :disk_quota, default: 2048
      String :state, null: false, default: "STOPPED"
      String :version
      String :metadata, default: "{}", null: false, size: 4096
      String :detected_buildpack
      column :not_deleted, "Boolean", default: true
      Integer :health_check_timeout
      TrueClass :diego, default: false
      Time :package_updated_at, default: nil
      String :app_guid, index: true
      String :type, default: "web"
      String :health_check_type, default: "port"
      String :command, size: 4096
      index :diego, name: :apps_diego_index
      TrueClass :enable_ssh, default: false
      String :encrypted_docker_credentials_json
      String :docker_salt
      String :ports, text: true
      String :health_check_http_endpoint, text: true
      column :health_check_invocation_timeout, :integer, null: true, default: nil
      String :revision_guid, size: 255
      primary_key :id
    end
    create_table! :quota_definitions, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :qd_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :qd_created_at_index
      index :updated_at, name: :qd_updated_at_index
      String :name, null: false, unique: true, case_insensitive: true
      Boolean :non_basic_services_allowed, null: false
      Integer :total_services, null: false
      Integer :memory_limit, null: false
      index :name, unique: true, name: :qd_name_index
      column :total_routes, :integer, null: false
      Integer :instance_memory_limit, null: false, default: -1
      column :total_private_domains, :integer, null: false, default: -1
      Integer :app_instance_limit, default: -1
      Integer :app_task_limit, default: -1
      Integer :total_service_keys, default: -1
      Integer :total_reserved_route_ports, default: 0
      primary_key :id
    end
    create_table! :request_counts do
      String :user_guid
      index :user_guid, name: :request_counts_user_guid_index
      Integer :count, default: 0
      Time :valid_until
      primary_key :id
    end
    create_table! :revision_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :revision_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :revision_annotations_created_at_index
      index :updated_at, name: :revision_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_revision_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :revision_labels do
      String :guid, null: false
      index :guid, unique: true, name: :revision_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :revision_labels_created_at_index
      index :updated_at, name: :revision_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_revision_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :revision_labels_compound_index
      primary_key :id
    end
    create_table! :revision_process_commands do
      String :guid, null: false
      index :guid, unique: true, name: :revision_process_commands_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :revision_process_commands_created_at_index
      index :updated_at, name: :revision_process_commands_updated_at_index
      String :revision_guid, size: 255, null: false
      index :revision_guid, name: :rev_commands_revision_guid_index
      String :process_type, size: 255, null: false
      String :process_command, size: 4096
      primary_key :id
    end
    create_table! :revisions do
      String :guid, null: false
      index :guid, unique: true, name: :revisions_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :revisions_created_at_index
      index :updated_at, name: :revisions_updated_at_index
      String :app_guid, size: 255
      index :app_guid, name: :fk_revision_app_guid_index
      Integer :version, default: 1
      String :droplet_guid, size: 255
      String :encrypted_environment_variables, size: 16000
      String :salt, size: 255
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      String :description, text: true, default: "N/A", null: false
      primary_key :id
    end
    create_table! :route_bindings do
      String :guid, null: false
      index :guid, unique: true, name: :route_bindings_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :route_bindings_created_at_index
      index :updated_at, name: :route_bindings_updated_at_index
      String :route_service_url, default: nil
      primary_key :id
    end
    create_table! :route_mappings, charset: :utf8 do
      column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamp
      Integer :app_port, default: -1
      String :guid, null: false
      index :guid, unique: true, name: :apps_routes_guid_index
      index :created_at, name: :apps_routes_created_at_index
      index :updated_at, name: :apps_routes_updated_at_index
      String :app_guid, collate: :utf8_bin, null: false
      String :route_guid, collate: :utf8_bin, null: false
      String :process_type
      index :process_type, name: :route_mappings_process_type_index
      unique [:app_guid, :route_guid, :process_type, :app_port], name: :route_mappings_app_guid_route_guid_process_type_app_port_key
      column :weight, :integer, default: 1
      primary_key :id
    end
    create_table! :routes, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :routes_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :routes_created_at_index
      index :updated_at, name: :routes_updated_at_index
      String :host, null: false, default: "", case_insensitive: true
      Integer :domain_id, null: false
      Integer :space_id, null: false
      String :path, default: "", null: false, case_insensitive: true
      Integer :port, null: false, default: 0
      index [:host, :domain_id, :path, :port], unique: true, name: :routes_host_domain_id_path_port_index
      Integer :vip_offset, null: true, default: nil
      index :vip_offset, unique: true, name: :routes_vip_offset_index
      primary_key :id
    end
    create_table! :security_groups do
      String :guid, null: false
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      String :name, null: false
      column :rules, :mediumtext
      TrueClass :staging_default, default: false, required: true
      FalseClass :running_default, default: false, required: true
      index :guid, name: :sg_guid_index
      index :created_at, name: :sg_created_at_index
      index :updated_at, name: :sg_updated_at_index
      index :staging_default, name: :sgs_staging_default_index
      index :running_default, name: :sgs_running_default_index
      index :name, name: :sg_name_index
      primary_key :id
    end
    create_table! :security_groups_spaces do
      Integer :security_group_id, null: false
      Integer :space_id, null: false
      index [:security_group_id, :space_id], name: :sgs_spaces_ids
      primary_key :id, name: :security_groups_spaces_pk
    end
    create_table! :service_binding_operations do
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :service_binding_operations_created_at_index
      index :updated_at, name: :service_binding_operations_updated_at_index
      Integer :service_binding_id
      String :state, size: 255, null: false
      String :type, size: 255, null: false
      String :description, size: 10000
      String :broker_provided_operation, size: 10000
      index :service_binding_id, name: :svc_binding_id_index, unique: true
      primary_key :id, name: :id
    end
    create_table! :service_bindings, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :sb_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :sb_created_at_index
      index :updated_at, name: :sb_updated_at_index
      String :credentials, null: false, text: true
      String :salt
      String :syslog_drain_url, text: true
      String :volume_mounts, text: true
      String :volume_mounts_salt
      String :app_guid, null: false, collate: :utf8_bin
      String :service_instance_guid, null: false, collate: :utf8_bin
      String :type
      index :app_guid, name: :service_bindings_app_guid_index
      index :service_instance_guid, name: :service_bindings_service_instance_guid_index
      String :name, size: 255, null: true
      unique [:app_guid, :name], name: :unique_service_binding_app_guid_name
      index :name, name: :service_bindings_name_index
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :service_brokers do
      String :guid, null: false
      index :guid, unique: true, name: :sbrokers_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :sbrokers_created_at_index
      index :updated_at, name: :sbrokers_updated_at_index
      String :name, null: false
      String :broker_url, null: false
      String :auth_password, null: false
      index :name, unique: true, name: :service_brokers_name_index
      String :salt
      String :auth_username
      String :encryption_key_label, size: 255
      index :broker_url, name: :sb_broker_url_index, unique: false
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :service_dashboard_clients do
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :s_d_clients_created_at_index
      index :updated_at, name: :s_d_clients_updated_at_index
      String :uaa_id, null: false
      index :uaa_id, unique: true, name: :s_d_clients_uaa_id_unique
      Integer :service_broker_id, null: true
      index :service_broker_id, name: :svc_dash_cli_svc_brkr_id_idx
      primary_key :id
    end
    create_table! :service_instance_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :service_instance_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :service_instance_annotations_created_at_index
      index :updated_at, name: :service_instance_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_service_instance_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :service_instance_labels do
      String :guid, null: false
      index :guid, unique: true, name: :service_instance_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :service_instance_labels_created_at_index
      index :updated_at, name: :service_instance_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_service_instance_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :service_instance_labels_compound_index
      primary_key :id
    end
    create_table! :service_instance_operations do
      String :guid, null: false
      index :guid, unique: true, name: :svc_inst_op_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :svc_inst_op_created_at_index
      index :updated_at, name: :svc_inst_op_updated_at_index
      Integer :service_instance_id
      index :service_instance_id, name: :svc_instance_id_index
      String :type
      String :state
      String :description, text: true
      String :proposed_changes, null: false, default: "{}"
      String :broker_provided_operation, text: true
      primary_key :id
    end
    create_table! :service_instance_shares do
      String :service_instance_guid, null: false, size: 255
      String :target_space_guid, null: false, size: 255
      primary_key [:service_instance_guid, :target_space_guid], name: :service_instance_target_space_pk
    end
    create_table! :service_instances, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :si_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :si_created_at_index
      index :updated_at, name: :si_updated_at_index
      String :name, null: false, case_insensitive: true
      String :credentials, null: true, text: true
      String :gateway_name
      String :gateway_data, size: 2048
      Integer :space_id, null: false
      Integer :service_plan_id, null: true
      index :name, name: :service_instances_name_index
      String :salt
      String :dashboard_url, size: 16000
      TrueClass :is_gateway_service, default: true, null: false
      index [:space_id, :name], unique: true, name: :si_space_id_name_index
      index :gateway_name, name: :si_gateway_name_index
      String :syslog_drain_url, text: true
      String :tags, text: true
      String :route_service_url, default: nil
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :service_keys do
      String :guid, null: false
      index :guid, unique: true, name: :sk_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :sk_created_at_index
      index :updated_at, name: :sk_updated_at_index
      String :name, null: false
      String :salt
      String :credentials, null: false, text: true
      Integer :service_instance_id, null: false
      index [:name, :service_instance_id], unique: true, name: :svc_key_name_instance_id_index
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :service_plan_visibilities do
      String :guid, null: false
      index :guid, unique: true, name: :spv_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :spv_created_at_index
      index :updated_at, name: :spv_updated_at_index
      Integer :service_plan_id, null: false
      Integer :organization_id, null: false
      index [:organization_id, :service_plan_id], unique: true, name: :spv_org_id_sp_id_index
      primary_key :id
    end
    create_table! :service_plans, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :service_plans_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :service_plans_created_at_index
      index :updated_at, name: :service_plans_updated_at_index
      String :name, null: false, case_insensitive: true
      String :description, null: false, text: true
      TrueClass :free, null: false
      Integer :service_id, null: false
      column :extra, :MediumText
      String :unique_id, null: false
      column :public, :boolean, default: true
      index [:service_id, :name], unique: true, name: :svc_plan_svc_id_name_index
      column :active, "Boolean", default: true
      TrueClass :bindable, null: true
      column :create_instance_schema, :text, null: true
      column :update_instance_schema, :text, null: true
      column :create_binding_schema, :text, null: true
      index :unique_id, name: :service_plans_unique_id_index, unique: false
      TrueClass :plan_updateable, null: true
      Integer :maximum_polling_duration, null: true
      primary_key :id
    end
    create_table! :service_usage_events do
      String :guid, null: false
      index :guid, unique: true, name: :usage_events_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      index :created_at, name: :created_at_index
      String :state, null: false
      String :org_guid, null: false
      String :space_guid, null: false
      String :space_name, null: false
      String :service_instance_guid, null: false
      String :service_instance_name, null: false
      String :service_instance_type, null: false
      String :service_plan_guid, null: true
      String :service_plan_name, null: true
      String :service_guid, null: true
      String :service_label, null: true
      index :service_guid, name: :service_usage_events_service_guid_index
      index :service_instance_type, name: :service_usage_events_service_instance_type_index
      String :service_broker_name, null: true
      String :service_broker_guid, null: true, size: 255
      primary_key :id
    end
    create_table! :services, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :services_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :services_created_at_index
      index :updated_at, name: :services_updated_at_index
      String :label, null: false, case_insensitive: true
      String :description, null: false, text: true
      String :info_url
      String :acls
      Integer :timeout
      Boolean :active, default: false
      index :label, name: :services_label_index
      column :extra, :MediumText
      String :unique_id, null: true
      TrueClass :bindable, null: false
      String :tags, text: true
      String :documentation_url
      Integer :service_broker_id
      String :long_description, text: true
      String :requires
      TrueClass :purging, default: false, null: false
      column :plan_updateable, :boolean, default: false
      column :bindings_retrievable, :boolean, default: false, null: false
      column :instances_retrievable, :boolean, default: false, null: false
      index :unique_id, name: :services_unique_id_index, unique: false
      column :allow_context_updates, :boolean, default: false, null: false
      primary_key :id
    end
    create_table! :sidecar_process_types do
      String :guid, null: false
      index :guid, unique: true, name: :sidecar_process_types_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :sidecar_process_types_created_at_index
      index :updated_at, name: :sidecar_process_types_updated_at_index
      String :type, size: 255, null: false
      String :sidecar_guid, size: 255, null: false
      index :sidecar_guid, name: :fk_sidecar_proc_type_sidecar_guid_index
      String :app_guid, size: 255, null: false
      primary_key :id
    end
    create_table! :sidecars do
      String :guid, null: false
      index :guid, unique: true, name: :sidecars_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :sidecars_created_at_index
      index :updated_at, name: :sidecars_updated_at_index
      String :name, size: 255, null: false
      String :command, size: 4096, null: false
      String :app_guid, size: 255, null: false
      index :app_guid, name: :fk_sidecar_app_guid_index
      primary_key :id
    end
    create_table! :space_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :space_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :space_annotations_created_at_index
      index :updated_at, name: :space_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_space_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :space_labels do
      String :guid, null: false
      index :guid, unique: true, name: :space_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :space_labels_created_at_index
      index :updated_at, name: :space_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_space_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :space_labels_compound_index
      primary_key :id
    end
    create_table! :space_quota_definitions do
      String :guid, null: false
      index :guid, unique: true, name: :sqd_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :sqd_created_at_index
      index :updated_at, name: :sqd_updated_at_index
      String :name, null: false
      Boolean :non_basic_services_allowed, null: false
      Integer :total_services, null: false
      Integer :memory_limit, null: false
      Integer :total_routes, null: false
      Integer :instance_memory_limit, null: false, default: -1
      Integer :organization_id, null: false
      index [:organization_id, :name], unique: true, name: :sqd_org_id_index
      Integer :app_instance_limit, default: -1
      Integer :app_task_limit, default: 5
      Integer :total_service_keys, null: false, default: -1
      Integer :total_reserved_route_ports, default: -1
      primary_key :id
    end
    create_table! :spaces, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :spaces_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :spaces_created_at_index
      index :updated_at, name: :spaces_updated_at_index
      String :name, null: false, case_insensitive: true
      Integer :organization_id, null: false
      index [:organization_id, :name], unique: true, name: :spaces_org_id_name_index
      Integer :space_quota_definition_id
      TrueClass :allow_ssh, default: true
      String :isolation_segment_guid, collate: :utf8_bin
      primary_key :id
    end
    create_table! :spaces_auditors, charset: :utf8 do
      Integer :space_id, null: false
      Integer :user_id, null: false
      index [:space_id, :user_id], unique: true, name: :space_auditors_idx
      primary_key :id, name: :spaces_auditors_pk
    end
    create_table! :spaces_developers, charset: :utf8 do
      Integer :space_id, null: false
      Integer :user_id, null: false
      index [:space_id, :user_id], unique: true, name: :space_developers_idx
      primary_key :id, name: :spaces_developers_pk
    end
    create_table! :spaces_managers, charset: :utf8 do
      Integer :space_id, null: false
      Integer :user_id, null: false
      index [:space_id, :user_id], unique: true, name: :space_managers_idx
      primary_key :id, name: :spaces_managers_pk
    end
    create_table! :stack_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :stack_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :stack_annotations_created_at_index
      index :updated_at, name: :stack_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_stack_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :stack_labels do
      String :guid, null: false
      index :guid, unique: true, name: :stack_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :stack_labels_created_at_index
      index :updated_at, name: :stack_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_stack_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :stack_labels_compound_index
      primary_key :id
    end
    create_table! :stacks, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :stacks_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :stacks_created_at_index
      index :updated_at, name: :stacks_updated_at_index
      String :name, null: false, case_insenstive: true
      String :description, null: true
      index :name, unique: true, name: :stacks_name_index
      primary_key :id
    end
    create_table! :staging_security_groups_spaces do
      Integer :staging_security_group_id, null: false
      Integer :staging_space_id, null: false
      index [:staging_security_group_id, :staging_space_id], unique: true, name: :staging_security_groups_spaces_ids
      primary_key :id, name: :staging_security_groups_spaces_pk
    end
    create_table! :task_annotations do
      String :guid, null: false
      index :guid, unique: true, name: :task_annotations_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :task_annotations_created_at_index
      index :updated_at, name: :task_annotations_updated_at_index
      String :resource_guid, size: 255
      String :key, size: 1000
      String :value, size: 5000
      index :resource_guid, name: :fk_task_annotations_resource_guid_index
      primary_key :id
    end
    create_table! :task_labels do
      String :guid, null: false
      index :guid, unique: true, name: :task_labels_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :task_labels_created_at_index
      index :updated_at, name: :task_labels_updated_at_index
      String :resource_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63
      index :resource_guid, name: :fk_task_labels_resource_guid_index
      index [:key_prefix, :key_name, :value], name: :task_labels_compound_index
      primary_key :id
    end
    create_table! :tasks do
      String :guid, null: false
      index :guid, unique: true, name: :tasks_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :tasks_created_at_index
      index :updated_at, name: :tasks_updated_at_index
      String :name, case_insensitive: true, null: false
      index :name, name: :tasks_name_index
      String :command, null: false, text: true
      String :state, null: false
      index :state, name: :tasks_state_index
      Integer :memory_in_mb, null: true
      String :encrypted_environment_variables, text: true, null: true
      String :salt, null: true
      String :failure_reason, null: true, size: 4096
      String :app_guid, null: false
      String :droplet_guid, null: false
      index :droplet_guid, name: :fk_tasks_droplet_guid
      Integer :sequence_id
      unique [:app_guid, :sequence_id], name: :unique_task_app_guid_sequence_id
      Integer :disk_in_mb
      index :app_guid, name: :tasks_app_guid_index
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false
      primary_key :id
    end
    create_table! :users, charset: :utf8 do
      String :guid, null: false
      index :guid, unique: true, name: :users_guid_index
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at
      index :created_at, name: :users_created_at_index
      index :updated_at, name: :users_updated_at_index
      Integer :default_space_id
      Boolean :admin, default: false
      Boolean :active, default: false
      primary_key :id
    end
    alter_table :app_annotations do
      add_foreign_key [:resource_guid], :apps, key: :guid, name: :fk_app_annotations_resource_guid
    end
    alter_table :app_events do
      add_foreign_key [:app_id], :processes, name: :fk_app_events_app_id
    end
    alter_table :app_labels do
      add_foreign_key [:resource_guid], :apps, key: :guid, name: :fk_app_labels_resource_guid
    end
    alter_table :apps do
      add_foreign_key [:space_guid], :spaces, key: :guid, name: :fk_apps_space_guid
    end
    alter_table :build_annotations do
      add_foreign_key [:resource_guid], :builds, key: :guid, name: :fk_build_annotations_resource_guid
    end
    alter_table :build_labels do
      add_foreign_key [:resource_guid], :builds, key: :guid, name: :fk_build_labels_resource_guid
    end
    alter_table :buildpack_annotations do
      add_foreign_key [:resource_guid], :buildpacks, key: :guid, name: :fk_buildpack_annotations_resource_guid
    end
    alter_table :buildpack_labels do
      add_foreign_key [:resource_guid], :buildpacks, key: :guid, name: :fk_buildpack_labels_resource_guid
    end
    alter_table :buildpack_lifecycle_buildpacks do
      add_foreign_key [:buildpack_lifecycle_data_guid], :buildpack_lifecycle_data, key: :guid, name: :fk_blbuildpack_bldata_guid
    end
    alter_table :builds do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_builds_app_guid
    end
    alter_table :deployment_annotations do
      add_foreign_key [:resource_guid], :deployments, key: :guid, name: :fk_deployment_annotations_resource_guid
    end
    alter_table :deployment_labels do
      add_foreign_key [:resource_guid], :deployments, key: :guid, name: :fk_deployment_labels_resource_guid
    end
    alter_table :deployment_processes do
      add_foreign_key [:deployment_guid], :deployments, key: :guid, name: :fk_deployment_processes_deployment_guid
    end
    alter_table :deployments do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :deployments_app_guid_fkey
    end
    alter_table :domains do
      add_foreign_key [:owning_organization_id], :organizations, name: :fk_domains_owning_org_id
    end
    alter_table :droplet_annotations do
      add_foreign_key [:resource_guid], :droplets, key: :guid, name: :fk_droplet_annotations_resource_guid
    end
    alter_table :droplet_labels do
      add_foreign_key [:resource_guid], :droplets, key: :guid, name: :fk_droplet_labels_resource_guid
    end
    alter_table :droplets do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_droplets_app_guid
    end
    alter_table :isolation_segment_annotations do
      add_foreign_key [:resource_guid], :isolation_segments, key: :guid, name: :fk_isolation_segment_annotations_resource_guid
    end
    alter_table :isolation_segment_labels do
      add_foreign_key [:resource_guid], :isolation_segments, key: :guid, name: :fk_isolation_segment_labels_resource_guid
    end
    alter_table :organization_annotations do
      add_foreign_key [:resource_guid], :organizations, key: :guid, name: :fk_organization_annotations_resource_guid
    end
    alter_table :organization_labels do
      add_foreign_key [:resource_guid], :organizations, key: :guid, name: :fk_organization_labels_resource_guid
    end
    alter_table :organizations do
      add_foreign_key [:quota_definition_id], :quota_definitions, name: :fk_org_quota_definition_id
      add_foreign_key [:guid, :default_isolation_segment_guid], :organizations_isolation_segments, name: "organizations_isolation_segments_pk"
    end
    alter_table :organizations_auditors do
      add_foreign_key [:organization_id], :organizations, name: :org_auditors_org_fk
      add_foreign_key [:user_id], :users, name: :org_auditors_user_fk
    end
    alter_table :organizations_billing_managers do
      add_foreign_key [:organization_id], :organizations, name: :org_billing_managers_org_fk
      add_foreign_key [:user_id], :users, name: :org_billing_managers_user_fk
    end
    alter_table :organizations_isolation_segments do
      add_foreign_key [:organization_guid], :organizations, key: :guid, name: :fk_organization_guid
      add_foreign_key [:isolation_segment_guid], :isolation_segments, key: :guid, name: :fk_isolation_segments_guid
    end
    alter_table :organizations_managers do
      add_foreign_key [:organization_id], :organizations, name: :org_managers_org_fk
      add_foreign_key [:user_id], :users, name: :org_managers_user_fk
    end
    alter_table :organizations_private_domains do
      add_foreign_key [:organization_id], :organizations, name: :fk_organization_id
      add_foreign_key [:private_domain_id], :domains, name: :fk_private_domain_id
    end
    alter_table :organizations_users do
      add_foreign_key [:organization_id], :organizations, name: :org_users_org_fk
      add_foreign_key [:user_id], :users, name: :org_users_user_fk
    end
    alter_table :package_annotations do
      add_foreign_key [:resource_guid], :packages, key: :guid, name: :fk_package_annotations_resource_guid
    end
    alter_table :package_labels do
      add_foreign_key [:resource_guid], :packages, key: :guid, name: :fk_package_labels_resource_guid
    end
    alter_table :packages do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_packages_app_guid
    end
    alter_table :process_annotations do
      add_foreign_key [:resource_guid], :processes, key: :guid, name: :fk_process_annotations_resource_guid
    end
    alter_table :process_labels do
      add_foreign_key [:resource_guid], :processes, key: :guid, name: :fk_process_labels_resource_guid
    end
    alter_table :processes do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_processes_app_guid
    end
    alter_table :revision_annotations do
      add_foreign_key [:resource_guid], :revisions, key: :guid, name: :fk_revision_annotations_resource_guid
    end
    alter_table :revision_labels do
      add_foreign_key [:resource_guid], :revisions, key: :guid, name: :fk_revision_labels_resource_guid
    end
    alter_table :revision_process_commands do
      add_foreign_key [:revision_guid], :revisions, key: :guid, name: :rev_commands_revision_guid_fkey
    end
    alter_table :revisions do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_revision_app_guid
    end
    alter_table :route_bindings do
      add_foreign_key :route_id, :routes
      add_foreign_key :service_instance_id, :service_instances
    end
    alter_table :route_mappings do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_route_mappings_app_guid
      add_foreign_key [:route_guid], :routes, key: :guid, name: :fk_route_mappings_route_guid
    end
    alter_table :routes do
      add_foreign_key [:domain_id], :domains, name: :fk_routes_domain_id
      add_foreign_key [:space_id], :spaces, name: :fk_routes_space_id
    end
    alter_table :security_groups_spaces do
      add_foreign_key [:space_id], :spaces, name: :fk_space_id
      add_foreign_key [:security_group_id], :security_groups, name: :fk_security_group_id
    end
    alter_table :service_binding_operations do
      add_foreign_key [:service_binding_id], :service_bindings, name: :fk_svc_binding_op_svc_binding_id, on_delete: :cascade
    end
    alter_table :service_bindings do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_service_bindings_app_guid
      add_foreign_key [:service_instance_guid], :service_instances, key: :guid, name: :fk_service_bindings_service_instance_guid
    end
    alter_table :service_brokers do
      add_foreign_key :space_id, :spaces
    end
    alter_table :service_instance_annotations do
      add_foreign_key [:resource_guid], :service_instances, key: :guid, name: :fk_service_instance_annotations_resource_guid
    end
    alter_table :service_instance_labels do
      add_foreign_key [:resource_guid], :service_instances, key: :guid, name: :fk_service_instance_labels_resource_guid
    end
    alter_table :service_instance_operations do
      add_foreign_key [:service_instance_id], :service_instances, name: :fk_svc_inst_op_svc_instance_id
    end
    alter_table :service_instance_shares do
      add_foreign_key [:service_instance_guid], :service_instances, key: :guid, name: :fk_service_instance_guid, on_delete: :cascade
      add_foreign_key [:target_space_guid], :spaces, key: :guid, name: :fk_target_space_guid, on_delete: :cascade
    end
    alter_table :service_instances do
      add_foreign_key [:service_plan_id], :service_plans, name: :svc_instances_service_plan_id
      add_foreign_key [:space_id], :spaces, name: :service_instances_space_id
    end
    alter_table :service_keys do
      add_foreign_key [:service_instance_id], :service_instances, name: :fk_svc_key_svc_instance_id
    end
    alter_table :service_plan_visibilities do
      add_foreign_key [:service_plan_id], :service_plans, name: :fk_spv_service_plan_id
      add_foreign_key [:organization_id], :organizations, name: :fk_spv_organization_id
    end
    alter_table :service_plans do
      add_foreign_key [:service_id], :services, name: :fk_service_plans_service_id
    end
    alter_table :services do
      add_foreign_key [:service_broker_id], :service_brokers, name: :fk_services_service_broker_id
    end
    alter_table :sidecar_process_types do
      add_foreign_key [:sidecar_guid], :sidecars, key: :guid, name: :fk_sidecar_proc_type_sidecar_guid
    end
    alter_table :sidecars do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_sidecar_app_guid
    end
    alter_table :space_annotations do
      add_foreign_key [:resource_guid], :spaces, key: :guid, name: :fk_space_annotations_resource_guid
    end
    alter_table :space_labels do
      add_foreign_key [:resource_guid], :spaces, key: :guid, name: :fk_space_labels_resource_guid
    end
    alter_table :space_quota_definitions do
      add_foreign_key [:organization_id], :organizations, name: :fk_sqd_organization_id
    end
    alter_table :spaces do
      add_foreign_key [:organization_id], :organizations, name: :fk_spaces_organization_id
      add_foreign_key [:space_quota_definition_id], :space_quota_definitions, name: :fk_space_sqd_id
      add_foreign_key [:isolation_segment_guid], :isolation_segments, key: :guid, name: :fk_spaces_isolation_segment_guid
    end
    alter_table :spaces_auditors do
      add_foreign_key [:space_id], :spaces, name: :space_auditors_space_fk
      add_foreign_key [:user_id], :users, name: :space_auditors_user_fk
    end
    alter_table :spaces_developers do
      add_foreign_key [:space_id], :spaces, name: :space_developers_space_fk
      add_foreign_key [:user_id], :users, name: :space_developers_user_fk
    end
    alter_table :spaces_managers do
      add_foreign_key [:space_id], :spaces, name: :space_managers_space_fk
      add_foreign_key [:user_id], :users, name: :space_managers_user_fk
    end
    alter_table :stack_annotations do
      add_foreign_key [:resource_guid], :stacks, key: :guid, name: :fk_stack_annotations_resource_guid
    end
    alter_table :stack_labels do
      add_foreign_key [:resource_guid], :stacks, key: :guid, name: :fk_stack_labels_resource_guid
    end
    alter_table :staging_security_groups_spaces do
      add_foreign_key [:staging_security_group_id], :security_groups, name: :fk_staging_security_group_id
      add_foreign_key [:staging_space_id], :spaces, name: :fk_staging_space_id
    end
    alter_table :task_annotations do
      add_foreign_key [:resource_guid], :tasks, key: :guid, name: :fk_task_annotations_resource_guid
    end
    alter_table :task_labels do
      add_foreign_key [:resource_guid], :tasks, key: :guid, name: :fk_task_labels_resource_guid
    end
    alter_table :tasks do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_tasks_app_guid
    end
    alter_table :users do
      add_foreign_key [:default_space_id], :spaces, name: :fk_users_default_space_id
    end
  end
end
EOF
