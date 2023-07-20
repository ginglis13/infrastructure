import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as custom_resources from 'aws-cdk-lib/custom-resources';
import * as AWS from 'aws-sdk';
import { Construct } from 'constructs';
  
  export class ECREnhancedScanningEnabler extends cdk.Stack {
    constructor(scope: Construct, id: string, props ? : cdk.StackProps) {
      super(scope, id, props);
  
      const onCreateParam: AWS.ECR.PutRegistryScanningConfigurationRequest = {
        scanType: 'ENHANCED',
        rules: [{
          repositoryFilters: [{
            filter: '*',
            filterType: 'WILDCARD',
          }, ],
          scanFrequency: 'CONTINUOUS_SCAN',
        }]
      };
      const onDeleteParam: AWS.ECR.PutRegistryScanningConfigurationRequest = {
        scanType: 'BASIC',
        rules: [{
          repositoryFilters: [{
            filter: '*',
            filterType: 'WILDCARD',
          }, ],
          scanFrequency: 'SCAN_ON_PUSH',
        }]
      };
  
      const enabler = new custom_resources.AwsCustomResource(this, 'EnhancedScanningEnabler', {
        policy: custom_resources.AwsCustomResourcePolicy.fromSdkCalls({
          resources: custom_resources.AwsCustomResourcePolicy.ANY_RESOURCE,
        }),
        onCreate: {
          service: 'ECR',
          physicalResourceId: custom_resources.PhysicalResourceId.of('id'),
          action: 'putRegistryScanningConfiguration',
          parameters: onCreateParam,
        },
        onDelete: {
          service: 'ECR',
          action: 'putRegistryScanningConfiguration',
          parameters: onDeleteParam,
        },
      })
  
      enabler.grantPrincipal.addToPrincipalPolicy(new iam.PolicyStatement({
        actions: ['inspector2:ListAccountPermissions', 'inspector2:Enable'],
        resources: [
          cdk.Stack.of(this).formatArn({
            service: 'inspector2',
            resource: '/accountpermissions',
            arnFormat: cdk.ArnFormat.SLASH_RESOURCE_NAME,
            resourceName: 'list',
          }),
          cdk.Stack.of(this).formatArn({
            service: 'inspector2',
            resource: '/enable',
            arnFormat: cdk.ArnFormat.SLASH_RESOURCE_NAME,
            resourceName: 'enable',
          }),
        ],
      }));
    }
  }