# -*- coding: utf-8 -*-
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Standard Library
from typing import Any

# AWS Libraries
from aws_cdk import CfnCondition, CfnMapping, Fn, Stack
from constructs import Construct

# CMS Common Library
from cms_common.config.stack_inputs import S3AssetConfigInputs

# Connected Mobility Solution on AWS
from .constructs.cognito import CognitoConstruct
from .constructs.configurations import Configurations
from .constructs.module_integration import ModuleInputsConstruct, ModuleOutputsConstruct


class AuthSetupStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        s3_asset_config_inputs: S3AssetConfigInputs,
        **kwargs: Any
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        CfnMapping(
            self,
            "Solution",
            mapping={
                "AssetsConfig": {
                    "S3AssetBucketBaseName": s3_asset_config_inputs.bucket_base_name,
                    "S3AssetKeyPrefix": s3_asset_config_inputs.object_key_prefix,
                },
            },
        )

        module_inputs_construct = ModuleInputsConstruct(
            self,
            "module-inputs",
        )

        should_create_cognito_resources_condition = CfnCondition(
            self,
            "should-create-cognito-resources-condition",
            expression=Fn.condition_equals(
                module_inputs_construct.stack_config.should_create_cognito_resources,
                "true",
            ),
        )

        cognito_construct = CognitoConstruct(
            self,
            "cognito",
            module_inputs_construct=module_inputs_construct,
            should_create_resources_condition=should_create_cognito_resources_condition,
        )

        configuration_secrets = Configurations(
            self,
            "configuration-secrets",
            cognito_construct=cognito_construct,
            should_populate_secrets_condition=should_create_cognito_resources_condition,
            module_inputs_construct=module_inputs_construct,
        )

        ModuleOutputsConstruct(
            self,
            "module-outputs",
            module_inputs_construct=module_inputs_construct,
            idp_config_secret_arn=configuration_secrets.idp_config_secret.secret_arn,
            service_client_config_secret_arn=configuration_secrets.service_client_config_secret.secret_arn,
            authorization_code_exchange_config_secret_arn=configuration_secrets.authorization_code_exchange_config_secret.secret_arn,
        )
