def mysql_installed?
  `which mysql_config`.length > 0
end

class PhpAT52 < Formula
  url 'http://ca2.php.net/distributions/php-5.2.17.tar.gz'
  homepage ''
  md5 '04d321d5aeb9d3a051233dbd24220ef1'
  version '5.2.17'

  skip_clean [ 'bin', 'sbin' ]

  depends_on 'libxml2'
  depends_on 'jpeg'
  depends_on 'libpng'
  depends_on 'mcrypt'
  depends_on 'gettext'
  if ARGV.include? '--with-mysql'
    depends_on 'mysql' => :recommended unless mysql_installed?
  end
  if ARGV.include? '--with-fpm'
    depends_on 'libevent'
  end
  if ARGV.include? '--with-pgsql'
    depends_on 'postgresql'
  end
  if ARGV.include? '--with-mssql'
    depends_on 'freetds'
  end
  if ARGV.include? '--with-intl'
    depends_on 'icu4c'
  end
  if ARGV.include? '--with-readline'
    depends_on 'readline'
  end
  
  def options
   [
     ['--with-mysql', 'Include MySQL support'],
     ['--with-pgsql', 'Include PostgreSQL support'],
     ['--with-fpm', 'Enable building of the fpm SAPI executable'],
     ['--with-apache', 'Build shared Apache 2.0 Handler module'],
     ['--with-intl', 'Include intl extension'],
     ['--with-readline', 'Include readline extension']
   ]
  end

  # depends_on 'cmake'

  def configure_args
    args = [
      "--prefix=#{prefix}",
      "--disable-debug",
      "--disable-dependency-tracking",
      "--with-config-file-path=#{prefix}/etc",
      "--with-iconv-dir=/usr",
      "--enable-soap",
      "--enable-sqlite-utf8",
      "--enable-sockets",
      "--enable-fastcgi",
      "--enable-memory-limit",
      "--enable-mbstring",
      "--enable-mbregex",
      "--enable-zend-multibyte",
      "--with-openssl=/usr",
      "--with-zlib=/usr",
      "--with-bz2=/usr",
      "--with-xmlrpc",
      "--with-libxml-dir=#{Formula.factory('libxml2').prefix}",
      "--with-xsl=/usr",
      "--with-curl=/usr",
      "--with-gd",
      "--enable-gd-native-ttf",
      "--with-mcrypt=#{Formula.factory('mcrypt').prefix}",
      "--with-jpeg-dir=#{Formula.factory('jpeg').prefix}",
      "--with-png-dir=#{Formula.factory('libpng').prefix}",
      "--with-gettext=#{Formula.factory('gettext').prefix}",
      "--mandir=#{man}"
    ]

    # Free type support
    if File.exist? "/usr/X11"
      args.push "--with-freetype-dir=/usr/X11"
    end

    # Bail if both php-fpm and apxs are enabled
    # http://bugs.php.net/bug.php?id=52419
    if (ARGV.include? '--with-fpm') && (ARGV.include? '--with-apache')
      onoe "You can only enable PHP FPM or Apache, not both"
      puts "http://bugs.php.net/bug.php?id=52419"
      exit 99
    end

    # Enable PHP FPM
    if ARGV.include? '--with-fpm'
      args.push "--enable-fpm"
    end

    # Build Apache module
    if ARGV.include? '--with-apache'
      args.push "--with-apxs2=/usr/sbin/apxs"
      args.push "--libexecdir=#{prefix}/libexec"
    end

    if ARGV.include? '--with-mysql'
      args.push "--with-mysql-sock=/tmp/mysql.sock"
      args.push "--with-mysqli"
      args.push "--with-mysql=/usr/local"
      args.push "--with-pdo-mysql=/usr/local"
    end

    if ARGV.include? '--with-pgsql'
      args.push "--with-pgsql=#{Formula.factory('postgresql').prefix}"
      args.push "--with-pdo-pgsql=#{Formula.factory('postgresql').prefix}"
    end

    if ARGV.include? '--with-intl'
      args.push "--enable-intl"
      args.push "--with-icu-dir=#{Formula.factory('icu4c').prefix}"
    end
    
    if ARGV.include? '--with-readline'
      args.push "--with-readline=#{Formula.factory('readline').prefix}"
    end

    return args
  end

  def install
    # Because for icu4c, we must link with c++ when building with intl extension
    ENV.append 'LDFLAGS', '-lstdc++' if ARGV.include? '--with-intl'

    ENV.O3 # Speed things up
    system "./configure", *configure_args

    if ARGV.include? '--with-apache'
      # Use Homebrew prefix for the Apache libexec folder
      inreplace "Makefile",
        "INSTALL_IT = $(mkinstalldirs) '$(INSTALL_ROOT)/usr/libexec/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='$(INSTALL_ROOT)/usr/libexec/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so",
        "INSTALL_IT = $(mkinstalldirs) '#{prefix}/libexec/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='#{prefix}/libexec/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so"
    end
    
    system "make"
    system "make install"

    system "cp ./php.ini-recommended #{prefix}/etc/php.ini"

    if ARGV.include? '--with-fpm'
      (prefix+'org.php.php-fpm.plist').write startup_plist
      system "cp #{prefix}/etc/php-fpm.conf.default #{prefix}/etc/php-fpm.conf"
      (prefix+'var/log').mkpath
      touch prefix+'var/log/php-fpm.log'
    end
  end

 def caveats; <<-EOS
   For 10.5 and Apache:
    Apache needs to run in 32-bit mode. You can either force Apache to start 
    in 32-bit mode or you can thin the Apache executable.
   
   To enable PHP in Apache add the following to httpd.conf and restart Apache:
    LoadModule php5_module    #{prefix}/libexec/apache2/libphp5.so

    The php.ini file can be found in:
      #{prefix}/etc/php.ini
   EOS
 end
end