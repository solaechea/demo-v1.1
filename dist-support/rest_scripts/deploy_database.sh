#!/bin/bash
# USAGE:  ./deploy_database.sh <temp-database-path> <target-database-name-and-path>
# Database will be uploaded to the server at the given path (relative to the data directory).
# EXAMPLE:  ./deploy_database.sh /tmp/upload.nsf test/mydatabase.nsf

set -e

# Parameters
TEMP_PATH=$1
DBNAME=$2
# TODO:  make title a parameter
TITLE=`printf "$DBNAME" | sed 's/\.nsf$//' | sed 's:^.*\/\([^/]*\)$:\1:'`
echo "Uploading database $TEMP_PATH to $DBNAME ($TITLE)"

# add a timestamp to the JSON file to avoid conflicts
TIMESTAMP=`date +%Y%m%d%H%M%S`
JSON_NAME=create_${TIMESTAMP}.json
JSON_TMP=/tmp/${JSON_NAME}
JSON_TRIGGER_DIR=/local/dominodata/JavaAddin/Genesis/json
JSON_TRIGGER_FILE=$JSON_TRIGGER_DIR/$JSON_NAME

# Determine if the database should be overwritten
FULL_TARGET_PATH=/local/dominodata/$DBNAME
REPLACE=false
if [ -e "$FULL_TARGET_PATH" ]; then
    REPLACE=true;
fi

# create the trigger file
# For now, I am giving "-Default-" designer access to that the user be able to deploy agents.
# TODO:  add an entry for the safe ID user(s) instead.
cat > /tmp/$JSON_NAME << EndOfMessage
{
    "title": "Upload Database",
    "versionjson": "1.0.0",

    "steps": [
		{
			"title": "Uploading database",
			"databases": [
				{
					"action": "create",
					"title": "$TITLE",
					"filePath": "$DBNAME",
					"templatePath": "$TEMP_PATH",
					"sign": true,
					"replace": $REPLACE,
					"ACL": {
						"ACLEntries": [
							{
								"name": "-Default-",
								"level": "designer",
								"type": "unspecified",
								"isPublicReader": true,
								"isPublicWriter": true
							},
							{
								"name": "LocalDomainAdmins",
								"level": "manager",
								"type": "personGroup",
								"isPublicReader": true,
								"isPublicWriter": true
							},
							{
								"name": "LocalDomainServers",
								"level": "manager",
								"type": "serverGroup",
								"isPublicReader": true,
								"isPublicWriter": true
							},
							{
								"name": "OtherDomainServers",
								"level": "noAccess",
								"type": "serverGroup",
								"isPublicReader": true,
								"isPublicWriter": true
							}
						]
					}
				}
			]
		}

    ]
}
EndOfMessage

# update the permissions
sudo chown domino.domino "$TEMP_PATH"
sudo chown domino.domino $JSON_TMP

# Make sure the Genesis directory exists
sudo mkdir -p "$JSON_TRIGGER_DIR"
sudo chown -R domino.domino "$JSON_TRIGGER_DIR"

# copy the file to trigger the action
sudo mv $JSON_TMP $JSON_TRIGGER_FILE
echo "Starting import:  $JSON_TRIGGER_FILE"

# wait for the file to be removed
while [ -e $JSON_TRIGGER_FILE ]
do
	sleep 1
done

# TODO:  check response file for error messages
echo "Deployment Successful."
