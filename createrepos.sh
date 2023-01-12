#!usr/bin/env bash

### Prereq Make sure you already exported following environment variables
#MULESOFT_NEXUS_EE_USER
#MULESOFT_NEXUS_EE_PASSWORD

### Exit the script on any failures
set -eo pipefail
set -e
set -u


#### Default values
CREATE_POLICY="false"

### Get the arguments
helpFunction()
{
   echo "Make sure you already exported following environment variables: MULESOFT_NEXUS_EE_USER and MULESOFT_NEXUS_EE_PASSWORD"
   echo "Usage: $0 -a apiname -s serverid "
   echo -e "\t-p Mulesoft public url - https://repository.mulesoft.org/nexus/content/repositories/public"
   echo -e "\t-v Maven public remote - https://repo.maven.apache.org/maven2"
   echo -e "\t-n Mulesoft nexus EE url - https://repository.mulesoft.org/nexus-ee/content/repositories/releases-ee/"
   echo -e "\t-r  Mulesoft release url - https://repository.mulesoft.org/releases"
   echo -e "\t-l  Create policy - true/false"
   echo -e "\t-b  Build name - anypoint-sapi-build-release"
   echo "For example:"
   echo "bash createrepos.sh -a anypoint-sapi -s psuseast1 -p https://repository.mulesoft.org/nexus/content/repositories/public -v https://repo.maven.apache.org/maven2 -n https://repository.mulesoft.org/nexus-ee/content/repositories/releases-ee/ -r https://repository.mulesoft.org/releases -l false -b anypoint-sapi-build-release"
   exit 1 # Exit script after printing help
}

while getopts "a:s:p:v:n:r:l:b:" opt
do
   case "$opt" in
      a )
        API_NAME="${OPTARG}" ;;
      s )
      	SERVER_ID="${OPTARG}";;
      p )
        MULESOFT_PUBLIC_URL="${OPTARG}" ;;
      v )
        MVN_PUBLIC_REMOTE_URL="${OPTARG}" ;;
      n )
        MULESOFT_NEXUS_EE_URL="${OPTARG}" ;;
      r )
        MULESOFT_RELEASE_URL="${OPTARG}" ;;
      l )
        CREATE_POLICY="${OPTARG}" ;;
      b )
        BUILD_NAME="${OPTARG}" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print in case parameters are empty
if [ -z "$API_NAME" ] || [ -z "$SERVER_ID" ] || [ -z "$MULESOFT_PUBLIC_URL" ] || [ -z "$MVN_PUBLIC_REMOTE_URL" ] || [
 -z "$MULESOFT_NEXUS_EE_URL" ] || [ -z "$MULESOFT_RELEASE_URL" ] || [ -z "$CREATE_POLICY" ] || [ -z "$BUILD_NAME" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi


#Point the JFrog CLI to the correct Artifactory server
jf config use  ${SERVER_ID}

#create local repo
jf rt rc local_repo_template.json --vars "repo-name=${API_NAME}-mvn-local;package-type=maven" --server-id ${SERVER_ID}

echo -e "Done creating local repo ${API_NAME}-mvn-local"

#create remote repos
jf rt rc remote_repo_template.json --vars "repo-name=${API_NAME}-mulesoft-public-remote;package-type=maven;url=${MULESOFT_PUBLIC_URL};username=;password=" --server-id ${SERVER_ID}

jf rt rc remote_repo_template.json --vars "repo-name=${API_NAME}-maven-public-remote;package-type=maven;url=${MVN_PUBLIC_REMOTE_URL};username=;password=" --server-id ${SERVER_ID}

jf rt rc remote_repo_template.json --vars "repo-name=${API_NAME}-mulesoft-nexus-remote;package-type=maven;url=${MULESOFT_NEXUS_EE_URL};username=${MULESOFT_NEXUS_EE_USER};password=${MULESOFT_NEXUS_EE_PASSWORD}" --server-id ${SERVER_ID}

jf rt rc remote_repo_template.json --vars "repo-name=${API_NAME}-mulesoft-release-remote;package-type=maven;url=${MULESOFT_RELEASE_URL};username=;password=" --server-id ${SERVER_ID}


#create virtual  repos
jf rt rc virtual_repo_template.json --vars "repo-name=${API_NAME}-mvn;package-type=maven;repos=${API_NAME}-mvn-local,${API_NAME}-mulesoft-public-remote,${API_NAME}-maven-public-remote,${API_NAME}-mulesoft-nexus-remote,${API_NAME}-mulesoft-release-remote;deploy-repo-name=${API_NAME}-mvn-local" --server-id ${SERVER_ID}

#create one policy for all repos
if [ "$CREATE_POLICY" == "true" ]
then
    echo "Creating policy"
    jf xr curl -XPOST /api/v2/policies -H "Content-Type: application/json" -d @sec_policy_failbuild.json --server-id ${SERVER_ID}
fi

# index my build
cat add_build_to_index.template |  sed  's/$BUILD-FOR-API/'"$BUILD_NAME"'/' > add_build_to_index.json
jf xr curl -XPOST /api/v1/binMgr/builds -H "Content-Type: application/json" -d @add_build_to_index.json --server-id ${SERVER_ID}

#create a watch for the repos and build  used for this api
cat watch_for_api.template |  sed  's/$APINAME/'"$API_NAME"'/g;s/$BUILD-FOR-API/'"$BUILD_NAME"'/' > watch_for_api.json

echo "Creating watch"
jf xr curl -XPOST /api/v2/watches -H "Content-Type: application/json" -d @watch_for_api.json --server-id ${SERVER_ID}