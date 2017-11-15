.PHONY: vagrant-virtualbox vagrant-libvirt scf-cached

scf-cached-libvirt: http/scf-autoyast.xml
	packer build -only scf-cached-libvirt vagrant-box.json
vagrant-libvirt: http/vagrant-autoyast.xml
	packer build -only vagrant-libvirt vagrant-box.json
vagrant-virtualbox: http/vagrant-autoyast.xml
	packer build -only vagrant-virtualbox vagrant-box.json

# The following build pieces require txtplate to evaluate Go templates
http/scf-autoyast.xml: http/autoyast.xml.tpl
	txtplate --input http/autoyast.xml.tpl \
		       --output http/scf-autoyast.xml \
					 scf-templating.json 

http/vagrant-autoyast.xml: http/autoyast.xml.tpl
	txtplate --input http/autoyast.xml.tpl \
					 --output http/vagrant-autoyast.xml \
					 vagrant-templating.json 
