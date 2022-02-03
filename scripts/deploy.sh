#!/bin/bash
truffle migrate --reset --network $1
echo "please wait...30 sec"
sleep 30

truffle run verify AirdropStaking --network $1

echo "done"