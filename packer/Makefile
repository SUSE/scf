.PHONY: vagrant-virtualbox vagrant-libvirt scf-cached-libvirt minicap
.INTERMEDIATE: http/scf-autoyast.xml http/vagrant-autoyast.xml

scf-cached-libvirt: http/scf-autoyast.xml
	packer build -only scf-cached-libvirt vagrant-box.json
vagrant-libvirt: http/vagrant-autoyast.xml
	packer build -only vagrant-libvirt vagrant-box.json
vagrant-virtualbox: http/vagrant-autoyast.xml
	packer build -only vagrant-virtualbox vagrant-box.json
jenkins-slave: http/vagrant-autoyast.xml
	packer build -only jenkins-slave vagrant-box.json
minicap: http/minicap-autoyast.xml
	packer build -only minicap vagrant-box.json

# The following build pieces require txtplate to evaluate Go templates
http/scf-autoyast.xml: http/autoyast.xml.tpl
	txtplate --input http/autoyast.xml.tpl \
	         --output http/scf-autoyast.xml \
	         scf-templating.json

http/minicap-autoyast.xml: http/autoyast.xml.tpl
	txtplate --input http/autoyast.xml.tpl \
	         --output http/minicap-autoyast.xml \
	         minicap-templating.json

http/vagrant-autoyast.xml: http/autoyast.xml.tpl
	txtplate --input http/autoyast.xml.tpl \
	         --output http/vagrant-autoyast.xml \
	         vagrant-templating.json
