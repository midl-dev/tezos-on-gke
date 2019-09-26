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
            delegators[delegator].append("### Payout to address %s:" % delegator)
            delegators[delegator].append("")
            delegators[delegator].append("|Cycle|Balance|Estimated rewards|Final rewards|Payout operation|")
            delegators[delegator].append("|-----|-------|-----------------|-------------|----------------|")
        delegator_val=cycle_val["delegators"][delegator]
        delegators[delegator].append("|%s|%s|%s|%s|%s|" % (cycle,delegator_val["balance"],
            delegator_val["estimatedRewards"],
            delegator_val["finalRewards"] if "finalRewards" in delegator_val else "",
            delegator_val["payoutOperationHash"][0:7] if "payoutOperationHash" in delegator_val else "" ))

for delegator, delegator_val in delegators.items():
    print("\n".join(delegator_val), file=open("%s/%s.md" % ( save_path, delegator), "a"))
