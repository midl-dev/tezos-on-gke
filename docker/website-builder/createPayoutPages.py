# coding=utf-8

import json 
import sys

save_path = sys.argv[1]

with open('payouts.json') as json_file:
    raw_payouts = json.load(json_file)
delegators = {}
for cycle,cycle_val in raw_payouts["payoutsByCycle"].items():
    for delegator in cycle_val["delegators"]:
        if not delegator in delegators:
            delegators[delegator] = ["---"]
            delegators[delegator].append("layout: about")
            delegators[delegator].append("---")
            delegators[delegator].append("### Payout to address [%s](https://tezblock.io/account/%s):" % (delegator, delegator))
            delegators[delegator].append("")
            delegators[delegator].append("|Cycle|Balance|Payout|Actual fee|Payout operation|")
            delegators[delegator].append("|-----|-------|------|----------|----------------|")
        delegator_val=cycle_val["delegators"][delegator]
        if "payoutOperationHash" in delegator_val:
            payout_operation = "[%s...](https://tezblock.io/transaction/%s)" % ( delegator_val["payoutOperationHash"][0:7], delegator_val["payoutOperationHash"]) 
        else:
            payout_operation = ""
        if delegator_val["estimatedRewards"] != "0":
            delegators[delegator].append("|%s|%sꜩ|%sꜩ|%s|%s|" % (cycle, int(delegator_val["balance"]) / 1000000,
            int(delegator_val["estimatedRewards"]) / 1000000,
            "%s%%" % round( 1 - ( 0.95 * int(delegator_val["estimatedRewards"]) / int(delegator_val["finalRewards"]) ) , 3) if "finalRewards" in delegator_val else "Not yet known",
            payout_operation ) )

for delegator, delegator_val in delegators.items():
    delegator_val.append("")
    delegator_val.append("[How do payouts work ?](https://hodl.farm/faq.html#how-do-payouts-work-)")
    print("\n".join(delegator_val), file=open("%s/%s.md" % ( save_path, delegator), "a"))

# Explanation of "actual fee"
# How to calculate the actual fee with the estimated rewards and actual rewards:
# An example when the nominal fee is 5%
# Your estimated rewards (that we pay you) is x
# Your share of our idealized earnings is x/(1-fee) i.e x/0.95
# The actual rewards we should have paid you is y
# Your share of actual earnings is y/0.95
# The effective fee is  ( y/0.95 - x ) / ( y/0.95) = 1 - 0.95 ( x / y )
# We can confirm this calculation with the following hypothesis:
# Let's say the network behaved optimally. In that case, y = x
# Then the effective fee is 1 - 0.95 = 0.05, which is correct
