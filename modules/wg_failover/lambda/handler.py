import os
import json
import logging
import boto3
import botocore

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")


def _get_env(name: str) -> str:
    v = os.getenv(name)
    if not v:
        raise ValueError(f"Missing required env var: {name}")
    return v


def handler(event, context):
    """
    Failover Lambda:
      1) Reassociate EIP -> Standby ENI
      2) Replace route (DEST_CIDR) in route table -> Standby ENI
         - If route doesn't exist, create it
    Required env vars:
      - EIP_ALLOCATION_ID
      - ROUTE_TABLE_ID
      - DEST_CIDR
      - STANDBY_ENI_ID
    """

    eip_allocation_id = _get_env("EIP_ALLOCATION_ID")
    route_table_id = _get_env("ROUTE_TABLE_ID")
    dest_cidr = _get_env("DEST_CIDR")
    standby_eni_id = _get_env("STANDBY_ENI_ID")

    logger.info("Event: %s", json.dumps(event, ensure_ascii=False))
    logger.info(
        "Params: EIP_ALLOCATION_ID=%s ROUTE_TABLE_ID=%s DEST_CIDR=%s STANDBY_ENI_ID=%s",
        eip_allocation_id, route_table_id, dest_cidr, standby_eni_id
    )

    # 0) Basic validation (optional but helpful)
    try:
        ec2.describe_network_interfaces(NetworkInterfaceIds=[standby_eni_id])
    except botocore.exceptions.ClientError as e:
        logger.exception("Standby ENI not found or not accessible: %s", standby_eni_id)
        raise

    # 1) Reassociate EIP to standby ENI
    logger.info("Associating EIP to standby ENI...")
    ec2.associate_address(
        AllocationId=eip_allocation_id,
        NetworkInterfaceId=standby_eni_id,
        AllowReassociation=True
    )
    logger.info("EIP association complete.")

    # 2) Update route to on-prem (replace, fallback to create)
    logger.info("Updating route table route...")
    try:
        ec2.replace_route(
            RouteTableId=route_table_id,
            DestinationCidrBlock=dest_cidr,
            NetworkInterfaceId=standby_eni_id
        )
        logger.info("Route replaced successfully.")
    except botocore.exceptions.ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        msg = e.response.get("Error", {}).get("Message", "")

        logger.warning("replace_route failed: %s - %s", code, msg)

        # If route doesn't exist, create it
        if code in ("InvalidRoute.NotFound", "InvalidParameterValue"):
            logger.info("Attempting create_route fallback...")
            ec2.create_route(
                RouteTableId=route_table_id,
                DestinationCidrBlock=dest_cidr,
                NetworkInterfaceId=standby_eni_id
            )
            logger.info("Route created successfully.")
        else:
            logger.exception("Unhandled error on replace_route.")
            raise

    # 3) Post-check (best effort)
    try:
        rt = ec2.describe_route_tables(RouteTableIds=[route_table_id])["RouteTables"][0]
        matched = None
        for r in rt.get("Routes", []):
            if r.get("DestinationCidrBlock") == dest_cidr:
                matched = r
                break

        logger.info("Post-check route entry: %s", json.dumps(matched, default=str))
    except Exception:
        logger.warning("Post-check skipped (non-fatal).", exc_info=True)

    return {
        "status": "ok",
        "message": "Failover completed (EIP reassociated + route updated)",
        "eip_allocation_id": eip_allocation_id,
        "route_table_id": route_table_id,
        "dest_cidr": dest_cidr,
        "standby_eni_id": standby_eni_id
    }
