# aatonnomicc node manager

Welcome to ANM this is a bit experimenatl so feed back is welcome 

this script will control the ammount of nodes running on a system running ubuntu saving time trying to guess how manay nodes to start.

the script will be installed by selecting start nodes option

![image](https://github.com/user-attachments/assets/6d7da7d0-750e-46a8-aef7-8bc0d2bfcd08)


this will install the anms.sh script in /usr/bin and set the script to run on a 1 min cron schedule
on first starting nodes it will ask for

1. Discord username
2. Logging
3. Port range default is set at 55 which means first node will start on port 55001 and iterate up from there.
4. NodeCap this is so people from home can set a hard limit of nodes so as to not overload there routers.


default load levels are set to low which will set that no new nodes can be added over load average Number of cpu's * 1.5 and will stop nodes at Number of cpu's * 2.5.
once the script has started one node the main script can be run again and a custome load level set.

![image](https://github.com/user-attachments/assets/886df594-3916-4ad9-917b-369e0ce682c2)

since the load levels go by cpu count an example for a 4 cpu system would look like this

1. Low        Bellow 6 Start new nodes  Over 10 Stop nodes
2. Medium     Bellow 8 Start new nodes  Over 12 Stop nodes
3. High       Bellow 10 Start new nodes Over 14 Stop nodes
4. Extream    Bellow 12 Start new nodes Over 16 Stop nodes

anm can stop one node every time it runs but can only start depending on a start interval of 3 minutes. also if a node is stoped for 5 hours it will delete the node.

once running there is a config folder located at /var/safenode-manager/config

![image](https://github.com/user-attachments/assets/f1203a76-24d9-4633-b045-8a88ae73eb99)

edit any of these settings manualy to control anm if you wish settings diferent from the default values.
if you wish fully automatic upgrades of nodes set 
```NodeVersion="--version 0.110.0"```
to
```NodeVersion=""``` and the upgrade will start at the upgrade hour and minnute.

# In Action

![image](https://github.com/user-attachments/assets/eac0ccd0-a706-4b8c-8a09-7c036518766d)

can be seen here that system load started increasing at 07:00 for all machines runing anm.

![image](https://github.com/user-attachments/assets/3c50bcb5-af23-41e6-9ca6-e119dd9967e6)

and here is total node count showing the number of running nodes decreasing to keep the load in the defined range.
