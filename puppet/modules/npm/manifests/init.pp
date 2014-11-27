class npm {
  package { "npm":
    ensure => present
  }

  exec { "/usr/bin/npm config set registry http://registry.npmjs.org/":
    require => Package["npm"]
  }
}
