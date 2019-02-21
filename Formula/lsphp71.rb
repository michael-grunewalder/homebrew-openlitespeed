class Lsphp71 < Formula
    desc "General-purpose scripting language"
    homepage "https://secure.php.net/"
    url "https://php.net/get/php-7.1.25.tar.xz/from/this/mirror"
    sha256 "0fd8dad1903cd0b2d615a1fe4209f99e53b7292403c8ffa1919c0f4dd1eada88"

    keg_only :versioned_formula

    depends_on "puleeno/openlitespeed/openlitespeed" => [:build]
    depends_on "pkg-config" => :build
    depends_on "apr"
    depends_on "apr-util"
    depends_on "aspell"
    depends_on "autoconf"
    depends_on "curl-openssl"
    depends_on "freetds"
    depends_on "freetype"
    depends_on "gettext"
    depends_on "glib"
    depends_on "gmp"
    depends_on "icu4c"
    depends_on "jpeg"
    depends_on "libpng"
    depends_on "libpq"
    depends_on "libtool"
    depends_on "libzip"
    depends_on "mcrypt"
    depends_on "openldap"
    depends_on "openssl"
    depends_on "pcre"
    depends_on "sqlite"
    depends_on "tidy-html5"
    depends_on "unixodbc"
    depends_on "webp"

    # PHP build system incorrectly links system libraries
    # see https://github.com/php/php-src/pull/3472
    patch :DATA

    def install
      # Ensure that libxml2 will be detected correctly in older MacOS
      if MacOS.version == :el_capitan || MacOS.version == :sierra
        ENV["SDKROOT"] = MacOS.sdk_path
      end

      # buildconf required due to system library linking bug patch
      system "./buildconf", "--force"

      # Required due to icu4c dependency
      ENV.cxx11

      config_path = etc/"lsphp/#{php_version}"
      # Prevent system pear config from inhibiting pear install
      (config_path/"pear.conf").delete if (config_path/"pear.conf").exist?

      # Prevent homebrew from harcoding path to sed shim in phpize script
      ENV["lt_cv_path_SED"] = "sed"

      # Each extension that is built on Mojave needs a direct reference to the
      # sdk path or it won't find the headers
      headers_path = "=#{MacOS.sdk_path_if_needed}/usr"

      args = %W[
        --prefix=#{prefix}
        --localstatedir=#{var}
        --sysconfdir=#{config_path}
        --with-config-file-path=#{config_path}
        --with-config-file-scan-dir=#{config_path}/conf.d
        --with-pear=#{pkgshare}/pear
        -- width-litespeed
        --enable-bcmath
        --enable-calendar
        --enable-dba
        --enable-dtrace
        --enable-exif
        --enable-ftp
        --enable-fpm
        --enable-intl
        --enable-mbregex
        --enable-mbstring
        --enable-mysqlnd
        --enable-opcache-file
        --enable-pcntl
        --enable-phpdbg
        --enable-phpdbg-webhelper
        --enable-shmop
        --enable-soap
        --enable-sockets
        --enable-sysvmsg
        --enable-sysvsem
        --enable-sysvshm
        --enable-wddx
        --enable-zip
        --with-bz2#{headers_path}
        --with-curl=#{Formula["curl-openssl"].opt_prefix}
        --with-freetype-dir=#{Formula["freetype"].opt_prefix}
        --with-gd
        --with-gettext=#{Formula["gettext"].opt_prefix}
        --with-gmp=#{Formula["gmp"].opt_prefix}
        --with-iconv#{headers_path}
        --with-icu-dir=#{Formula["icu4c"].opt_prefix}
        --with-jpeg-dir=#{Formula["jpeg"].opt_prefix}
        --with-kerberos#{headers_path}
        --with-layout=GNU
        --with-ldap=#{Formula["openldap"].opt_prefix}
        --with-ldap-sasl#{headers_path}
        --with-libedit#{headers_path}
        --with-libxml-dir#{headers_path}
        --with-libzip
        --with-mcrypt=#{Formula["mcrypt"].opt_prefix}
        --with-mhash#{headers_path}
        --with-mysql-sock=/tmp/mysql.sock
        --with-mysqli=mysqlnd
        --with-ndbm#{headers_path}
        --with-openssl=#{Formula["openssl"].opt_prefix}
        --with-pdo-dblib=#{Formula["freetds"].opt_prefix}
        --with-pdo-mysql=mysqlnd
        --with-pdo-odbc=unixODBC,#{Formula["unixodbc"].opt_prefix}
        --with-pdo-pgsql=#{Formula["libpq"].opt_prefix}
        --with-pdo-sqlite=#{Formula["sqlite"].opt_prefix}
        --with-pgsql=#{Formula["libpq"].opt_prefix}
        --with-pic
        --with-png-dir=#{Formula["libpng"].opt_prefix}
        --with-pspell=#{Formula["aspell"].opt_prefix}
        --with-sqlite3=#{Formula["sqlite"].opt_prefix}
        --with-tidy=#{Formula["tidy-html5"].opt_prefix}
        --with-unixODBC=#{Formula["unixodbc"].opt_prefix}
        --with-webp-dir=#{Formula["webp"].opt_prefix}
        --with-xmlrpc
        --with-xsl#{headers_path}
        --with-zlib#{headers_path}
      ]

      system "./configure", *args
      system "make"
      system "make", "install"

      # Allow pecl to install outside of Cellar
      extension_dir = Utils.popen_read("#{bin}/php-config --extension-dir").chomp
      orig_ext_dir = File.basename(extension_dir)
      inreplace bin/"php-config", lib/"php", prefix/"pecl"
      inreplace "php.ini-development", %r{; ?extension_dir = "\./"},
        "extension_dir = \"#{HOMEBREW_PREFIX}/lib/lsphp/pecl/#{orig_ext_dir}\""

      config_files = {
        "php.ini-development"   => "php.ini",
      }
      config_files.each_value do |dst|
        dst_default = config_path/"#{dst}.default"
        rm dst_default if dst_default.exist?
      end
      config_path.install config_files
    end

    def post_install
      pear_prefix = pkgshare/"pear"
      pear_files = %W[
        #{pear_prefix}/.depdblock
        #{pear_prefix}/.filemap
        #{pear_prefix}/.depdb
        #{pear_prefix}/.lock
      ]

      %W[
        #{pear_prefix}/.channels
        #{pear_prefix}/.channels/.alias
      ].each do |f|
        chmod 0755, f
        pear_files.concat(Dir["#{f}/*"])
      end

      chmod 0644, pear_files

      # Custom location for extensions installed via pecl
      pecl_path = HOMEBREW_PREFIX/"lib/lsphp/pecl"
      ln_s pecl_path, prefix/"pecl" unless (prefix/"pecl").exist?
      extension_dir = Utils.popen_read("#{bin}/php-config --extension-dir").chomp
      php_basename = File.basename(extension_dir)
      php_ext_dir = opt_prefix/"lib/php"/php_basename

      # fix pear config to install outside cellar
      pear_path = HOMEBREW_PREFIX/"share/pear@#{php_version}"
      cp_r pkgshare/"pear/.", pear_path
      {
        "php_ini"  => etc/"lsphp/#{php_version}/php.ini",
        "php_dir"  => pear_path,
        "doc_dir"  => pear_path/"doc",
        "ext_dir"  => pecl_path/php_basename,
        "bin_dir"  => opt_bin,
        "data_dir" => pear_path/"data",
        "cfg_dir"  => pear_path/"cfg",
        "www_dir"  => pear_path/"htdocs",
        "man_dir"  => HOMEBREW_PREFIX/"share/man",
        "test_dir" => pear_path/"test",
        "php_bin"  => opt_bin/"php",
      }.each do |key, value|
        value.mkpath if key =~ /(?<!bin|man)_dir$/
        system bin/"pear", "config-set", key, value, "system"
      end

      system bin/"pear", "update-channels"

      %w[
        opcache
      ].each do |e|
        ext_config_path = etc/"lsphp/#{php_version}/conf.d/ext-#{e}.ini"
        extension_type = (e == "opcache") ? "zend_extension" : "extension"
        if ext_config_path.exist?
          inreplace ext_config_path,
            /#{extension_type}=.*$/, "#{extension_type}=#{php_ext_dir}/#{e}.so"
        else
          ext_config_path.write <<~EOS
            [#{e}]
            #{extension_type}="#{php_ext_dir}/#{e}.so"
          EOS
        end
      end
    end

    def php_version
      version.to_s.split(".")[0..1].join(".")
    end

  __END__
  diff --git a/acinclude.m4 b/acinclude.m4
  index 168c465f8d..6c087d152f 100644
  --- a/acinclude.m4
  +++ b/acinclude.m4
  @@ -441,7 +441,11 @@ dnl
   dnl Adds a path to linkpath/runpath (LDFLAGS)
   dnl
   AC_DEFUN([PHP_ADD_LIBPATH],[
  -  if test "$1" != "/usr/$PHP_LIBDIR" && test "$1" != "/usr/lib"; then
  +  case "$1" in
  +  "/usr/$PHP_LIBDIR"|"/usr/lib"[)] ;;
  +  /Library/Developer/CommandLineTools/SDKs/*/usr/lib[)] ;;
  +  /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/*/usr/lib[)] ;;
  +  *[)]
       PHP_EXPAND_PATH($1, ai_p)
       ifelse([$2],,[
         _PHP_ADD_LIBPATH_GLOBAL([$ai_p])
  @@ -452,8 +456,8 @@ AC_DEFUN([PHP_ADD_LIBPATH],[
         else
           _PHP_ADD_LIBPATH_GLOBAL([$ai_p])
         fi
  -    ])
  -  fi
  +    ]) ;;
  +  esac
   ])

   dnl
  @@ -487,7 +491,11 @@ dnl add an include path.
   dnl if before is 1, add in the beginning of INCLUDES.
   dnl
   AC_DEFUN([PHP_ADD_INCLUDE],[
  -  if test "$1" != "/usr/include"; then
  +  case "$1" in
  +  "/usr/include"[)] ;;
  +  /Library/Developer/CommandLineTools/SDKs/*/usr/include[)] ;;
  +  /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/*/usr/include[)] ;;
  +  *[)]
       PHP_EXPAND_PATH($1, ai_p)
       PHP_RUN_ONCE(INCLUDEPATH, $ai_p, [
         if test "$2"; then
  @@ -495,8 +503,8 @@ AC_DEFUN([PHP_ADD_INCLUDE],[
         else
           INCLUDES="$INCLUDES -I$ai_p"
         fi
  -    ])
  -  fi
  +    ]) ;;
  +  esac
   ])

   dnl internal, don't use
  @@ -2411,7 +2419,8 @@ AC_DEFUN([PHP_SETUP_ICONV], [
       fi

       if test -f $ICONV_DIR/$PHP_LIBDIR/lib$iconv_lib_name.a ||
  -       test -f $ICONV_DIR/$PHP_LIBDIR/lib$iconv_lib_name.$SHLIB_SUFFIX_NAME
  +       test -f $ICONV_DIR/$PHP_LIBDIR/lib$iconv_lib_name.$SHLIB_SUFFIX_NAME ||
  +       test -f $ICONV_DIR/$PHP_LIBDIR/lib$iconv_lib_name.tbd
       then
         PHP_CHECK_LIBRARY($iconv_lib_name, libiconv, [
           found_iconv=yes
