# -*- coding: utf-8 -*-
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Standard Library

# AWS Libraries
from aws_cdk import CustomResource
from constructs import Construct

# Connected Mobility Solution on AWS
from ...handlers.custom_resource.function.lib.custom_resource_type_enum import (
    CustomResourceFunctionType,
)


class DeploymentUUIDConstruct(Construct):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        custom_resource_lambda_function_arn: str,
    ) -> None:
        super().__init__(scope, construct_id)

        deployment_uuid_custom_resource = CustomResource(
            self,
            "deployment-uuid-custom-resource",
            service_token=custom_resource_lambda_function_arn,
            resource_type=f"Custom::{CustomResourceFunctionType.CREATE_DEPLOYMENT_UUID.value}",
            properties={
                "Resource": CustomResourceFunctionType.CREATE_DEPLOYMENT_UUID.value,
            },
        )
        self.uuid = deployment_uuid_custom_resource.get_att_string("SolutionUUID")
