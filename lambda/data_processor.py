import json
import boto3

s3 = boto3.client("s3")

PROCESSED_BUCKET = "event-processed-data-bucket-123"

def lambda_handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        obj = s3.get_object(Bucket=bucket, Key=key)
        data = json.loads(obj["Body"].read())

        processed = {
            "event_type": data.get("event_type"),
            "value": data.get("value")
        }

        s3.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=key,
            Body=json.dumps(processed)
        )

    return {
        "statusCode": 200,
        "body": "Data processed successfully"
    }
