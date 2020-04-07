# -*- mode: ruby -*-
# vi: set ft=ruby :

#The environment will start with 2 clusters by default. You can tune the
#number of clusters by passing an enviornment variable for NUM_CLUSTERS

number_of_clusters = (ENV['NUM_CLUSTERS'] || "2").to_i
box_name = (ENV['VAGRANT_BOX'] || "ubuntu/eoan64")

Vagrant.configure("2") do |config|
  config.vm.box = "#{box_name}"



  (1..number_of_clusters).each do |cluster|
    config.vm.define "master-c#{cluster}" do |master|
      master.vm.hostname = "master-c#{cluster}"
      ip = cluster + 10
      master.vm.network :private_network, ip: "192.168.80.#{ip}", :netmask => "255.255.255.0"
      master.vm.provision :shell, :path => "master.sh"
      master.vm.provider :virtualbox do |vbox|
          vbox.customize ["modifyvm", :id, "--memory", 2048]
          vbox.customize ["modifyvm", :id, "--cpus", 1]
      end
    end
  end
end
