'''
lambda function to read ECR Image Inpsection events from Amazon EventBridge 
and send notifications to Finch team regarding security notifications.
'''
import os
import boto3
import json

def build_message(event):
    '''build_message reads an {event} from Inspector image scanning and builds 
    the body of reporting email with vulnerability findings.

    :param events.EventBridgeEvent event: The EventBridgeEvent containing an Inspector scan finding.
    Schema: https://docs.aws.amazon.com/inspector/latest/user/eventbridge-integration.html#event-finding
    '''
    detail = event['detail']
    title = detail['title']
    description = detail['description']
    severity = detail['severity']
    source_url = detail['sourceUrl']
    status = detail['status']
    type = detail['type']
    finding_arn = detail['findingArn']
    first_observed_at = detail['firstObservedAt']

    message = f'''{title} - Severity {severity}

    Severity: {severity}
    Type: {type}
    Description: {description}
    Source URL: {source_url}

    Status: {status}
    Observed: {first_observed_at}

    For more info, view the finding via ARN in the AWS Console: {finding_arn}
    '''

    return message

def send_sns(subject, message):
    '''send_sns sends an email with subject and body
    
    :param str subject: The subject of the email
    :param str message: The body of the email
    '''
    client = boto3.client("sns")
    topic_arn = os.environ["SNS_ARN"]
    client.publish(TopicArn=topic_arn, Message=message, Subject=subject)

def lambda_handler(event, context):
    detailType= event["detail-type"]
    
    if (detailType == "Inspector2 Finding"):
        message = build_message(event)
    else:
        print("No findings found, skipping sending email")
        return {'statusCode': 200}
    
    subject = "Rootfs Image Security Finding"
    message = build_message(event)
    send_sns(subject, message)

    return {'statusCode': 200}
    