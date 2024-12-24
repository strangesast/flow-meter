import json
import os
import boto3
from boto3.dynamodb.conditions import Key, Attr
from botocore.exceptions import ClientError
from datetime import datetime, timedelta
from boto3.dynamodb.types import TypeDeserializer


dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME", "IoTData")
table = dynamodb.Table(TABLE_NAME)

deserializer = TypeDeserializer()


def deserialize_item(item):
    """Convert DynamoDB item to a native Python dictionary."""
    return {k: deserializer.deserialize(v) for k, v in item.items()}


def handler(event, context):
    try:
        # Extract query parameters from the event
        query_params = event.get("queryStringParameters") or {}
        device_id = query_params.get("id")
        start_timestamp = query_params.get("start_timestamp")
        end_timestamp = query_params.get("end_timestamp")

        dt = datetime.now() - timedelta(days=1)
        ts = int(dt.timestamp())

        # if not device_id:
        #     return {
        #         "statusCode": 400,
        #         "body": json.dumps({"error": "Missing required query parameter: id"}),
        #     }

        # Build the DynamoDB query key condition
        # key_condition = Key("id").eq(device_id)
        key_condition = Attr("timestamp").gte(ts)

        # If timestamp range is provided, add it to the key condition
        # if start_timestamp and end_timestamp:
        #    key_condition &= Key("timestamp").between(
        #        int(start_timestamp), int(end_timestamp)
        #    )
        # elif start_timestamp:
        #    key_condition &= Key("timestamp").gte(int(start_timestamp))
        # elif end_timestamp:
        #    key_condition &= Key("timestamp").lte(int(end_timestamp))

        response = table.scan(FilterExpression=key_condition, Limit=100)

        # items = [deserialize_item(item) for item in response.get("Items", [])]
        items = response.get("Items", [])

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"data": items}, default=str),
        }

    except ClientError as e:
        # Handle DynamoDB client errors
        return {
            "statusCode": 500,
            "body": json.dumps({"error": e.response["Error"]["Message"]}, default=str),
        }
    except Exception as e:
        # Handle general exceptions
        return {"statusCode": 500, "body": json.dumps({"error": str(e)}, default=str)}
