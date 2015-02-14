#!/bin/bash

# With this script you could create an sns topic and an sqs queue.
# Topic will have SendMessage access to queue and queue will be subscribed on topic.
# An iam user also will be created and has access to both of them.
# As input you should give a file with 4 elements per row
# A sample row is following:
# sns_topic_name sqs_queue_name iam_user_name iam_policy_name
# sns_topic_name: name for the sns topic
# sqs_queue_name: name for sqs queue
# iam_user_name: name for iam user
# iam_policy_name: name for iam policy
# In order to save the output save it to a file while you will execute it
# ./aws_sns_sqs_sqs_iam file_for_input > aws_sns_sqs_sqs_iam.log


set -o pipefail
file_with_details=$1

# Read each line of the given file

while IFS=' ' read -r sns_topic_name sqs_queue_name iam_user_name iam_policy_name

do
    #more details for policy name
    iam_policy_name=iam_policy_name-$(date +%Y%m%d-%H%M%S)
    iam_policy_filename=iam_policy.json

    # Create SNS topic
    sns_topic_arn=$(aws sns create-topic --name $sns_topic_name --output text)

    # Create SQS queue
    sqs_queue_url=$(aws sqs create-queue --queue-name $sqs_queue_name --output text)
    # Get sqs arn
    sqs_queue_arn=$(aws sqs get-queue-attributes --queue-url $sqs_queue_url --attribute-names QueueArn --output text| awk {'print $2'})
    # Create a subscription to the sqs queue from the created sns topic
    sns_subscription_arn=$(aws sns subscribe --topic-arn $sns_topic_arn --protocol sqs --notification-endpoint $sqs_queue_arn | awk {'print $2'} )

    # Create a random number for sqs policy Sid
    random_number=$RANDOM$RANDOM

    # Create a string for Policy attribute value with an anothodox way. I thinnk there is a better way
    str_for_sqs_policy=$(echo '{"Policy": "{\"Version\":\"2008-10-17\",\"Id\":\"$sqs_queue_arn/SQSDefaultPolicy\",\"Statement\":[{\"Sid\":\"Sid$random_number\",\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"*\"},\"Action\":\"SQS:SendMessage\",\"Resource\":\"$sqs_queue_arn\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"$sns_topic_arn\"}}}]}"}')

    # Change variables with their values due to single quotes issue
    str_for_sqs_policy_specific=$(echo $str_for_sqs_policy | sed -e "s/\$sqs_queue_arn/$sqs_queue_arn/g" -e "s/\$sns_topic_arn/$sns_topic_arn/g" -e "s/\$random_number/$random_number/g")

    # Print single quotes in policy string
    sqs_sns_attr_policy_final=$(echo "'$str_for_sqs_policy_specific'")

    # Insert in a variable aws cli command for attributes configuration
    aws_command_sqs_attr=$(echo "aws sqs set-queue-attributes --queue-url $sqs_queue_url --attribute ")

    # Create command and join Policy attribute in order to give SendMessage access to the created sqs queue the created sns topic
    sns_sqs_access=$(echo $aws_command_sqs_attr$sqs_sns_attr_policy_final)
    # Exexute the command
    eval "$sns_sqs_access"

    # Create iam user for sns and sqs
    iam_user_arn=$(aws iam create-user --user-name $iam_user_name --output text | awk '{print $2}')

    # Create iam user access key
    iam_user_credentials=$(aws iam create-access-key --user-name $iam_user_name --output text | awk '{print $4,$2}')
    iam_user_access_id=$(echo $iam_user_credentials | cut -d' ' -f2)
    iam_user_access_key=$(echo $iam_user_credentials | cut -d' ' -f1)
    
    # Log in file some procedure details
    echo ---------------------------------------------------------------------------
    echo ---------------------------------------------------------------------------
    echo ---------------------------------------------------------------------------
    echo IAM user "$iam_user_name" created with
    echo with SECRET_ACCESS_key: $iam_user_access_key
    echo and ACCESS_id: $iam_user_access_id
    echo Relevant SQS queue arn: $sqs_queue_arn
    echo Relevant SNS topic arn: $sns_topic_arn
    echo ---------------------------------------------------------------------------
    echo ---------------------------------------------------------------------------
    echo ---------------------------------------------------------------------------

    # Create iam user policy
    #TODO: add source IP and the needed access
    random_number_2=$RANDOM$RANDOM
    random_number_3=$RANDOM$RANDOM
    echo "{
      \"Statement\": [
        {
          \"Sid\": \"Stmt$random_number_2\",
          \"Action\": [
            \"sns:Publish\"
          ],
          \"Effect\": \"Allow\",
          \"Resource\": \"$sns_topic_arn\"
        },
        {
          \"Sid\": \"Stmt$random_number_3\",
          \"Action\": [
            \"sqs:DeleteMessage\",
            \"sqs:ReceiveMessage\"
          ],
          \"Effect\": \"Allow\",
          \"Resource\": \"$sqs_queue_arn\"
        }
      ]
    }" > $iam_policy_filename

    #Attach iam user needed policies
    aws iam put-user-policy --user-name $iam_user_name --policy-name $iam_policy_name --policy-document file://$iam_policy_filename

    # Delete policy file
    rm $iam_policy_filename

done < $file_with_details

