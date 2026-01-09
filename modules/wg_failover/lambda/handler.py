import os
import boto3

ec2 = boto3.client("ec2")

EIP_ALLOCATION_ID = os.environ["EIP_ALLOCATION_ID"]
ROUTE_TABLE_ID    = os.environ["ROUTE_TABLE_ID"]
DEST_CIDR         = os.environ["DEST_CIDR"]
STANDBY_ENI_ID    = os.environ["STANDBY_ENI_ID"]

def handler(event, context):
    # 1) EIP -> Standby ENI
    ec2.associate_address(
        AllocationId=EIP_ALLOCATION_ID,
        NetworkInterfaceId=STANDBY_ENI_ID,
        AllowReassociation=True
    )

    # 2) RouteTable route -> Standby ENI
    ec2.replace_route(
        RouteTableId=ROUTE_TABLE_ID,
        DestinationCidrBlock=DEST_CIDR,
        NetworkInterfaceId=STANDBY_ENI_ID
    )

    return {
        "status": "ok",
        "eip_allocation_id": EIP_ALLOCATION_ID,
        "route_table_id": ROUTE_TABLE_ID,
        "dest_cidr": DEST_CIDR,
        "standby_eni_id": STANDBY_ENI_ID
    }