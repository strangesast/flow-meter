import boto3
from datetime import datetime, timedelta
import calendar
import sys


def get_first_day_of_current_month():
    today = datetime.today()
    return today.replace(day=1).strftime("%Y-%m-%d")


def get_today():
    return datetime.today().strftime("%Y-%m-%d")


def get_cost_and_usage(client, service, start_date, end_date):
    try:
        response = client.get_cost_and_usage(
            TimePeriod={"Start": start_date, "End": end_date},
            Granularity="MONTHLY",
            Metrics=["UnblendedCost", "UsageQuantity"],
            Filter={"Dimensions": {"Key": "SERVICE", "Values": [service]}},
        )
        results = response.get("ResultsByTime", [])
        if not results:
            return {"Cost": "0.00", "Usage": "0"}

        total_cost = 0.0
        total_usage = 0.0
        for result in results:
            for group in result.get("Groups", []):
                cost = float(group["Metrics"]["UnblendedCost"]["Amount"])
                usage = float(group["Metrics"]["UsageQuantity"]["Amount"])
                total_cost += cost
                total_usage += usage

        # If 'Groups' is empty, get from 'Total'
        if not results[0].get("Groups", []):
            cost = float(results[0]["Total"]["UnblendedCost"]["Amount"])
            usage = float(results[0]["Total"]["UsageQuantity"]["Amount"])
            total_cost += cost
            total_usage += usage

        return {"Cost": f"${total_cost:.2f}", "Usage": f"{total_usage:.2f}"}
    except Exception as e:
        print(f"Error fetching data for {service}: {e}", file=sys.stderr)
        return {"Cost": "Error", "Usage": "Error"}


def main():
    # Initialize boto3 client for Cost Explorer
    client = boto3.client(
        "ce", region_name="us-east-1"
    )  # Cost Explorer is a global service

    # List of AWS services used in the Terraform project
    services = [
        "AWS IoT Core",
        "Amazon DynamoDB",
        "AWS Identity and Access Management",
        "AWS Lambda",
        "Amazon API Gateway",
        "Amazon CloudWatch",
        "Amazon Simple Storage Service (S3)",
        "Amazon CloudFront",
        "Amazon Route 53",
        "AWS Certificate Manager",
    ]

    # Define the date range for the current billing cycle
    start_date = get_first_day_of_current_month()
    end_date = get_today()

    print(f"Fetching cost and usage from {start_date} to {end_date}...\n")

    # Header
    print(f"{'Service':40} {'Cost (USD)':15} {'Usage':15}")
    print("-" * 70)

    total_cost = 0.0
    total_usage = 0.0

    for service in services:
        data = get_cost_and_usage(client, service, start_date, end_date)
        cost = data["Cost"]
        usage = data["Usage"]

        # Accumulate total cost and usage
        try:
            total_cost += float(cost.replace("$", ""))
            total_usage += float(usage)
        except:
            pass  # In case of 'Error', skip accumulation

        print(f"{service:40} {cost:15} {usage:15}")

    print("-" * 70)
    print(f"{'Total':40} ${total_cost:.2f}       {total_usage:.2f}")


if __name__ == "__main__":
    main()
