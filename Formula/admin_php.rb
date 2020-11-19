class AdminPhp < Formula
  homepage "https://secure.php.net"
  url "https://secure.php.net/get/php-7.3.24.tar.xz/from/this/mirror"
  sha256 "78b0b417a147ab7572c874334d11654e3c61ec5b3f2170098e5db02fb0c89888"

  depends_on "expat"
  depends_on "libxml2"
  depends_on "openssl"
  depends_on "zlib"
  depends_on "libzip"

  def install
      config_path = etc/"lsphp/admin/#{php_version}"

      # Each extension that is built on Mojave needs a direct reference to the
      # sdk path or it won't find the headers
      headers_path = "=#{MacOS.sdk_path_if_needed}/usr"

      # Required due to icu4c dependency
      ENV.cxx11

      args = %W[
          --prefix=#{prefix}
          --disable-all
          --with-litespeed
          --enable-zip
          --enable-xml
          --enable-json
          --enable-sockets
          --enable-session
          --enable-posix
          --enable-bcmath
          --with-libzip
          --with-bz2#{headers_path}
          --with-zlib=#{Formula["zlib"].opt_prefix}
          --with-openssl=#{Formula["openssl"].opt_prefix}
          --with-sqlite3=#{Formula["sqlite"].opt_prefix}
          --with-libexpat-dir=#{Formula["expat"].opt_prefix}
      ]


      system "./configure", *args
      system "make"
      system "make", "install"
  end

  def php_version
      version.to_s.split(".")[0..1].join(".")
  end
end
