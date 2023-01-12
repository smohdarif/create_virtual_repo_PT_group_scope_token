You will need to set the following environment variables:
```text

export MULESOFT_NEXUS_EE_USER=
export MULESOFT_NEXUS_EE_PASSWORD=

```

**Use-case:**

1. Create local , remote repos ( with xray indexing enabled) and wrap it with a virtual repo used for the API using 
   Jfrog CLI templates .

Note: You can get the JFrog Cli from https://jfrog.com/getcli/

2. Create the Xray policy , index the build and create the Xray Watch using a template

Make sure you already exported following environment variables: MULESOFT_NEXUS_EE_USER and MULESOFT_NEXUS_EE_PASSWORD

```text
Usage: createrepos.sh -a apiname -s serverid
-p Mulesoft public url - https://repository.mulesoft.org/nexus/content/repositories/public
-v Maven public remote - https://repo.maven.apache.org/maven2
-n Mulesoft nexus EE url - https://repository.mulesoft.org/nexus-ee/content/repositories/releases-ee/
-r  Mulesoft release url - https://repository.mulesoft.org/releases
-l  Create policy - true/false
-b  Build name - anypoint-sapi-build-release
```

For example:
```text
bash createrepos.sh -a anypoint-sapi -s psuseast1 -p https://repository.mulesoft.org/nexus/content/repositories/public -v https://repo.maven.apache.org/maven2 -n https://repository.mulesoft.org/nexus-ee/content/repositories/releases-ee/ -r https://repository.mulesoft.org/releases -l false -b mvn-sample-build
```

