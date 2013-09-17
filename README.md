plugin in progress...

#### INSTALLATION
copy rb files to ~/.chef/plugins/knife/ or $CHEFREPO/.chef/plugins/knife/, eg:
```
cd /opt/chef-repo/.chef
mkdir -p plugins/knife
cd plugins/knife
git clone https://github.com/faja/knife-razor .
```

#### CONFIGURATION
Configuration options (should be placed in your knife.rb file):
* knife[:razor_api] - ip:port of your razor api

eg:
```
knife[:razor_api]='192.168.45.3:8026'
```

#### USAGE
eg:
```
# knife razor provision chef node node0.example.com base,www -e production -o centos6
# knife razor provision idle node node1.staging.example.com AA:BB:CC:DD:EE:FF base,base_staging,www,db -e staging -o centos6
```

#### OVERVIEW

 
