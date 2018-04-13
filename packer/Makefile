.PHONY: vagrant-virtualbox vagrant-libvirt scf-cached-libvirt
.INTERMEDIATE: http/scf-autoyast.xml http/vagrant-autoyast.xml

scf-cached-libvirt: http/scf-autoyast.xml
	packer build -only scf-cached-libvirt \
		-var ssh_username=scf \
		-var ssh_password=changeme \
		vagrant-box.json
vagrant-libvirt: http/vagrant-autoyast.xml
	packer build -only vagrant-libvirt vagrant-box.json
vagrant-virtualbox: http/vagrant-autoyast.xml
	packer build -only vagrant-virtualbox vagrant-box.json
jenkins-slave: http/vagrant-autoyast.xml
	packer build -only jenkins-slave vagrant-box.json

# The following build pieces require txtplate to evaluate Go templates
http/scf-autoyast.xml: http/autoyast.xml.tpl
	txtplate --input http/autoyast.xml.tpl \
	         --output http/scf-autoyast.xml \
	         scf-templating.json

http/vagrant-autoyast.xml: http/autoyast.xml.tpl
	txtplate --input http/autoyast.xml.tpl \
	         --output http/vagrant-autoyast.xml \
	         vagrant-templating.json
