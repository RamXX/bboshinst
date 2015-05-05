# Binary BOSH Installer Script
## For OpenStack
When I first heard of Binary BOSH [here](https://blog.starkandwayne.com/2014/07/10/resurrecting-bosh-with-binary-boshes/) brought up by Dr. Nic, I thought it was a really good idea.

Yes, it's true that there are ways to manually recover an instance of BOSH or MicroBOSH, but I find more elegant to have an automatic mechanism that relies on BOSH itself. Heck, if we use MicroBOSH to deploy BOSH, then why not use BOSH to protect BOSH?

In any case, this script is an attempt to automate the whole process. It was tested on [DreamCompute](https://www.dreamhost.com/cloud/computing/) and it's known to work there. You may need to customize it for other OpenStack clouds, but it's made as generic as possible.

Feel free to improve on it and submit your pull requests.

### Usage
`bbosh.sh <stemcell> <release tarball> <microbosh manifest> <manifest 1> <manifest 2> <PEM keyfile>`

There is also a `bbosh_cleanup.sh` script that relies on `nova`, `cinder` and `glance` commands that need to be installed in your running environment.

### Pre-requisites
- Have BOSH CLI installed according to [these instructions](https://bosh.io/docs/bosh-cli.html).
- Have the Nova, Cinder and Glance command-line tools installed.
- Install dependencies: 

```
sudo apt-get install bzr jq golang
export GOPATH=$HOME/go && export PATH=$PATH:$GOPATH/bin:
go get github.com/bronze1man/yaml2json
```
- Very important: `source` your openrc.sh file for your tenant before you attempt any install.

