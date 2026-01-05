import json
import boto3

s3 = boto3.client("s3")

PROCESSED_BUCKET = "event-processed-data-bucket-123"
REPORT_BUCKET = "event-daily-reports-bucket-123"

def lambda_handler(event, context):
    response = s3.list_objects_v2(Bucket=PROCESSED_BUCKET)

    count = 0
    if "Contents" in response:
        count = len(response["Contents"])

    report = {
        "total_events_processed": count
    }

    s3.put_object(
        Bucket=REPORT_BUCKET,
        Key="daily_report.json",
        Body=json.dumps(report)
    )

    return {
        "statusCode": 200,
        "body": "Daily report generated"
    }
