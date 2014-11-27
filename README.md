Setting Up An OpenLMIS Instance
===============================

Software Required
-----------------

* [Git](http://git-scm.com/download/mac)
* [Vagrant](https://www.vagrantup.com/)
* [VirtualBox](http://download.virtualbox.org/virtualbox/4.3.20/VirtualBox-4.3.20-96996-OSX.dmg)

Create a Vagrant workspace
--------------------------

_(in Mac command line)_

<code>git clone git@github.com:ThoughtWorksInc/ahf-logistics-sample.git</code>

<code>cd ahf-logistics-sample</code>

Setup OpenLMIS virtual machine
------------------------------

_(in Mac command line)_

<code>vagrant up</code>

<code>vagrant ssh</code>

_(in virtual machine command line)_

<code>cd /vagrant</code>

<code>./setup.sh</code>

Run OpenLMIS instance
---------------------

_(in virtual machine command line)_

<code>./run.sh</code>

Now you should be able to access OpenLMIS at http://localhost:9091/
