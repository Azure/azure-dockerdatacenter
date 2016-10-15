  

# azure-dockerdatacenter
Azure Docker DataCenter Templates for the to-be GAed Docker DataCenter with  ucp:2.0.0-Beta1 (native Swarm with Raft) and dtr:2.1.0-Beta1 Azure initially based on the "legacy" Docker 1.x 1.0.9 Azure MarketPlace Gallery Templates. For Raft, [please view ContainerCon, Europe (Berlin, October 4-9, 2016) Slides](for UCP 2.0.0 Beta1 and DTR 2.1.0 Beta1) .


Please see the [LICENSE file](https://github.com/Azure/azure-dockerdatacenter/blob/master/LICENSE) for licensing information. 
Docker DataCenter License as used as-is (parameterized or to be uploaded license - lic file) in this project for UCP 2.0.0 Beta1 and DTR 2.1.0 Beta1 can only be obtained presently for the private beta. Please refer to [this post](https://forums.docker.com/t/docker-datacenter-on-engine-1-12-private-beta/23232/1) in the docker forum. Please sign up [here](https://goo.gl/UTG895) for GA Waiting list.

This project has adopted the [Microsoft Open Source Code of
Conduct](https://opensource.microsoft.com/codeofconduct/). For more information
see the [Code of Conduct
FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional
questions or comments.

**This repo is based on and top of the [Azure Marketplace Gallery Docker DDC 1.0.9 template(s)](https://gallery.azure.com/artifact/20151001/docker.dockerdatacenterdocker-datacenter.1.0.9/Artifacts/mainTemplate.json)**

**Uses the new public tar.gz from [here](https://packages.docker.com/caas/ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz) for changes using the Raft Protocol and Auto HA for private beta (to be GAed DDC) and native swarm mode orchestration on MS Azure. DDC Private Beta docs are [here](https://beta.docker.com/docs/ddc)**

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-dockerdatacenter%2Fmaster%2Fazuredeploy.json" target="_blank">
   <img alt="Deploy to Azure" src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-dockerdatacenter%2Fmaster%2Fazuredeploy.json" target="_blank">  
<img src="http://armviz.io/visualizebutton.png"/> </a> 

This project is hosted at:

  * https://github.com/Azure/azure-dockerdatacenter
  
## Reporting bugs

Please report bugs  by opening an issue in the [GitHub Issue Tracker](https://github.com/Azure/azure-dockerdatacenter/issues)


## Patches and pull requests

Patches can be submitted as GitHub pull requests. If using GitHub please make sure your branch applies to the current master as a 'fast forward' merge (i.e. without creating a merge commit). Use the `git rebase` command to update your branch to the current master if necessary.

## Pre-Req
~~Create a free account for MS Azure Operational Management Suite with workspaceID~~


:heart: :penguin: :whale:
