# OPC PowerApps Build Tools

Collection of Azure DevOps build / release tasks used to automate application lifecycle management with Microsoft PowerApps. 

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. 

```
git clone https://github.com/opc-cpvp/OPC.PowerApps.BuildTools.git
```

### Prerequisites

* Node.js
* npm
* TFS Cross Platform Command Line Interface

### Installing

After compiling the tasks, simply follow Microsoft's [documentation](https://docs.microsoft.com/en-us/azure/devops/extend/publish/overview?view=azure-devops#publish) on publishing to the Visual Studio Marketplace.

## Tasks

### OPC - PowerApps Tool Installer

The Tool Installer task installs all necesessary tools required by the other tasks.

This includes:
* Xrm Online Management Api
* PowerApps Administration
* PowerApps
* Xrm Tooling CrmConnector
* OPC PowerApps Data Migration

### OPC - PowerApps Create Environment

The Create Environment task creates a brand new PowerApps environment with the provided configuration. 

### OPC - PowerApps Copy Environment

The Copy Environment task creates a copy (including configuration) of an existing environment.

### OPC - PowerApps Export Environment Schema

The Export Environment Schema task exports a schema definition for a given environment. 

### OPC - PowerApps Export Environment Data

The Export Environment Data task exports data for a given environment. 

## Built With

* [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview)

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/opc-cpvp/OPC.PowerApps.BuildTools/tags). 

## Authors

* **OPC-CPVP** - *Initial work* - [OPC-CPVP](https://github.com/opc-cpvp)

See also the list of [contributors](https://github.com/opc-cpvp/OPC.PowerApps.BuildTools/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
