
cf api api.$1.xip.io --skip-ssl-validation
cf login -u admin -p fakepassword
cf create-org demo
cf target -o demo
cf create-space space1 -o demo
cf target -o demo -s space1
