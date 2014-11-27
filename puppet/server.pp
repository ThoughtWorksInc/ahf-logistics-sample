exec { "pre-install-update":
  command => "/usr/bin/apt-get update"
}

exec { "install-add-apt":
  command => "/usr/bin/apt-get install python-software-properties -y",
  creates => '/usr/bin/add-apt-repository'
}

exec { "add-apt-repository-for-java":
  command => "/usr/bin/add-apt-repository -y ppa:webupd8team/java"
}

exec { "add-apt-repository-for-gradle":
  command => "/usr/bin/add-apt-repository -y ppa:cwchien/gradle"
}

exec { "add-apt-repository-for-node":
  command => "/usr/bin/wget -O /tmp/setup https://deb.nodesource.com/setup && /bin/bash /tmp/setup"
}

exec { "apt-update":
  command => "/usr/bin/apt-get update",
  subscribe => Exec["add-apt-repository-for-java"],
  refreshonly => true
}

Exec["pre-install-update"] -> Exec["install-add-apt"] ->
Exec["add-apt-repository-for-java"] -> Exec["add-apt-repository-for-gradle"] -> Exec["add-apt-repository-for-node"] ->
Exec["apt-update"] -> Package <| |>

include curl
include unzip
include openjdk7
include postgres
include git
include gradle
include nodejs
