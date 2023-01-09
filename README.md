You will need to set the following environment variables:
```text
export apiname=
export JFROG_CLI_LOG_LEVEL=DEBUG
export SERVER_ID=
export SERVER_URL=
export MYTOKEN=

export mulesoft_organization_url=
export mulesoft_organization_user=
export mulesoft_organization_password=

export mulesoft_nexus_ee_url=
export mulesoft_nexus_ee_user=
export mulesoft_nexus_ee_password=

export mulesoft_public_url=
```

**Use-case:**

How to create local , remote repos and wrap it with a virtual repo using Jfrog CLI templates ?
Then create a group that has write/deploy permissions to the local repos and cache permissions to the remote repos.
Use permission tempolates and create it using jfrog cli.

Create an Access token that has the group scope  and non-expirable ( using the new Jfrog Access API and not the old 
security API) .

Also what does refreshable access token mean and how to refresh it when it expires. 
Verify that this token can upload artifacts to local and virtual repo and download artifacts from the remote repo 
before using this token in the Github actions workflow.

FYI the json  as documented in  [application/vnd.org.jfrog.artifactory.security.PermissionTargetV2+json](https://www.jfrog.com/confluence/display/JFROG/Security+Configuration+JSON#SecurityConfigurationJSON-application/vnd.org.jfrog.artifactory.security.PermissionTargetV2+json) is incorrect.
It should be be "actions_users"  instead of "actions.users"  and  "actions_groups"  instead of "actions.groups". Will log Doc JIRA later.

References:
https://www.jfrog.com/confluence/display/JFROG/Repository+Configuration+JSON

https://github.com/sureshvenkatesan/swampup2021-1/blob/su115-functional-test-gradle7/solution.sh

1. Create a local maven repository

https://github.com/jfrog/SwampUp2022/blob/main/SUP016-Automate_everything_with_the_JFrog_CLI/lab-1/template-local-rescue.json
```text
jf rt rc local_repo_template.json --vars "repo-name=${apiname}-sapi-mvn-dev-local;package-type=maven" --server-id ${SERVER_ID}

```

2. Create remote repositories:

https://github.com/jfrog/SwampUp2022/blob/main/SUP016-Automate_everything_with_the_JFrog_CLI/lab-1/template-remote-rescue.json
```text
jf rt rc remote_repo_template.json --vars "repo-name=${apiname}-sapi-werner-mulesoft-dev-remote;package-type=maven;url=${mulesoft_organization_url};username=${mulesoft_organization_user};password=${mulesoft_organization_password}" --server-id ${SERVER_ID}

jf rt rc remote_repo_template.json --vars "repo-name=${apiname}-sapi-mulesoft-nexus-dev-remote;package-type=maven;url=${mulesoft_nexus_ee_url};username=${mulesoft_nexus_ee_user};password=${mulesoft_nexus_ee_password}" --server-id ${SERVER_ID}

jf rt rc remote_repo_template.json --vars "repo-name=${apiname}-sapi-mulesoft-public-dev-remote;package-type=maven;url=${mulesoft_public_url};username=;password=" --server-id ${SERVER_ID}
```


3. Create virtual repository

https://github.com/jfrog/SwampUp2022/blob/main/SUP016-Automate_everything_with_the_JFrog_CLI/lab-1/template-virtual-rescue.json
```text
jf rt rc virtual_repo_template.json --vars "repo-name=${apiname}-sapi-mvn-dev;package-type=maven;repos=${apiname}-sapi-mvn-dev-local,${apiname}-sapi-werner-mulesoft-dev-remote,${apiname}-sapi-mulesoft-nexus-dev-remote,${apiname}-sapi-mulesoft-public-dev-remote;deploy-repo-name=${apiname}-sapi-mvn-dev-local" --server-id ${SERVER_ID}
```


4. Create a group GitHub_Action_Group:

https://www.jfrog.com/confluence/display/CLI/CLI+for+JFrog+Artifactory#CLIforJFrogArtifactory-CreatingGroups
```text
jf rt group-create GitHub_Action_Group --server-id ${SERVER_ID}
```

5. Create permission target for this group:

https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API+V2

https://www.jfrog.com/confluence/display/JFROG/Security+Configuration+JSON 
```text
jf rt permission-target-create pt-template-for-group.json --vars "pt-name=GitHub_Group_Permission;repos=ANY LOCAL,ANY REMOTE;group=GitHub_Action_Group" --server-id ${SERVER_ID}
```

6. Create a access token for a transient user githubuser who has the group scoped permissions and no expiry.
This will be used as the ${GITHUB_SCOPED_ACCESS_TOKEN} in next step.
```text
curl  -H "Authorization: Bearer ${MYTOKEN}" -XPOST ${SERVER_URL}/access/api/v1/tokens -d "username=githubuser" -d "scope=applied-permissions/groups:GitHub_Action_Group" -d "expires_in=0"
```

7. Build and deploy
Configure your Github actions to connect the jf cli to Artifactory using the steps in https://github.com/marketplace/actions/setup-jfrog-cli

https://github.com/jfrog/SwampUp2022/tree/main/SUP016-Automate_everything_with_the_JFrog_CLI/lab-3

Run jf mvnc as mentioned in https://github.com/shivaraman83/spring-boot-maven-example-helloworld/blob/master/.github/workflows/maven-publish.yml
```text
export REPO_NAME=${apiname}-sapi-mvn-dev
jf mvnc --repo-resolve-releases $REPO_NAME --repo-resolve-snapshots $REPO_NAME --repo-deploy-releases $REPO_NAME --repo-deploy-snapshots $REPO_NAME
jf mvn clean install -f ./pom.xml --build-name sup016-maven --build-number 1.0.0

Or
Just try a simple upload and download:
tar -czvf froggy.tgz pt-template.json
jf rt u froggy.tgz ${apiname}-sapi-mvn-dev --server-id ${SERVER_ID}
jf rt dl ${apiname}-sapi-mvn-dev/froggy.tgz /tmp/ --server-id ${SERVER_ID}

or as the transient githubuser access token:
Test upload to virtual repo:
jf rt u froggy.tgz ${apiname}-sapi-mvn-dev --url ${SERVER_URL}/artifactory --access-token ${GITHUB_SCOPED_ACCESS_TOKEN}

Test download from local repo:
jf rt dl ${apiname}-sapi-mvn-dev-local/froggy.tgz /tmp/ --url ${SERVER_URL}/artifactory --access-token "${GITHUB_SCOPED_ACCESS_TOKEN}"


Test dowload from remote repo as well:
jf rt dl anypoint-sapi-werner-mulesoft-dev-remote/froggy.tgz /tmp/ --url ${SERVER_URL}/artifactory --access-token "${GITHUB_SCOPED_ACCESS_TOKEN}"

Test download from virtual repo:
jf rt dl ${apiname}-sapi-mvn-dev/froggy.tgz /tmp/ --url ${SERVER_URL}/artifactory --access-token "${GITHUB_SCOPED_ACCESS_TOKEN}"

```

===========================================================================

Customer decided to use transient githubuser from access token ( thta has group scpoped permissions) instead of explicitly creating the githubuser .
So we did not do the following:

8.Create an artifactory user for github

https://www.jfrog.com/confluence/display/CLI/CLI+for+JFrog+Artifactory#CLIforJFrogArtifactory-CreatingUsers

```text
jf rt user-create  githubuser1 ${githubuser_password} githubuser@jfrog.com --server-id ${SERVER_ID}
```


Note: This user is automatically assigned to group 'readers'.

9. Set permissions for the user on the local and remote repos.

https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API+V2

https://www.jfrog.com/confluence/display/JFROG/Security+Configuration+JSON 

https://github.com/jfrog/SwampUp2022/tree/main/SUP016-Automate_everything_with_the_JFrog_CLI/lab-2
```text
jf rt permission-target-create pt-template.json --vars "pt-name=github-pt;repos=${apiname}-sapi-mvn-dev-local,${apiname}-sapi-werner-mulesoft-dev-remote,${apiname}-sapi-mulesoft-nexus-dev-remote,${apiname}-sapi-mulesoft-public-dev-remote;user=githubuser" --server-id ${SERVER_ID}
```




10. Create access token for this user (access-token-create) .
Note: the atc comamnd uses the old /api/security/token API and these "token_id" are not visible in  the UI.
```text
jf rt atc  githubuser --server-id ${SERVER_ID}

jf rt atc githubuser --groups *  --server-id ${SERVER_ID} -> not working

jf rt atc githubuser  --refreshable --server-id ${SERVER_ID}
```


Instead create the access token using new Access API ( cannot be invoked from jf , so use curl) which acn be refreshed.

Note: You will get an "access_token" and corresponding "refresh_token"
```text
curl  -H "Authorization: Bearer ${MYTOKEN}" -XPOST ${SERVER_URL}/access/api/v1/tokens -d "username=githubuser" -d "scope=applied-permissions/user" -d "refreshable=true" 
```

Output:
```text
{
  "token_id" : "fb95ad88-4f1c-46e4-9294-2f9592f393c4",
  "access_token" : "eyJ2ZXIiOiIyIiwidHlwIjoiSldUIiwiYWxnIjoiUlMyNTYiLCJraWQiOiJMZXplVmwyTEhfNjNjenVxSjdXaEZvZTgtT2xWaVZoSTB3MG45NlpoOFJNIn0.eyJleHQiOiJ7XCJyZXZvY2FibGVcIjpcInRydWVcIn0iLCJzdWIiOiJqZmFjQDAxZmd5MzBtYnJ2Z2J3MTBhM2VudmowNXEwXC91c2Vyc1wvZ2l0aHVidXNlciIsInNjcCI6ImFwcGxpZWQtcGVybWlzc2lvbnNcL3VzZXIiLCJhdWQiOiIqQCoiLCJpc3MiOiJqZmFjQDAxZmd5MzBtYnJ2Z2J3MTBhM2VudmowNXEwIiwiZXhwIjoxNzAzMTQ0ODQ0LCJpYXQiOjE2NzE2MDg4NDQsImp0aSI6ImZiOTVhZDg4LTRmMWMtNDZlNC05Mjk0LTJmOTU5MmYzOTNjNCJ9.nOboCI7vpKZ1rzwQQSyAX6js0_Z0PP9yr5o89jEUs5rwN6YZhNBJDGPqmEOaxtKtqfnhNfdVjr1xSQtc1Qkk8Q0nQSm-82ZfrUxriFyYyUZgJkjOIcRIrE16SRusWKOxr1VUOVGRCp-x7DPLm4Et06_OLI-xtTk1lVmR0H0g_cQdZyBcUBbh2HlWd-WwC_KpCclOzcx6HW92A17lzjaDKLSVbIQV2H1aCgFjyNcTHpGUNSYhQy772gqk-rYUAWtG0ZrW6SAqQyl-ONHM9mU7JGr9XwK50dpv0p7myo5Kj4nkuHANrdso22OKaB7JbqDWtkPVWf9KJlyHvJapYfFcsA",
  "refresh_token" : "4d7ebe87-47bd-4642-9ccc-1bb7f9be8d29",
  "expires_in" : 31536000,
  "scope" : "applied-permissions/user",
  "token_type" : "Bearer"
}
```

Refresh this access token ( i.e "token_id" : "fb95ad88-4f1c-46e4-9294-2f9592f393c4") using the "refresh_token" : "4d7ebe87-47bd-4642-9ccc-1bb7f9be8d29":
```text
curl  -H "Authorization: Bearer ${MYTOKEN}" -XPOST ${SERVER_URL}/access/api/v1/tokens -d "grant_type=refresh_token" -d "refresh_token=4d7ebe87-47bd-4642-9ccc-1bb7f9be8d29"
```


That token will be revoked and will be refreshed  and you will get a new "token_id" and "refresh_token" for the same "expires_in" period i.e the expiration  

Here is the output:
```text
{
"token_id" : "fa21f6a4-f527-4b2c-a661-333a46003920",
"access_token" : "eyJ2ZXIiOiIyIiwidHlwIjoiSldUIiwiYWxnIjoiUlMyNTYiLCJraWQiOiJMZXplVmwyTEhfNjNjenVxSjdXaEZvZTgtT2xWaVZoSTB3MG45NlpoOFJNIn0.eyJleHQiOiJ7XCJyZXZvY2FibGVcIjpcInRydWVcIn0iLCJzdWIiOiJqZmFjQDAxZmd5MzBtYnJ2Z2J3MTBhM2VudmowNXEwXC91c2Vyc1wvZ2l0aHVidXNlciIsInNjcCI6ImFwcGxpZWQtcGVybWlzc2lvbnNcL3VzZXIiLCJhdWQiOiIqQCoiLCJpc3MiOiJqZmFjQDAxZmd5MzBtYnJ2Z2J3MTBhM2VudmowNXEwIiwiZXhwIjoxNzAzMTQ0ODk5LCJpYXQiOjE2NzE2MDg4OTksImp0aSI6ImZhMjFmNmE0LWY1MjctNGIyYy1hNjYxLTMzM2E0NjAwMzkyMCJ9.VV7H8vGg403u2gWf3oHO_Uc2rPZaaX1mzrCTNE9fuqGd9o0PflSuG2c2abRtJm1Si9kNqlLmKcPeBu5B2lgwm6FNWnQf6FIbOkkSoP-2KnRhmVJGCCewOWVhw1HMnQH8fG59pCFnEeXCtZ-Bmi1c86wTgOv5duKgHTcg6CfB1h6u24-E-gFmJoWrVLvw1RfG-w74qHwmas-0-6MCUUzwrwVEL3Kis9KoH3nPOwC5U-j2lytR8SQkdhSQmQ3Nq40g5Da6yDuChntweOdmMYzwEs7YplWVkeScE4RPThOC446iF4dBYCYgsac1h5xw_WpD1Hmw",
"refresh_token" : "ce5d0a24-4f2f-404b-95d5-2f58979eb2a0",
"expires_in" : 31536000,
"scope" : "applied-permissions/user",
"token_type" : "Bearer"
}
```


Or
 
If you do not want a refreshable token , you could also extract a non-refreshable token to an env variable as 
mentioned in https://github.com/jfrog/terraform-provider-artifactory/blob/master/scripts/get-access-key.sh
```text
export GITHUB_SCOPED_ACCESS_TOKEN=$(curl  -H "Authorization: Bearer ${MYTOKEN}" -XPOST ${SERVER_URL}/access/api/v1/tokens -d "username=githubuser" -d "scope=applied-permissions/user" -d "description=Created_with_script_for_github" | jq .access_token)
```


Or for group scoped token:
```
export GITHUB_SCOPED_ACCESS_TOKEN=$(curl  -H "Authorization: Bearer ${MYTOKEN}" -XPOST ${SERVER_URL}/access/api/v1/tokens  -d "username=githubuser" -d "scope=applied-permissions/groups:GitHub_Action_Group" -d "expires_in=0" -d "description=Created_with_script_for_github" | jq .access_token)

echo "${GITHUB_SCOPED_ACCESS_TOKEN}"
```
YOu can use this access token to configure the jf cli in  your Github actions pipeline as mentioned in
https://github.com/marketplace/actions/setup-jfrog-cli

===========================================================================
