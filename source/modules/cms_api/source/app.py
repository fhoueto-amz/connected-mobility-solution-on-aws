#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Standard Library
import os
from os.path import dirname, realpath

# AWS Libraries
from aws_cdk import App, Aspects, DefaultStackSynthesizer
from cdk_nag import AwsSolutionsChecks

# CMS Common Library
from cms_common.aspects.nag_suppression import NagSuppression, NagType
from cms_common.aspects.vpc_aspect import ApplyVpcOnCustomResource
from cms_common.config.stack_inputs import (
    S3AssetConfigInputs,
    SolutionConfigInputs,
    create_solution_tags_for_stack,
    create_stack_description,
)

# Connected Mobility Solution on AWS
from .infrastructure.cms_api_stack import CmsAPIStack

solution_config_inputs = SolutionConfigInputs(
    solution_id=os.environ["SOLUTION_ID"],
    solution_name=os.environ["SOLUTION_NAME"],
    solution_version=os.environ["SOLUTION_VERSION"],
    application_type=os.environ["APPLICATION_TYPE"],
    module_name=os.environ["MODULE_NAME"],
    module_short_name=os.environ["MODULE_SHORT_NAME"],
    capability_id=os.environ["CAPABILITY_ID"],
)

s3_asset_config_inputs = S3AssetConfigInputs(
    bucket_base_name=os.environ["S3_ASSET_BUCKET_BASE_NAME"],
    object_key_prefix=os.environ["S3_ASSET_KEY_PREFIX"],
)

app = App()
stack = CmsAPIStack(
    app,
    solution_config_inputs.module_name,
    stack_name=solution_config_inputs.module_name,
    description=create_stack_description(solution_config=solution_config_inputs),
    synthesizer=DefaultStackSynthesizer(generate_bootstrap_version_rule=False),
    solution_config_inputs=solution_config_inputs,
    s3_asset_config_inputs=s3_asset_config_inputs,
)

# Tags
create_solution_tags_for_stack(app=app, solution_config=solution_config_inputs)

# Aspects
Aspects.of(app).add(
    ApplyVpcOnCustomResource(
        module_name=solution_config_inputs.module_name,
        security_group_logical_ids=stack.api_construct.cdk_lambdas_vpc_construct.security_groups,
        subnet_names=stack.api_construct.cdk_lambdas_vpc_construct.subnets,
    )
)

Aspects.of(app).add(
    NagSuppression(
        f"{dirname(realpath(__file__))}/.cdk-nag-suppression-list.json", NagType.CDK_NAG
    )
)
Aspects.of(app).add(
    NagSuppression(
        f"{dirname(realpath(__file__))}/.cfn-nag-suppression-list.json", NagType.CFN_NAG
    )
)
if os.environ.get("CDK_NAG_ENFORCE") == "true":
    Aspects.of(app).add(AwsSolutionsChecks())

app.synth()
